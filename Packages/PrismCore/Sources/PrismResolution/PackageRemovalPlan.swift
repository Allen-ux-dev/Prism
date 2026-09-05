import Foundation
import PrismDomain
import PrismEnvironment

public enum PackageRemovalMode: String, Codable, Sendable, Hashable, CaseIterable {
    case remove
    case purge
}

public struct PackageRemovalRequest: Codable, Sendable, Equatable {
    public let packageID: String
    public let mode: PackageRemovalMode
    public let removeUnusedDependencies: Bool

    public init(packageID: String, mode: PackageRemovalMode, removeUnusedDependencies: Bool = false) {
        self.packageID = packageID
        self.mode = mode
        self.removeUnusedDependencies = removeUnusedDependencies
    }
}

public struct PackageRemovalPlan: Codable, Sendable, Equatable {
    public let requested: PrismPackage
    public let mode: PackageRemovalMode
    public let packagesToRemove: [PrismPackage]
    public let preservedSharedDependencies: [PrismPackage]
    public let unmetCapabilities: Set<EnvironmentCapability>
    public let residueCheckRequired: Bool

    public init(
        requested: PrismPackage,
        mode: PackageRemovalMode,
        packagesToRemove: [PrismPackage],
        preservedSharedDependencies: [PrismPackage],
        unmetCapabilities: Set<EnvironmentCapability>,
        residueCheckRequired: Bool = true
    ) {
        self.requested = requested
        self.mode = mode
        self.packagesToRemove = packagesToRemove
        self.preservedSharedDependencies = preservedSharedDependencies
        self.unmetCapabilities = unmetCapabilities
        self.residueCheckRequired = residueCheckRequired
    }

    public var removesConfiguration: Bool { mode == .purge }
    public var isExecutable: Bool { unmetCapabilities.isEmpty }
}

public enum PackageRemovalResolutionError: Error, Equatable {
    case packageNotInstalled(String)
}

public struct PackageRemovalPlanner: Sendable {
    public init() {}

    public func plan(
        request: PackageRemovalRequest,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        environment: PrismEnvironment
    ) throws -> PackageRemovalPlan {
        guard let installedVersion = installed.installedVersions[request.packageID] else {
            throw PackageRemovalResolutionError.packageNotInstalled(request.packageID)
        }

        let requested = catalog.candidates(for: request.packageID).first
            ?? PrismPackage(
                identifier: request.packageID,
                name: request.packageID,
                version: installedVersion,
                distribution: .prismNative,
                installationState: .installed
            )

        var unmet: Set<EnvironmentCapability> = []
        if !environment.capabilities.contains(.packageRemove) { unmet.insert(.packageRemove) }
        if requested.distribution == .debianDeb {
            if !environment.capabilities.contains(.apt) { unmet.insert(.apt) }
            if !environment.capabilities.contains(.dpkg) { unmet.insert(.dpkg) }
        }

        let dependencyIDs = directDependencyIDs(of: requested)
            .filter { installed.installedVersions[$0] != nil }
        let dependencyPackages = dependencyIDs.map { identifier in
            catalog.candidates(for: identifier).first
                ?? PrismPackage(
                    identifier: identifier,
                    name: identifier,
                    version: installed.installedVersions[identifier] ?? .native("0"),
                    distribution: .prismNative,
                    installationState: .installed
                )
        }

        let otherInstalledPackages = catalog.packages.filter {
            $0.identifier != requested.identifier && installed.installedVersions[$0.identifier] != nil
        }
        let sharedIDs = Set(dependencyIDs.filter { dependencyID in
            otherInstalledPackages.contains { directDependencyIDs(of: $0).contains(dependencyID) }
        })

        let preserved: [PrismPackage]
        let cleanup: [PrismPackage]
        if request.removeUnusedDependencies {
            preserved = dependencyPackages.filter { sharedIDs.contains($0.identifier) }
            cleanup = dependencyPackages.filter { !sharedIDs.contains($0.identifier) }
        } else {
            preserved = dependencyPackages
            cleanup = []
        }

        let removals = (cleanup + [requested])
            .reduce(into: [String: PrismPackage]()) { $0[$1.identifier] = $1 }
            .values
            .sorted { $0.identifier < $1.identifier }

        return PackageRemovalPlan(
            requested: requested,
            mode: request.mode,
            packagesToRemove: removals,
            preservedSharedDependencies: preserved.sorted { $0.identifier < $1.identifier },
            unmetCapabilities: unmet,
            residueCheckRequired: true
        )
    }

    private func directDependencyIDs(of package: PrismPackage) -> Set<String> {
        let dependencies = package.dependencyGroups.isEmpty
            ? package.dependencies.map { PackageDependencyGroup(alternatives: [$0]) }
            : package.dependencyGroups
        return Set(dependencies.flatMap { $0.alternatives.map(\.packageIdentifier) })
    }
}
