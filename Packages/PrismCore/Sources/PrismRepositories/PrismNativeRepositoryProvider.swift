import Foundation
import PrismDomain

public actor PrismNativeRepositoryProvider: RepositoryProvider, RepositoryProviderProbing {
    public nonisolated let descriptor = PrismProviderDescriptor(
        identifier: "dev.prism.repository.native", kind: .repository, version: "2.1", priority: 60,
        operatingModes: [.modern, .hybrid], supportedFormats: [.prismNative, .prismSource], health: .healthy
    )
    private var snapshots: [String: PrismRepositorySnapshot]
    public init(snapshots: [String: PrismRepositorySnapshot] = [:]) { self.snapshots = snapshots }

    public func probe(source: RepositorySource, operationContext: ProviderOperationContext) async -> RepositoryProbeResult {
        guard (try? await operationContext.checkingCancellation()) != nil else {
            return .unsupported(providerID: descriptor.identifier, reason: "cancelled")
        }
        if snapshots[source.identifier] != nil {
            return .init(providerID: descriptor.identifier, confidence: 0.95, compatibility: .compatible, detectedFormat: "prism-native")
        }
        if ["prism", "native"].contains(source.kind.lowercased()) {
            return .init(providerID: descriptor.identifier, confidence: 0.75, compatibility: .partiallyCompatible, detectedFormat: "prism-native")
        }
        return .unsupported(providerID: descriptor.identifier)
    }

    public func refresh(_ context: RepositoryRefreshContext) async throws -> PrismRepositorySnapshot {
        guard let snapshot = snapshots[context.source.identifier] else { throw RepositoryProviderError.repositoryNotLoaded(context.source.identifier) }
        return snapshot
    }
    public func refresh(_ context: RepositoryRefreshContext, operationContext: ProviderOperationContext) async throws -> PrismRepositorySnapshot {
        try await operationContext.checkingCancellation()
        let snapshot = try await refresh(context)
        try await operationContext.checkingCancellation()
        return snapshot
    }
    public func catalog(repositoryID: String) async -> [PrismPackage] { snapshots[repositoryID]?.packages ?? [] }
    public func package(_ identifier: String, repositoryID: String) async -> PrismPackage? { snapshots[repositoryID]?.packages.first { $0.identifier == identifier } }
    public func metadata(repositoryID: String) async -> [String : String] { snapshots[repositoryID]?.repository.metadata ?? [:] }
    public func health(repositoryID: String) async -> ProviderHealth { snapshots[repositoryID] == nil ? .unknown("not registered") : .healthy }
}
