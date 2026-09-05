import Foundation
import PrismDomain
import PrismTransactions

public enum RuntimeServiceProviderKind: String, Codable, Sendable, Hashable {
    case native
    case compatibility
}

public enum RuntimeBackgroundSessionState: String, Codable, Sendable, Hashable {
    case unsupported
    case disabled
    case starting
    case active
    case degraded
}

public struct RuntimeServiceHelloRequest: Codable, Sendable, Hashable {
    public let clientIdentifier: String
    public let supportedProtocolVersions: [Int]

    public init(clientIdentifier: String, supportedProtocolVersions: [Int] = [1]) {
        self.clientIdentifier = clientIdentifier
        self.supportedProtocolVersions = supportedProtocolVersions
    }
}

public struct RuntimeServiceHello: Codable, Sendable, Hashable {
    public let runtimeIdentity: String
    public let displayName: String
    public let serviceVersion: String
    public let selectedProtocolVersion: Int
    public let providerKind: RuntimeServiceProviderKind
    public let priority: Int
    public let capabilityStates: [CapabilityIdentifier: CapabilityState]
    public let health: ProviderHealth
    public let backgroundSessionState: RuntimeBackgroundSessionState
    public let metadata: [String: String]

    public init(
        runtimeIdentity: String,
        displayName: String,
        serviceVersion: String,
        selectedProtocolVersion: Int,
        providerKind: RuntimeServiceProviderKind,
        priority: Int = 0,
        capabilityStates: [CapabilityIdentifier: CapabilityState],
        health: ProviderHealth,
        backgroundSessionState: RuntimeBackgroundSessionState = .disabled,
        metadata: [String: String] = [:]
    ) {
        self.runtimeIdentity = runtimeIdentity
        self.displayName = displayName
        self.serviceVersion = serviceVersion
        self.selectedProtocolVersion = selectedProtocolVersion
        self.providerKind = providerKind
        self.priority = priority
        self.capabilityStates = capabilityStates
        self.health = health
        self.backgroundSessionState = backgroundSessionState
        self.metadata = metadata
    }
}

public enum RuntimeServiceRequest: Codable, Sendable, Hashable {
    case handshake(RuntimeServiceHelloRequest)
    case inspectInstalledApps
    case inspectRegisteredBundleIdentifiers
    case install(AppInstallOperation)
    case replace(AppInstallOperation)
    case removeApp(String)
    case registerApp(String)
    case refreshApp(String)
    case inspectActiveInjections
    case applyInjection(InjectionOperation)
    case removeInjection(targetBundleIdentifier: String, artifactIdentifier: String)
    case queryBackgroundSession
    case setBackgroundSessionEnabled(Bool)
}

public enum RuntimeServiceResponse: Codable, Sendable {
    case hello(RuntimeServiceHello)
    case installedApps([String: PrismInstalledApp])
    case registeredBundleIdentifiers(Set<String>)
    case activeInjections(Set<InjectionStateKey>)
    case operation(BackendOperationResult)
    case backgroundSession(RuntimeBackgroundSessionState)
    case accepted
    case rejected(String)
}


public enum RuntimeBridgeConnectionState: String, Codable, Sendable, Hashable {
    case offline
    case connected
    case degraded
}

public struct RuntimeServiceBridgeStatus: Codable, Sendable, Hashable {
    public let connectionState: RuntimeBridgeConnectionState
    public let runtimeDisplayName: String?
    public let applicationProviderIdentifier: String?
    public let injectionProviderIdentifier: String?
    public let backgroundSupported: Bool
    public let backgroundState: RuntimeBackgroundSessionState
    public let lastError: String?

    public init(
        connectionState: RuntimeBridgeConnectionState = .offline,
        runtimeDisplayName: String? = nil,
        applicationProviderIdentifier: String? = nil,
        injectionProviderIdentifier: String? = nil,
        backgroundSupported: Bool = false,
        backgroundState: RuntimeBackgroundSessionState = .unsupported,
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

public enum RuntimeServiceProtocolError: Error, Equatable, Sendable {
    case handshakeRejected(String)
    case incompatibleProtocol
    case unexpectedResponse
    case disconnected
    case capabilityUnavailable(String)
}
