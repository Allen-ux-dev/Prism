import Foundation
import PrismDomain
import PrismPrivilegedProtocol

public struct RuntimeServiceEndpoint: Codable, Sendable, Hashable {
    public let identifier: String
    public let socketPath: String

    public init(identifier: String, socketPath: String) {
        self.identifier = identifier
        self.socketPath = socketPath
    }
}

public protocol RuntimeServiceEndpointSource: Sendable {
    func endpoints() async -> [RuntimeServiceEndpoint]
}

public struct EnvironmentRuntimeServiceEndpointSource: RuntimeServiceEndpointSource, Sendable {
    public let environmentKey: String

    public init(environmentKey: String = "PRISM_RUNTIME_SERVICE_SOCKET") {
        self.environmentKey = environmentKey
    }

    public func endpoints() async -> [RuntimeServiceEndpoint] {
        guard let raw = ProcessInfo.processInfo.environment[environmentKey], !raw.isEmpty else { return [] }
        return raw.split(separator: ";").enumerated().compactMap { index, part in
            let value = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return RuntimeServiceEndpoint(identifier: "runtime-endpoint-\(index)", socketPath: value)
        }
    }
}

public actor RuntimeServiceBridgeCoordinator {
    public typealias TransportFactory = @Sendable (RuntimeServiceEndpoint) -> any RuntimeServiceTransport

    private struct ActiveConnection: Sendable {
        let endpoint: RuntimeServiceEndpoint
        let bridge: RuntimeServiceBridge
        let snapshot: RuntimeServiceBridgeSnapshot
    }

    private let registry: RuntimeApplicationServiceRegistry
    private let endpointSource: any RuntimeServiceEndpointSource
    private let transportFactory: TransportFactory
    private let clientIdentifier: String
    private var activeConnections: [String: ActiveConnection] = [:]
    private var registeredApplicationIdentifiers: Set<String> = []
    private var registeredInjectionIdentifiers: Set<String> = []
    private var status = RuntimeServiceBridgeStatus()

    public init(
        registry: RuntimeApplicationServiceRegistry = .shared,
        endpointSource: any RuntimeServiceEndpointSource = EnvironmentRuntimeServiceEndpointSource(),
        clientIdentifier: String = "dev.allenux.prism",
        transportFactory: @escaping TransportFactory = { endpoint in
            UnixSocketRuntimeServiceTransport(path: endpoint.socketPath)
        }
    ) {
        self.registry = registry
        self.endpointSource = endpointSource
        self.clientIdentifier = clientIdentifier
        self.transportFactory = transportFactory
    }

    public func currentStatus() -> RuntimeServiceBridgeStatus {
        status
    }

    @discardableResult
    public func reconnect() async -> RuntimeServiceBridgeStatus {
        await unregisterTrackedServices()
        for connection in activeConnections.values {
            await connection.bridge.reset()
        }
        activeConnections.removeAll()

        let endpoints = await endpointSource.endpoints()
        guard !endpoints.isEmpty else {
            status = RuntimeServiceBridgeStatus(connectionState: .offline)
            return status
        }

        var errors: [String] = []
        var firstApplicationID: String?
        var firstInjectionID: String?

        for endpoint in endpoints {
            do {
                let bridge = RuntimeServiceBridge(
                    transport: transportFactory(endpoint),
                    clientIdentifier: clientIdentifier
                )
                let snapshot = try await bridge.connect()
                if let application = snapshot.applicationService {
                    await registry.registerApplication(application)
                    registeredApplicationIdentifiers.insert(application.descriptor.identifier)
                    firstApplicationID = firstApplicationID ?? application.descriptor.identifier
                }
                if let injection = snapshot.injectionService {
                    await registry.registerInjection(injection)
                    registeredInjectionIdentifiers.insert(injection.descriptor.identifier)
                    firstInjectionID = firstInjectionID ?? injection.descriptor.identifier
                }
                activeConnections[endpoint.identifier] = .init(endpoint: endpoint, bridge: bridge, snapshot: snapshot)
            } catch {
                errors.append("\(endpoint.identifier): \(String(describing: error))")
            }
        }

        guard !activeConnections.isEmpty else {
            status = RuntimeServiceBridgeStatus(
                connectionState: .degraded,
                lastError: errors.first
            )
            return status
        }

        let background = selectBackgroundConnection()
        let backgroundSupported = background != nil
        var backgroundState: RuntimeBackgroundSessionState = backgroundSupported ? .disabled : .unsupported
        if let background {
            do { backgroundState = try await background.bridge.queryBackgroundSession() }
            catch {
                backgroundState = .degraded
                errors.append(String(describing: error))
            }
        }

        let primary = preferredConnection(Array(activeConnections.values))
        status = RuntimeServiceBridgeStatus(
            connectionState: errors.isEmpty ? .connected : .connected,
            runtimeDisplayName: primary?.snapshot.hello.displayName,
            applicationProviderIdentifier: firstApplicationID,
            injectionProviderIdentifier: firstInjectionID,
            backgroundSupported: backgroundSupported,
            backgroundState: backgroundState,
            lastError: errors.first
        )
        return status
    }

    public func setBackgroundEnabled(_ enabled: Bool) async throws -> RuntimeBackgroundSessionState {
        guard let connection = selectBackgroundConnection() else {
            throw RuntimeServiceProtocolError.capabilityUnavailable("background-execution + privileged-service")
        }
        do {
            let newState = try await connection.bridge.setBackgroundSessionEnabled(enabled)
            status = RuntimeServiceBridgeStatus(
                connectionState: status.connectionState,
                runtimeDisplayName: status.runtimeDisplayName,
                applicationProviderIdentifier: status.applicationProviderIdentifier,
                injectionProviderIdentifier: status.injectionProviderIdentifier,
                backgroundSupported: true,
                backgroundState: newState,
                lastError: status.lastError
            )
            return newState
        } catch {
            status = RuntimeServiceBridgeStatus(
                connectionState: .degraded,
                runtimeDisplayName: status.runtimeDisplayName,
                applicationProviderIdentifier: status.applicationProviderIdentifier,
                injectionProviderIdentifier: status.injectionProviderIdentifier,
                backgroundSupported: true,
                backgroundState: .degraded,
                lastError: String(describing: error)
            )
            throw error
        }
    }

    private func unregisterTrackedServices() async {
        for identifier in registeredApplicationIdentifiers {
            await registry.unregisterApplication(identifier: identifier)
        }
        for identifier in registeredInjectionIdentifiers {
            await registry.unregisterInjection(identifier: identifier)
        }
        registeredApplicationIdentifiers.removeAll()
        registeredInjectionIdentifiers.removeAll()
    }

    private func selectBackgroundConnection() -> ActiveConnection? {
        preferredConnection(activeConnections.values.filter { connection in
            let hello = connection.snapshot.hello
            let capabilities = usableCapabilities(from: hello)
            return hello.health.isUsable
                && capabilities.contains(.backgroundExecution)
                && capabilities.contains(.privilegedService)
        })
    }

    private func preferredConnection<S: Sequence>(_ connections: S) -> ActiveConnection? where S.Element == ActiveConnection {
        connections.sorted { lhs, rhs in
            let l = lhs.snapshot.hello
            let r = rhs.snapshot.hello
            if l.providerKind != r.providerKind { return l.providerKind == .native }
            if l.priority != r.priority { return l.priority > r.priority }
            return l.runtimeIdentity < r.runtimeIdentity
        }.first
    }

    private func usableCapabilities(from hello: RuntimeServiceHello) -> Set<CapabilityIdentifier> {
        Set(hello.capabilityStates.compactMap { identifier, state in
            switch state.availability {
            case .available, .degraded: return identifier
            case .unavailable, .unknown: return nil
            }
        })
    }
}
