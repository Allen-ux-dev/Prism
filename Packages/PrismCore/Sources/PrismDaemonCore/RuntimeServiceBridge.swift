import Foundation
import PrismDomain
import PrismTransactions
import PrismPrivilegedProtocol

public actor RuntimeServiceBridgeConnection {
    private let transport: any RuntimeServiceTransport
    private let clientIdentifier: String
    private let supportedProtocolVersions: [Int]
    private var cachedHello: RuntimeServiceHello?

    public init(
        transport: any RuntimeServiceTransport,
        clientIdentifier: String,
        supportedProtocolVersions: [Int] = [1]
    ) {
        self.transport = transport
        self.clientIdentifier = clientIdentifier
        self.supportedProtocolVersions = supportedProtocolVersions
    }

    public func connect() async throws -> RuntimeServiceHello {
        if let cachedHello { return cachedHello }
        let response = try await transport.send(.handshake(.init(
            clientIdentifier: clientIdentifier,
            supportedProtocolVersions: supportedProtocolVersions
        )))
        switch response {
        case .hello(let hello):
            guard supportedProtocolVersions.contains(hello.selectedProtocolVersion) else {
                throw RuntimeServiceProtocolError.incompatibleProtocol
            }
            cachedHello = hello
            return hello
        case .rejected(let reason):
            throw RuntimeServiceProtocolError.handshakeRejected(reason)
        default:
            throw RuntimeServiceProtocolError.unexpectedResponse
        }
    }

    public func request(_ request: RuntimeServiceRequest) async throws -> RuntimeServiceResponse {
        _ = try await connect()
        do {
            return try await transport.send(request)
        } catch {
            cachedHello = nil
            await transport.reset()
            throw error
        }
    }

    public func reset() async {
        cachedHello = nil
        await transport.reset()
    }
}

public struct RemoteRuntimeApplicationService: RuntimeApplicationService, Sendable {
    public let descriptor: RuntimeApplicationServiceDescriptor
    private let connection: RuntimeServiceBridgeConnection

    public init(descriptor: RuntimeApplicationServiceDescriptor, connection: RuntimeServiceBridgeConnection) {
        self.descriptor = descriptor
        self.connection = connection
    }

    public func inspectInstalledApps() async throws -> [String: PrismInstalledApp] {
        switch try await connection.request(.inspectInstalledApps) {
        case .installedApps(let apps): return apps
        case .rejected(let reason): throw RuntimeServiceProtocolError.handshakeRejected(reason)
        default: throw RuntimeServiceProtocolError.unexpectedResponse
        }
    }

    public func inspectRegisteredBundleIdentifiers() async throws -> Set<String> {
        switch try await connection.request(.inspectRegisteredBundleIdentifiers) {
        case .registeredBundleIdentifiers(let identifiers): return identifiers
        case .rejected(let reason): throw RuntimeServiceProtocolError.handshakeRejected(reason)
        default: throw RuntimeServiceProtocolError.unexpectedResponse
        }
    }

    public func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        try await operationResult(for: .install(operation))
    }

    public func replace(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        try await operationResult(for: .replace(operation))
    }

    public func remove(bundleIdentifier: String) async throws -> BackendOperationResult {
        try await operationResult(for: .removeApp(bundleIdentifier))
    }

    public func register(bundleIdentifier: String) async throws -> BackendOperationResult {
        try await operationResult(for: .registerApp(bundleIdentifier))
    }

    public func refresh(bundleIdentifier: String) async throws -> BackendOperationResult {
        try await operationResult(for: .refreshApp(bundleIdentifier))
    }

    private func operationResult(for request: RuntimeServiceRequest) async throws -> BackendOperationResult {
        switch try await connection.request(request) {
        case .operation(let result): return result
        case .rejected(let reason): throw RuntimeServiceProtocolError.handshakeRejected(reason)
        default: throw RuntimeServiceProtocolError.unexpectedResponse
        }
    }
}

public struct RemoteRuntimeInjectionService: RuntimeInjectionService, Sendable {
    public let descriptor: RuntimeApplicationServiceDescriptor
    private let connection: RuntimeServiceBridgeConnection

    public init(descriptor: RuntimeApplicationServiceDescriptor, connection: RuntimeServiceBridgeConnection) {
        self.descriptor = descriptor
        self.connection = connection
    }

    public func inspectActiveInjections() async throws -> Set<InjectionStateKey> {
        switch try await connection.request(.inspectActiveInjections) {
        case .activeInjections(let injections): return injections
        case .rejected(let reason): throw RuntimeServiceProtocolError.handshakeRejected(reason)
        default: throw RuntimeServiceProtocolError.unexpectedResponse
        }
    }

    public func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult {
        try await operationResult(for: .applyInjection(operation))
    }

    public func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult {
        try await operationResult(for: .removeInjection(targetBundleIdentifier: targetBundleIdentifier, artifactIdentifier: artifactIdentifier))
    }

    private func operationResult(for request: RuntimeServiceRequest) async throws -> BackendOperationResult {
        switch try await connection.request(request) {
        case .operation(let result): return result
        case .rejected(let reason): throw RuntimeServiceProtocolError.handshakeRejected(reason)
        default: throw RuntimeServiceProtocolError.unexpectedResponse
        }
    }
}

public struct RuntimeServiceBridgeSnapshot: Sendable {
    public let hello: RuntimeServiceHello
    public let applicationService: RemoteRuntimeApplicationService?
    public let injectionService: RemoteRuntimeInjectionService?
}

public struct RuntimeServiceBridge: Sendable {
    private let connection: RuntimeServiceBridgeConnection

    public init(transport: any RuntimeServiceTransport, clientIdentifier: String) {
        self.connection = RuntimeServiceBridgeConnection(transport: transport, clientIdentifier: clientIdentifier)
    }

    public func connect() async throws -> RuntimeServiceBridgeSnapshot {
        let hello = try await connection.connect()
        let descriptor = descriptor(from: hello)
        let capabilities = descriptor.capabilities

        let applicationCapabilities: Set<CapabilityIdentifier> = [
            .appInstall, .appRegistration, .appReplace, .appRemoval, .appRefresh
        ]
        let injectionCapabilities: Set<CapabilityIdentifier> = [
            .appInjection, .dylibInjection, .frameworkInjection, .bundleInjection
        ]

        return RuntimeServiceBridgeSnapshot(
            hello: hello,
            applicationService: capabilities.isDisjoint(with: applicationCapabilities) ? nil : .init(descriptor: descriptor, connection: connection),
            injectionService: capabilities.isDisjoint(with: injectionCapabilities) ? nil : .init(descriptor: descriptor, connection: connection)
        )
    }

    public func queryBackgroundSession() async throws -> RuntimeBackgroundSessionState {
        switch try await connection.request(.queryBackgroundSession) {
        case .backgroundSession(let state): return state
        case .rejected(let reason): throw RuntimeServiceProtocolError.handshakeRejected(reason)
        default: throw RuntimeServiceProtocolError.unexpectedResponse
        }
    }

    public func setBackgroundSessionEnabled(_ enabled: Bool) async throws -> RuntimeBackgroundSessionState {
        switch try await connection.request(.setBackgroundSessionEnabled(enabled)) {
        case .backgroundSession(let state): return state
        case .rejected(let reason): throw RuntimeServiceProtocolError.handshakeRejected(reason)
        default: throw RuntimeServiceProtocolError.unexpectedResponse
        }
    }

    public func reset() async {
        await connection.reset()
    }

    private func descriptor(from hello: RuntimeServiceHello) -> RuntimeApplicationServiceDescriptor {
        let usableCapabilities = Set(hello.capabilityStates.compactMap { identifier, state in
            switch state.availability {
            case .available, .degraded: return identifier
            case .unavailable, .unknown: return nil
            }
        })
        let kind: RuntimeApplicationProviderKind = hello.providerKind == .native ? .native : .compatibility
        return RuntimeApplicationServiceDescriptor(
            identifier: hello.runtimeIdentity,
            displayName: hello.displayName,
            providerKind: kind,
            priority: hello.priority,
            capabilities: usableCapabilities,
            health: hello.health,
            metadata: hello.metadata.merging([
                "serviceVersion": hello.serviceVersion,
                "protocolVersion": String(hello.selectedProtocolVersion)
            ]) { current, _ in current }
        )
    }
}
