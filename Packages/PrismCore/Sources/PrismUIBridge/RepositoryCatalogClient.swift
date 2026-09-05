import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import PrismDomain
import PrismRepositories

public protocol RepositoryDataFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

public enum RepositoryNetworkError: Error, Equatable { case badStatus(Int), noPackagesIndex }

public struct URLSessionRepositoryDataFetcher: RepositoryDataFetching, Sendable {
    public init() {}
    public func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { throw RepositoryNetworkError.badStatus(http.statusCode) }
        return data
    }
}

private struct RepositoryDataFetcherAdapter: RepositoryResourceLoading, Sendable {
    let fetcher: any RepositoryDataFetching
    func data(from url: URL) async throws -> Data { try await fetcher.data(from: url) }
}

public struct RepositorySourceVisual: Sendable, Hashable {
    public let displayName: String
    public let iconURLs: [String]
    public let commerceProviderIdentifier: String?
    public let providerIdentifier: String?
    public let refreshState: String
    public let trustLabel: String
    public let compatibilityLabel: String
    public let lastRefresh: Date?
    public let summary: String?

    public init(
        displayName: String,
        iconURLs: [String],
        commerceProviderIdentifier: String? = nil,
        providerIdentifier: String? = nil,
        refreshState: String = "Ready",
        trustLabel: String = "Unknown",
        compatibilityLabel: String = "Unknown",
        lastRefresh: Date? = nil,
        summary: String? = nil
    ) {
        self.displayName = displayName
        self.iconURLs = iconURLs
        self.commerceProviderIdentifier = commerceProviderIdentifier
        self.providerIdentifier = providerIdentifier
        self.refreshState = refreshState
        self.trustLabel = trustLabel
        self.compatibilityLabel = compatibilityLabel
        self.lastRefresh = lastRefresh
        self.summary = summary
    }
}

public struct RepositoryCatalogResult: Sendable {
    public let packages: [PrismPackage]
    public let sourceCounts: [String: Int]
    public let sourceVisuals: [String: RepositorySourceVisual]
    public let packageIconURLs: [String: String]
    public let repositoryBaseURLsByID: [String: String]
    public let warnings: [String]

    public init(
        packages: [PrismPackage],
        sourceCounts: [String: Int],
        sourceVisuals: [String: RepositorySourceVisual] = [:],
        packageIconURLs: [String: String] = [:],
        repositoryBaseURLsByID: [String: String] = [:],
        warnings: [String]
    ) {
        self.packages = packages
        self.sourceCounts = sourceCounts
        self.sourceVisuals = sourceVisuals
        self.packageIconURLs = packageIconURLs
        self.repositoryBaseURLsByID = repositoryBaseURLsByID
        self.warnings = warnings
    }
}

public struct RepositoryCatalogClient: Sendable {
    private let resolver: RepositoryProviderResolver

    public init(fetcher: any RepositoryDataFetching = URLSessionRepositoryDataFetcher()) {
        let loader = RepositoryDataFetcherAdapter(fetcher: fetcher)
        self.resolver = RepositoryProviderResolver(
            providers: [
                RelaxinModernRepositoryProvider(),
                PrismNativeRepositoryProvider(),
                APTRepositoryProvider(loader: loader)
            ]
        )
    }

    public init(resolver: RepositoryProviderResolver) {
        self.resolver = resolver
    }

    public func load(sourceURLs: [URL]) async -> RepositoryCatalogResult {
        var packages: [PrismPackage] = []
        var counts: [String: Int] = [:]
        var sourceVisuals: [String: RepositorySourceVisual] = [:]
        var packageIconURLs: [String: String] = [:]
        var repositoryBaseURLsByID: [String: String] = [:]
        var warnings: [String] = []

        for base in sourceURLs {
            let sourceID = base.absoluteString
            let source = RepositorySource(identifier: sourceID, url: base, kind: "auto")
            do {
                let snapshot = try await resolver.refresh(source: source)
                packages.append(contentsOf: snapshot.packages)
                counts[sourceID] = snapshot.packages.count
                sourceVisuals[sourceID] = sourceVisual(for: snapshot.repository, baseURL: base)
                repositoryBaseURLsByID[snapshot.repository.identity] = base.absoluteString
                for package in snapshot.packages {
                    if let icon = package.iconURL {
                        packageIconURLs[package.identifier] = icon.absoluteString
                    }
                }
                warnings.append(contentsOf: snapshot.warnings.map { "\($0.field): \($0.message)" })
            } catch {
                counts[sourceID] = 0
                warnings.append("\(sourceID): \(error)")
            }
        }

        let sorted = packages.sorted { lhs, rhs in
            if lhs.identifier != rhs.identifier { return lhs.identifier < rhs.identifier }
            if lhs.version != rhs.version { return lhs.version > rhs.version }
            return (lhs.repositoryID ?? "") < (rhs.repositoryID ?? "")
        }
        return .init(
            packages: sorted,
            sourceCounts: counts,
            sourceVisuals: sourceVisuals,
            packageIconURLs: packageIconURLs,
            repositoryBaseURLsByID: repositoryBaseURLsByID,
            warnings: warnings
        )
    }

    private func sourceVisual(for repository: PrismRepository, baseURL: URL) -> RepositorySourceVisual {
        .init(
            displayName: repository.displayName ?? baseURL.host ?? baseURL.absoluteString,
            iconURLs: (repository.iconURLs ?? []).map(\.absoluteString),
            commerceProviderIdentifier: repository.providerMetadata?["commerceProviderIdentifier"],
            providerIdentifier: repository.providerIdentifier,
            refreshState: repository.refreshState.rawValue.capitalized,
            trustLabel: repository.trustState.rawValue.capitalized,
            compatibilityLabel: repository.compatibility?.rawValue ?? "unknown",
            lastRefresh: repository.lastRefresh,
            summary: repository.summary
        )
    }
}
