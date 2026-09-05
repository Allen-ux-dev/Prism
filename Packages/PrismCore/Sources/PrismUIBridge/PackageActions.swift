import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution

public struct PrismPackageChangeRow: Codable, Sendable, Hashable, Identifiable {
    public let identifier: String
    public let name: String
    public let version: String
    public var id: String { "\(identifier):\(version)" }

    public init(identifier: String, name: String, version: String) {
        self.identifier = identifier
        self.name = name
        self.version = version
    }

    init(package: PrismPackage) {
        self.init(identifier: package.identifier, name: package.name, version: package.version.rawValue)
    }
}

public struct PrismPackageUpgradeRow: Codable, Sendable, Hashable, Identifiable {
    public let identifier: String
    public let name: String
    public let fromVersion: String
    public let toVersion: String
    public var id: String { "\(identifier):\(fromVersion):\(toVersion)" }

    init(upgrade: PackageUpgrade) {
        identifier = upgrade.package.identifier
        name = upgrade.package.name
        fromVersion = upgrade.fromVersion.rawValue
        toVersion = upgrade.package.version.rawValue
    }
}

public struct PrismInstallPlanReview: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let requestedPackageID: String
    public let installs: [PrismPackageChangeRow]
    public let upgrades: [PrismPackageUpgradeRow]
    public let removals: [PrismPackageChangeRow]
    public let conflicts: [String]
    public let unmetCapabilities: [String]
    public let isExecutable: Bool

    init(id: UUID = UUID(), requestedPackageID: String, plan: InstallPlan) {
        self.id = id
        self.requestedPackageID = requestedPackageID
        installs = plan.installs.map(PrismPackageChangeRow.init(package:))
        upgrades = plan.upgrades.map(PrismPackageUpgradeRow.init(upgrade:))
        removals = plan.removals.map(PrismPackageChangeRow.init(package:))
        conflicts = plan.unresolvedConflicts.map { "\($0.packageIdentifier) conflicts with \($0.conflictingPackageIdentifier)" }
        unmetCapabilities = plan.unmetCapabilities.map(\.rawValue).sorted()
        isExecutable = plan.isExecutable
    }
}


public struct PrismPackageRemovalReview: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let requestedPackageID: String
    public let mode: PackageRemovalMode
    public let packagesToRemove: [PrismPackageChangeRow]
    public let preservedDependencies: [PrismPackageChangeRow]
    public let unmetCapabilities: [String]
    public let removesConfiguration: Bool
    public let residueCheckRequired: Bool
    public let isExecutable: Bool

    init(id: UUID = UUID(), plan: PackageRemovalPlan) {
        self.id = id
        requestedPackageID = plan.requested.identifier
        mode = plan.mode
        packagesToRemove = plan.packagesToRemove.map(PrismPackageChangeRow.init(package:))
        preservedDependencies = plan.preservedSharedDependencies.map(PrismPackageChangeRow.init(package:))
        unmetCapabilities = plan.unmetCapabilities.map(\.rawValue).sorted()
        removesConfiguration = plan.removesConfiguration
        residueCheckRequired = plan.residueCheckRequired
        isExecutable = plan.isExecutable
    }
}

public struct PrismPreparedRemovalPlan: Sendable {
    public let review: PrismPackageRemovalReview
    public let plan: PackageRemovalPlan
    public init(review: PrismPackageRemovalReview, plan: PackageRemovalPlan) {
        self.review = review
        self.plan = plan
    }
}

public struct PrismPreparedInstallPlan: Sendable {
    public let review: PrismInstallPlanReview
    public let plan: InstallPlan
    public init(review: PrismInstallPlanReview, plan: InstallPlan) {
        self.review = review
        self.plan = plan
    }
}

public struct PrismPackageActionPlanner: Sendable {
    private let planner = InstallPlanner()
    public init() {}

    public func providerRequirements(for packages: [PrismPackage], runtimeIdentity: String? = nil) -> ProviderOperationRequirements {
        ProviderOperationRequirements.install(packages: packages, runtimeIdentity: runtimeIdentity)
    }

    public func removalProviderRequirements(runtimeIdentity: String? = nil) -> ProviderOperationRequirements {
        ProviderOperationRequirements(
            capabilities: ["packageRemove"],
            runtimeIdentity: runtimeIdentity,
            isWrite: true
        )
    }

    public func prepareRemoval(
        packageID: String,
        mode: PackageRemovalMode,
        removeUnusedDependencies: Bool = false,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        environment: PrismEnvironment
    ) throws -> PrismPreparedRemovalPlan {
        let plan = try PackageRemovalPlanner().plan(
            request: .init(
                packageID: packageID,
                mode: mode,
                removeUnusedDependencies: removeUnusedDependencies
            ),
            catalog: catalog,
            installed: installed,
            environment: environment
        )
        return PrismPreparedRemovalPlan(
            review: PrismPackageRemovalReview(plan: plan),
            plan: plan
        )
    }

    public func prepare(
        packageID: String,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        environment: PrismEnvironment
    ) throws -> PrismPreparedInstallPlan {
        let plan = try planner.plan(
            request: InstallRequest(packageIDs: [packageID]),
            catalog: catalog,
            installed: installed,
            environment: environment
        )
        return PrismPreparedInstallPlan(
            review: PrismInstallPlanReview(requestedPackageID: packageID, plan: plan),
            plan: plan
        )
    }
}
