import Foundation
import PrismDomain

public actor APTRepositoryProvider: RepositoryProvider, RepositoryProviderProbing {
    public nonisolated let descriptor = PrismProviderDescriptor(
        identifier: "org.prism.repository.apt",
        kind: .repository,
        version: "2.1",
        priority: 20,
        operatingModes: [.modern, .hybrid, .legacy],
        supportedFormats: [.debianDeb],
        health: .healthy,
        diagnosticsMetadata: ["compatibility": "APT/Sileo/Zebra"]
    )

    private let loader: any RepositoryResourceLoading
    private let normalizer = SileoRepositoryProvider()
    private let decoder = RepositoryPayloadDecoder()
    private var snapshots: [String: PrismRepositorySnapshot] = [:]
    private var healthStates: [String: ProviderHealth] = [:]

    public init(loader: any RepositoryResourceLoading) { self.loader = loader }

    public func probe(source: RepositorySource, operationContext: ProviderOperationContext) async -> RepositoryProbeResult {
        let acceptedKinds: Set<String> = ["auto", "apt", "sileo", "zebra", "debian"]
        guard acceptedKinds.contains(source.kind.lowercased()) else {
            return .unsupported(providerID: descriptor.identifier, reason: "source kind is not APT-compatible")
        }
        do {
            try await operationContext.checkingCancellation()
            _ = try await loadPackages(baseURL: source.url, operationContext: operationContext)
            try await operationContext.checkingCancellation()
            return .init(
                providerID: descriptor.identifier,
                confidence: source.kind == "auto" ? 0.90 : 0.98,
                compatibility: .compatible,
                detectedFormat: "apt",
                metadata: ["compatibility": "APT/Sileo/Zebra"]
            )
        } catch {
            return .unsupported(providerID: descriptor.identifier, reason: String(describing: error))
        }
    }

    public func refresh(_ context: RepositoryRefreshContext) async throws -> PrismRepositorySnapshot {
        try await refresh(context, operationContext: .init())
    }

    public func refresh(_ context: RepositoryRefreshContext, operationContext: ProviderOperationContext) async throws -> PrismRepositorySnapshot {
        let acceptedKinds: Set<String> = ["auto", "apt", "sileo", "zebra", "debian"]
        guard acceptedKinds.contains(context.source.kind.lowercased()) else {
            throw RepositoryProviderError.unsupportedSourceKind(context.source.kind)
        }
        do {
            try await operationContext.checkingCancellation()
            let release = (try? await loader.data(from: context.source.url.appendingPathComponent("Release"))) ?? Data()
            try await operationContext.checkingCancellation()
            let packages = try await loadPackages(baseURL: context.source.url, operationContext: operationContext)
            var snapshot = try normalizer.normalizeRepository(metadata: release, packagesIndex: packages, baseURL: context.source.url)
            try await operationContext.checkingCancellation()
            let normalizedPackages = snapshot.packages.map { package in
                PrismPackage(
                    identifier: package.identifier,
                    name: package.name,
                    version: package.version,
                    architecture: package.architecture,
                    author: package.author,
                    description: package.description,
                    repositoryID: context.source.identifier,
                    dependencies: package.dependencies,
                    dependencyGroups: package.dependencyGroups,
                    conflicts: package.conflicts,
                    requirements: package.requirements,
                    distribution: package.distribution,
                    installationState: package.installationState,
                    metadata: package.metadata,
                    iconURL: package.iconURL
                )
            }

            let repository = PrismRepository(
                identity: context.source.identifier,
                baseURL: snapshot.repository.baseURL,
                metadata: snapshot.repository.metadata,
                providerIdentifier: descriptor.identifier,
                packages: normalizedPackages,
                refreshState: .ready,
                trustState: snapshot.repository.trustState,
                lastRefresh: Date(),
                displayName: snapshot.repository.displayName,
                iconURLs: snapshot.repository.iconURLs,
                summary: snapshot.repository.summary,
                compatibility: snapshot.repository.compatibility,
                providerMetadata: snapshot.repository.providerMetadata
            )
            snapshot = PrismRepositorySnapshot(repository: repository, packages: normalizedPackages, warnings: snapshot.warnings)
            snapshots[context.source.identifier] = snapshot
            healthStates[context.source.identifier] = .healthy
            return snapshot
        } catch {
            healthStates[context.source.identifier] = .degraded(String(describing: error))
            if let previous = snapshots[context.source.identifier] { return previous }
            throw error
        }
    }

    public func catalog(repositoryID: String) async -> [PrismPackage] { snapshots[repositoryID]?.packages ?? [] }
    public func package(_ identifier: String, repositoryID: String) async -> PrismPackage? { snapshots[repositoryID]?.packages.first { $0.identifier == identifier } }
    public func metadata(repositoryID: String) async -> [String: String] { snapshots[repositoryID]?.repository.metadata ?? [:] }
    public func health(repositoryID: String) async -> ProviderHealth { healthStates[repositoryID] ?? .unknown("not refreshed") }

    private func loadPackages(baseURL: URL, operationContext: ProviderOperationContext) async throws -> Data {
        for (name, encoding) in [("Packages", RepositoryPayloadEncoding.plain), ("Packages.gz", .gzip)] {
            do {
                try await operationContext.checkingCancellation()
                let raw = try await loader.data(from: baseURL.appendingPathComponent(name))
                try await operationContext.checkingCancellation()
                return try decoder.decode(raw, encoding: encoding)
            } catch RepositoryProviderError.operationCancelled {
                throw RepositoryProviderError.operationCancelled
            } catch RepositoryProviderError.operationTimedOut(let id) {
                throw RepositoryProviderError.operationTimedOut(id)
            } catch {
                continue
            }
        }
        throw RepositoryProviderError.noPackagesIndex
    }
}
