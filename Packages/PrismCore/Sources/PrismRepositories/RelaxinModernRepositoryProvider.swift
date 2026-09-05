import Foundation
import PrismDomain

public actor RelaxinModernRepositoryProvider: RepositoryProvider, RepositoryProviderProbing {
    public nonisolated let descriptor = PrismProviderDescriptor(
        identifier: "dev.relaxin.repository.modern", kind: .repository, version: "1.1", priority: 100,
        operatingModes: [.modern, .hybrid], supportedFormats: [.relaxinPackage, .prismNative, .prismSource],
        runtimeIdentities: ["dev.relaxin.runtime"], health: .healthy
    )
    private var snapshots: [String: PrismRepositorySnapshot]
    public init(snapshots: [String: PrismRepositorySnapshot] = [:]) { self.snapshots = snapshots }

    public func probe(source: RepositorySource, operationContext: ProviderOperationContext) async -> RepositoryProbeResult {
        guard (try? await operationContext.checkingCancellation()) != nil else {
            return .unsupported(providerID: descriptor.identifier, reason: "cancelled")
        }
        if snapshots[source.identifier] != nil {
            return .init(providerID: descriptor.identifier, confidence: 1, compatibility: .compatible, detectedFormat: "relaxin-modern")
        }
        if ["relaxin", "modern"].contains(source.kind.lowercased()) {
            return .init(providerID: descriptor.identifier, confidence: 0.8, compatibility: .partiallyCompatible, detectedFormat: "relaxin-modern")
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
