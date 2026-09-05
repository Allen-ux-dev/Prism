import Foundation

public enum RepositoryRefreshState: String, Codable, Sendable, Hashable {
    case idle
    case refreshing
    case ready
    case failed
}

public enum RepositoryTrustState: String, Codable, Sendable, Hashable {
    case unknown
    case trusted
    case warning
    case rejected
}

public struct PrismRepository: Codable, Sendable, Hashable {
    public let identity: String
    public let baseURL: URL
    public let metadata: [String: String]
    public let providerIdentifier: String
    public let packages: [PrismPackage]
    public let refreshState: RepositoryRefreshState
    public let trustState: RepositoryTrustState
    public let lastRefresh: Date?
    // Provider-normalized presentation fields. Optional for backward decoding compatibility.
    public let displayName: String?
    public let iconURLs: [URL]?
    public let summary: String?
    public let compatibility: CompatibilityLevel?
    public let providerMetadata: [String: String]?

    public init(
        identity: String,
        baseURL: URL,
        metadata: [String: String] = [:],
        providerIdentifier: String,
        packages: [PrismPackage] = [],
        refreshState: RepositoryRefreshState = .idle,
        trustState: RepositoryTrustState = .unknown,
        lastRefresh: Date? = nil,
        displayName: String? = nil,
        iconURLs: [URL]? = nil,
        summary: String? = nil,
        compatibility: CompatibilityLevel? = nil,
        providerMetadata: [String: String]? = nil
    ) {
        self.identity = identity
        self.baseURL = baseURL
        self.metadata = metadata
        self.providerIdentifier = providerIdentifier
        self.packages = packages
        self.refreshState = refreshState
        self.trustState = trustState
        self.lastRefresh = lastRefresh
        self.displayName = displayName
        self.iconURLs = iconURLs
        self.summary = summary
        self.compatibility = compatibility
        self.providerMetadata = providerMetadata
    }
}

public extension PrismRepository {
    var trustStatus: RepositoryTrustStatus {
        switch trustState {
        case .trusted: return .trusted
        case .warning: return .unverified
        case .rejected: return .invalid
        case .unknown: return .unknown
        }
    }
}
