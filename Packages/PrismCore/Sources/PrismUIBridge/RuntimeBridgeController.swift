import Foundation
import PrismPrivilegedProtocol

public enum PrismRuntimeBridgeConnectionState: String, Codable, Sendable, Hashable {
    case offline
    case connected
    case degraded
}

public enum PrismRuntimeBackgroundState: String, Codable, Sendable, Hashable {
    case unsupported
    case disabled
    case starting
    case active
    case degraded
}

public struct PrismRuntimeBridgeStatus: Codable, Sendable, Hashable {
    public let connectionState: PrismRuntimeBridgeConnectionState
    public let runtimeDisplayName: String?
    public let applicationProviderIdentifier: String?
    public let injectionProviderIdentifier: String?
    public let backgroundSupported: Bool
    public let backgroundState: PrismRuntimeBackgroundState
    public let lastError: String?

    public init(
        connectionState: PrismRuntimeBridgeConnectionState = .offline,
        runtimeDisplayName: String? = nil,
        applicationProviderIdentifier: String? = nil,
        injectionProviderIdentifier: String? = nil,
        backgroundSupported: Bool = false,
        backgroundState: PrismRuntimeBackgroundState = .unsupported,
        lastError: String? = nil
    ) {
        self.connectionState = connectionState
        self.runtimeDisplayName = runtimeDisplayName
        self.applicationProviderIdentifier = applicationProviderIdentifier
        self.injectionProviderIdentifier = injectionProviderIdentifier
        self.backgroundSupported = backgroundSupported
        self.backgroundState = backgroundState
        self.lastError = lastError
    }
}

public enum RuntimeBridgeControllerError: Error, Equatable, Sendable {
    case rejected(String)
    case unexpectedResponse
}

public actor RuntimeBridgeController {
    private let session: PrivilegedSessionManager

    public init(socketPath: String, clientIdentifier: String = "dev.allenux.prism") {
        self.session = PrivilegedSessionManager(
            transport: UnixSocketPrivilegedTransport(path: socketPath),
            clientIdentifier: clientIdentifier
        )
    }

    public init(session: PrivilegedSessionManager) {
        self.session = session
    }

    public func status() async throws -> PrismRuntimeBridgeStatus {
        _ = try await session.connect()
        return try mapStatus(try await session.request(.queryRuntimeBridgeStatus))
    }

    public func reconnect() async throws -> PrismRuntimeBridgeStatus {
        _ = try await session.connect()
        return try mapStatus(try await session.request(.reconnectRuntimeBridge))
    }

    public func setBackgroundEnabled(_ enabled: Bool) async throws -> PrismRuntimeBridgeStatus {
        _ = try await session.connect()
        return try mapStatus(try await session.request(.setRuntimeBackgroundEnabled(enabled)))
    }

    private func mapStatus(_ response: PrivilegedResponse) throws -> PrismRuntimeBridgeStatus {
        switch response {
        case .runtimeBridgeStatus(let status):
            return PrismRuntimeBridgeStatus(
                connectionState: map(status.connectionState),
                runtimeDisplayName: status.runtimeDisplayName,
                applicationProviderIdentifier: status.applicationProviderIdentifier,
                injectionProviderIdentifier: status.injectionProviderIdentifier,
                backgroundSupported: status.backgroundSupported,
                backgroundState: map(status.backgroundState),
                lastError: status.lastError
            )
        case .rejected(let reason):
            throw RuntimeBridgeControllerError.rejected(reason)
        default:
            throw RuntimeBridgeControllerError.unexpectedResponse
        }
    }

    private func map(_ state: RuntimeBridgeConnectionState) -> PrismRuntimeBridgeConnectionState {
        switch state {
        case .offline: return .offline
        case .connected: return .connected
        case .degraded: return .degraded
        }
    }

    private func map(_ state: RuntimeBackgroundSessionState) -> PrismRuntimeBackgroundState {
        switch state {
        case .unsupported: return .unsupported
        case .disabled: return .disabled
        case .starting: return .starting
        case .active: return .active
        case .degraded: return .degraded
        }
    }
}
