import Foundation

public enum PackageInstallationState: String, Codable, Sendable, Hashable {
    case notInstalled
    case installed
    case updateAvailable
    case installing
    case removing
    case broken
    case unknown
}

public struct PackageRequirement: Codable, Sendable, Hashable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

public struct PrismPackage: Sendable, Codable, Hashable {
    public let identifier: String
    public let name: String
    public let version: PackageVersion
    public let architecture: String
    public let author: String?
    public let description: String
    public let repositoryID: String?
    public let dependencies: [PackageDependency]
    public let dependencyGroups: [PackageDependencyGroup]
    public let conflicts: [PackageDependency]
    public let requirements: [PackageRequirement]
    public let distribution: PackageFormatIdentifier
    public let installationState: PackageInstallationState
    public let metadata: [String: String]
    public let iconURL: URL?

    public init(
        identifier: String,
        name: String? = nil,
        version: PackageVersion = .native("0"),
        architecture: String = "unknown",
        author: String? = nil,
        description: String = "",
        repositoryID: String? = nil,
        dependencies: [PackageDependency] = [],
        dependencyGroups: [PackageDependencyGroup] = [],
        conflicts: [PackageDependency] = [],
        requirements: [PackageRequirement] = [],
        distribution: PackageFormatIdentifier = .prismNative,
        installationState: PackageInstallationState = .unknown,
        metadata: [String: String] = [:],
        iconURL: URL? = nil
    ) {
        self.identifier = identifier
        self.name = name ?? identifier
        self.version = version
        self.architecture = architecture
        self.author = author
        self.description = description
        self.repositoryID = repositoryID
        self.dependencies = dependencies
        self.dependencyGroups = dependencyGroups
        self.conflicts = conflicts
        self.requirements = requirements
        self.distribution = distribution
        self.installationState = installationState
        self.metadata = metadata
        self.iconURL = iconURL
    }

    public init(
        identifier: String,
        name: String? = nil,
        version: DebianVersion,
        architecture: String = "unknown",
        author: String? = nil,
        description: String = "",
        repositoryID: String? = nil,
        dependencies: [PackageDependency] = [],
        dependencyGroups: [PackageDependencyGroup] = [],
        conflicts: [PackageDependency] = [],
        requirements: [PackageRequirement] = [],
        distribution: PackageFormatIdentifier = .debianDeb,
        installationState: PackageInstallationState = .unknown,
        metadata: [String: String] = [:],
        iconURL: URL? = nil
    ) {
        self.init(
            identifier: identifier, name: name, version: PackageVersion(version), architecture: architecture, author: author,
            description: description, repositoryID: repositoryID, dependencies: dependencies, dependencyGroups: dependencyGroups,
            conflicts: conflicts, requirements: requirements, distribution: distribution, installationState: installationState, metadata: metadata, iconURL: iconURL
        )
    }
}

public extension PrismPackage {
    var trustStatus: PackageTrustStatus {
        switch metadata["TrustStatus"]?.lowercased() {
        case "trusted": return .trusted
        case "verified": return .verified
        case "unverified": return .unverified
        case "invalid": return .invalid
        default: return .unknown
        }
    }
}
