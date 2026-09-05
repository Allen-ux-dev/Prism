import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions

public struct ClientHello: Codable, Sendable, Equatable { public let protocolVersion: Int; public let clientIdentifier: String; public init(protocolVersion: Int = 1, clientIdentifier: String) { self.protocolVersion = protocolVersion; self.clientIdentifier = clientIdentifier } }
public struct ServiceHello: Codable, Sendable, Equatable { public let protocolVersion: Int; public let serviceVersion: String; public init(protocolVersion: Int = 1, serviceVersion: String) { self.protocolVersion = protocolVersion; self.serviceVersion = serviceVersion } }
public struct RepositorySourceDescriptor: Codable, Sendable, Hashable { public let baseURL: URL; public init(baseURL: URL) { self.baseURL = baseURL } }

public enum PrivilegedRequest: Codable, Sendable, Equatable {
    case handshake(ClientHello)
    case queryEnvironment
    case queryCapabilities
    case queryTransactions
    case submitTransaction(PrismTransaction)
    case cancelTransaction(UUID)
    case queryPackageState
    case queryApplicationState
    case reconcileState(UUID)
    case syncSources([RepositorySourceDescriptor])
    case queryRuntimeBridgeStatus
    case reconnectRuntimeBridge
    case setRuntimeBackgroundEnabled(Bool)
}

public enum PrivilegedResponse: Codable, Sendable, Equatable {
    case hello(ServiceHello)
    case environment(PrismEnvironment)
    case capabilities(Set<EnvironmentCapability>)
    case transactions([PrismTransaction])
    case transaction(PrismTransaction)
    case packageState(PackageStateSnapshot)
    case applicationState(ApplicationStateSnapshot)
    case runtimeBridgeStatus(RuntimeServiceBridgeStatus)
    case accepted
    case rejected(String)
}

public protocol PrivilegedTransport: Sendable {
    func send(_ request: PrivilegedRequest) async throws -> PrivilegedResponse
    func reset() async
}

public extension PrivilegedTransport {
    func reset() async {}
}

public enum PrivilegedSessionState: String, Codable, Sendable { case offline, recovering, connected }

public actor PrivilegedSessionManager {
    private let transport: any PrivilegedTransport
    private let clientIdentifier: String
    public private(set) var state: PrivilegedSessionState = .offline
    public private(set) var serviceHello: ServiceHello?

    public init(transport: any PrivilegedTransport, clientIdentifier: String) { self.transport = transport; self.clientIdentifier = clientIdentifier }
    @discardableResult public func connect() async throws -> ServiceHello {
        if state == .connected, let serviceHello { return serviceHello }
        state = .recovering
        let response = try await transport.send(.handshake(.init(clientIdentifier: clientIdentifier)))
        guard case .hello(let hello) = response else { state = .offline; throw SessionError.handshakeRejected }
        state = .connected; serviceHello = hello; return hello
    }
    public func request(_ request: PrivilegedRequest) async throws -> PrivilegedResponse {
        guard state == .connected else { throw SessionError.notConnected }
        return try await transport.send(request)
    }
    public func reconnect() async throws {
        state = .recovering
        serviceHello = nil
        await transport.reset()
        state = .offline
        _ = try await connect()
    }
}

public enum SessionError: Error, Equatable { case notConnected, handshakeRejected }

public actor InMemoryPrivilegedTransport: PrivilegedTransport {
    public typealias Handler = @Sendable (PrivilegedRequest) async throws -> PrivilegedResponse
    private let handler: Handler
    public init(handler: @escaping Handler) { self.handler = handler }
    public func send(_ request: PrivilegedRequest) async throws -> PrivilegedResponse { try await handler(request) }
}
