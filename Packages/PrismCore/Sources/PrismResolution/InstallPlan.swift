import Foundation
import PrismDomain
import PrismEnvironment

public struct InstallRequest: Codable, Sendable, Equatable {
    public let packageIDs: [String]

    public init(packageIDs: [String]) {
        self.packageIDs = packageIDs
    }
}

public struct PackageCatalogSnapshot: Codable, Sendable, Equatable {
    public let packages: [PrismPackage]

    public init(packages: [PrismPackage]) {
        self.packages = packages
    }

    public func candidates(for identifier: String) -> [PrismPackage] {
        packages
            .filter { $0.identifier == identifier }
            .sorted {
                if $0.version != $1.version { return $0.version > $1.version }
                return $0.identifier < $1.identifier
            }
    }
}

public struct PackageStateSnapshot: Codable, Sendable, Equatable {
    public let installedVersions: [String: PackageVersion]

    public init(installedVersions: [String: PackageVersion]) {
        self.installedVersions = installedVersions
    }
}

public struct PackageUpgrade: Codable, Sendable, Equatable {
    public let fromVersion: PackageVersion
    public let package: PrismPackage

    public init(fromVersion: PackageVersion, package: PrismPackage) {
        self.fromVersion = fromVersion
        self.package = package
    }
}

public struct PackageConflict: Codable, Sendable, Equatable {
    public let packageIdentifier: String
    public let conflictingPackageIdentifier: String

    public init(packageIdentifier: String, conflictingPackageIdentifier: String) {
        self.packageIdentifier = packageIdentifier
        self.conflictingPackageIdentifier = conflictingPackageIdentifier
    }
}

public struct InstallPlan: Codable, Sendable, Equatable {
    public let requested: [PrismPackage]
    public let installs: [PrismPackage]
    public let upgrades: [PackageUpgrade]
    public let removals: [PrismPackage]
    public let unresolvedConflicts: [PackageConflict]
    public let unmetCapabilities: Set<EnvironmentCapability>

    public init(
        requested: [PrismPackage],
        installs: [PrismPackage],
        upgrades: [PackageUpgrade],
        removals: [PrismPackage],
        unresolvedConflicts: [PackageConflict],
        unmetCapabilities: Set<EnvironmentCapability>
    ) {
        self.requested = requested
        self.installs = installs
        self.upgrades = upgrades
        self.removals = removals
        self.unresolvedConflicts = unresolvedConflicts
        self.unmetCapabilities = unmetCapabilities
    }

    public var isExecutable: Bool {
        unresolvedConflicts.isEmpty && unmetCapabilities.isEmpty
    }
}

public protocol InstallPlanning: Sendable {
    func plan(
        request: InstallRequest,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        environment: PrismEnvironment
    ) throws -> InstallPlan
}

public enum ResolutionError: Error, Equatable {
    case packageNotFound(String)
    case unsatisfiedDependency(package: String, dependency: String)
    case dependencyCycle([String])
}
