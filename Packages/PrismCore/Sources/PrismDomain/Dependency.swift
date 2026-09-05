import Foundation

public enum VersionRelation: String, Codable, Sendable, Hashable {
    case equal
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
}

public struct PackageDependency: Codable, Sendable, Hashable {
    public let packageIdentifier: String
    public let relation: VersionRelation?
    public let requiredVersion: PackageVersion?

    public init(
        packageIdentifier: String,
        relation: VersionRelation? = nil,
        requiredVersion: PackageVersion? = nil
    ) {
        self.packageIdentifier = packageIdentifier
        self.relation = relation
        self.requiredVersion = requiredVersion
    }

    public func isSatisfied(by installedVersion: PackageVersion, registry: VersionSchemeRegistry = .standard) -> Bool {
        guard let relation, let requiredVersion else { return true }
        return (try? registry.satisfies(installedVersion, constraint: .init(relation: relation, version: requiredVersion))) ?? false
    }

    public func isSatisfied(by installedVersion: DebianVersion, registry: VersionSchemeRegistry = .standard) -> Bool {
        isSatisfied(by: PackageVersion(installedVersion), registry: registry)
    }

    public init(packageIdentifier: String, relation: VersionRelation? = nil, requiredVersion: DebianVersion?) {
        self.packageIdentifier = packageIdentifier
        self.relation = relation
        self.requiredVersion = requiredVersion.map(PackageVersion.init)
    }
}

public struct PackageDependencyGroup: Codable, Sendable, Hashable {
    public let alternatives: [PackageDependency]
    public init(alternatives: [PackageDependency]) { self.alternatives = alternatives }
}
