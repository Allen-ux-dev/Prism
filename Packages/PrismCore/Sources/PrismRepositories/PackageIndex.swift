import Foundation
import PrismDomain

public struct PackageIndexSnapshot: Codable, Sendable, Equatable {
    public let packages: [PrismPackage]
    public let generatedAt: Date
    public init(packages: [PrismPackage], generatedAt: Date = Date()) { self.packages = packages; self.generatedAt = generatedAt }
}

public actor PackageIndexStore {
    private var snapshot = PackageIndexSnapshot(packages: [])
    public init() {}
    public func current() -> PackageIndexSnapshot { snapshot }
    public func replace(with newSnapshot: PackageIndexSnapshot) { snapshot = newSnapshot }
}

public struct SearchService: Sendable {
    public init() {}
    public func search(_ query: String, in snapshot: PackageIndexSnapshot) -> [PrismPackage] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return snapshot.packages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
        return snapshot.packages.compactMap { package -> (PrismPackage, Int)? in
            let id = package.identifier.lowercased(), name = package.name.lowercased()
            let author = package.author?.lowercased() ?? "", desc = package.description.lowercased()
            let score: Int
            if id == needle { score = 0 }
            else if name == needle { score = 1 }
            else if id.hasPrefix(needle) { score = 2 }
            else if name.hasPrefix(needle) { score = 3 }
            else if name.contains(needle) || id.contains(needle) { score = 4 }
            else if author.contains(needle) { score = 5 }
            else if desc.contains(needle) { score = 6 }
            else { return nil }
            return (package, score)
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            if lhs.0.name != rhs.0.name { return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending }
            return lhs.0.identifier < rhs.0.identifier
        }.map(\.0)
    }
}

public actor RepositoryRefreshService {
    private let index: PackageIndexStore
    public init(index: PackageIndexStore) { self.index = index }
    public func commit(repositories: [PrismRepository]) async {
        let packages = repositories.flatMap(\.packages)
        await index.replace(with: PackageIndexSnapshot(packages: packages))
    }
}
