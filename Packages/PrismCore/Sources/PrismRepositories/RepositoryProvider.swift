import Foundation
import PrismDomain

public struct RepositoryNormalizationWarning: Codable, Sendable, Equatable, Hashable {
    public let packageIdentifier: String?
    public let field: String
    public let message: String

    public init(packageIdentifier: String?, field: String, message: String) {
        self.packageIdentifier = packageIdentifier
        self.field = field
        self.message = message
    }
}

public struct PrismRepositorySnapshot: Codable, Sendable, Equatable {
    public let repository: PrismRepository
    public let packages: [PrismPackage]
    public let warnings: [RepositoryNormalizationWarning]

    public init(repository: PrismRepository, packages: [PrismPackage], warnings: [RepositoryNormalizationWarning] = []) {
        self.repository = repository
        self.packages = packages
        self.warnings = warnings
    }
}

// Compatibility parser boundary used only by the APT provider.
public protocol RepositoryNormalizer: Sendable {
    func normalizeRepository(metadata: Data, packagesIndex: Data, baseURL: URL) throws -> PrismRepositorySnapshot
}

public struct RepositorySource: Codable, Hashable, Sendable {
    public let identifier: String
    public let url: URL
    public let kind: String
    public init(identifier: String, url: URL, kind: String) {
        self.identifier = identifier
        self.url = url
        self.kind = kind
    }
}

public struct RepositoryRefreshContext: Sendable {
    public let source: RepositorySource
    public init(source: RepositorySource) { self.source = source }
}

public protocol RepositoryResourceLoading: Sendable {
    func data(from url: URL) async throws -> Data
}

public actor ProviderCancellationToken {
    private var cancelled = false
    public init() {}
    public func cancel() { cancelled = true }
    public func isCancelled() -> Bool { cancelled }
}

public struct ProviderOperationContext: Sendable {
    public let operationID: UUID
    public let deadline: Date?
    public let cancellationToken: ProviderCancellationToken

    public init(
        operationID: UUID = UUID(),
        deadline: Date? = nil,
        cancellationToken: ProviderCancellationToken = ProviderCancellationToken()
    ) {
        self.operationID = operationID
        self.deadline = deadline
        self.cancellationToken = cancellationToken
    }

    public func checkingCancellation(now: Date = Date()) async throws {
        if Task.isCancelled {
            throw RepositoryProviderError.operationCancelled
        }
        if await cancellationToken.isCancelled() {
            throw RepositoryProviderError.operationCancelled
        }
        if let deadline, now >= deadline {
            throw RepositoryProviderError.operationTimedOut(operationID.uuidString)
        }
    }
}

public struct RepositoryProbeResult: Codable, Hashable, Sendable {
    public let providerID: String
    public let confidence: Double
    public let compatibility: CompatibilityLevel
    public let detectedFormat: String?
    public let metadata: [String: String]

    public init(
        providerID: String,
        confidence: Double,
        compatibility: CompatibilityLevel,
        detectedFormat: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.providerID = providerID
        self.confidence = min(max(confidence, 0), 1)
        self.compatibility = compatibility
        self.detectedFormat = detectedFormat
        self.metadata = metadata
    }

    public static func unsupported(providerID: String, reason: String? = nil) -> Self {
        .init(
            providerID: providerID,
            confidence: 0,
            compatibility: .unsupported,
            metadata: reason.map { ["reason": $0] } ?? [:]
        )
    }

    public var isSupported: Bool {
        confidence > 0 && compatibility != .unsupported
    }
}

public protocol RepositoryProviderProbing: PrismProvider {
    func probe(source: RepositorySource, operationContext: ProviderOperationContext) async -> RepositoryProbeResult
}

public protocol RepositoryProvider: PrismProvider {
    func refresh(_ context: RepositoryRefreshContext) async throws -> PrismRepositorySnapshot
    func refresh(_ context: RepositoryRefreshContext, operationContext: ProviderOperationContext) async throws -> PrismRepositorySnapshot
    func catalog(repositoryID: String) async -> [PrismPackage]
    func package(_ identifier: String, repositoryID: String) async -> PrismPackage?
    func metadata(repositoryID: String) async -> [String: String]
    func health(repositoryID: String) async -> ProviderHealth
}

public extension RepositoryProvider {
    func refresh(_ context: RepositoryRefreshContext, operationContext: ProviderOperationContext) async throws -> PrismRepositorySnapshot {
        try await operationContext.checkingCancellation()
        let snapshot = try await refresh(context)
        try await operationContext.checkingCancellation()
        return snapshot
    }
}

public enum RepositoryProviderError: Error, Equatable, Sendable {
    case resourceUnavailable(String)
    case noPackagesIndex
    case repositoryNotLoaded(String)
    case unsupportedSourceKind(String)
    case noCompatibleProvider(String)
    case operationTimedOut(String)
    case operationCancelled
}
