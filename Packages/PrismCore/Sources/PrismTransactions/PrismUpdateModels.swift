import Foundation
import PrismDomain

public enum PrismUpdateState: Codable, Sendable, Equatable, Hashable {
    case idle
    case downloading
    case validating
    case staged
    case waitingForSafePoint
    case activating
    case verifying
    case committed
    case rollingBack
    case rolledBack
    case failed(reason: String)
}

public enum PrismUpdateTarget: Codable, Sendable, Equatable, Hashable {
    case prism
    case provider(ProviderIdentity)
}

public struct PrismUpdateCandidate: Codable, Sendable, Equatable, Hashable {
    public let target: PrismUpdateTarget
    public let version: String
    public let metadata: [String: String]

    public init(target: PrismUpdateTarget, version: String, metadata: [String: String] = [:]) {
        self.target = target
        self.version = version
        self.metadata = metadata
    }
}

public struct PrismUpdateSnapshot: Codable, Sendable, Equatable, Hashable {
    public let installedVersion: String
    public let providerRegistrations: [ProviderIdentity]

    public init(installedVersion: String, providerRegistrations: [ProviderIdentity]) {
        self.installedVersion = installedVersion
        self.providerRegistrations = providerRegistrations
    }
}
