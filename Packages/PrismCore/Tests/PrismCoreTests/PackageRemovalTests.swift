import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions

private func pkg(_ id: String, deps: [String] = []) -> PrismPackage {
    PrismPackage(
        identifier: id,
        name: id,
        version: DebianVersion("1.0"),
        dependencies: deps.map { PackageDependency(packageIdentifier: $0) },
        distribution: .debianDeb
    )
}

private func env(_ capabilities: Set<EnvironmentCapability>) -> PrismEnvironment {
    PrismEnvironment(
        providerIdentifier: "fixture",
        bootstrapIdentifier: nil,
        rootStyle: .rootless,
        rootPrefix: URL(fileURLWithPath: "/fixture"),
        architecture: "arm64",
        capabilities: capabilities
    )
}

@Test func purgeRemovalPlanCleansOnlyOrphansAndPreservesSharedDependencies() throws {
    let target = pkg("plugin.target", deps: ["dep.orphan", "dep.shared"])
    let orphan = pkg("dep.orphan")
    let shared = pkg("dep.shared")
    let other = pkg("plugin.other", deps: ["dep.shared"])
    let catalog = PackageCatalogSnapshot(packages: [target, orphan, shared, other])
    let installed = PackageStateSnapshot(installedVersions: [
        "plugin.target": .debian("1.0"),
        "dep.orphan": .debian("1.0"),
        "dep.shared": .debian("1.0"),
        "plugin.other": .debian("1.0")
    ])

    let plan = try PackageRemovalPlanner().plan(
        request: .init(packageID: "plugin.target", mode: .purge, removeUnusedDependencies: true),
        catalog: catalog,
        installed: installed,
        environment: env([.packageRemove, .apt, .dpkg])
    )

    #expect(plan.packagesToRemove.map(\.identifier) == ["dep.orphan", "plugin.target"])
    #expect(plan.preservedSharedDependencies.map(\.identifier) == ["dep.shared"])
    #expect(plan.removesConfiguration)
    #expect(plan.residueCheckRequired)
    #expect(plan.isExecutable)
}

@Test func standardRemovalKeepsConfigurationAndDependenciesWhenAutoCleanupDisabled() throws {
    let target = pkg("plugin.target", deps: ["dep.one"])
    let dep = pkg("dep.one")
    let catalog = PackageCatalogSnapshot(packages: [target, dep])
    let installed = PackageStateSnapshot(installedVersions: [
        "plugin.target": .debian("1.0"),
        "dep.one": .debian("1.0")
    ])

    let plan = try PackageRemovalPlanner().plan(
        request: .init(packageID: "plugin.target", mode: .remove, removeUnusedDependencies: false),
        catalog: catalog,
        installed: installed,
        environment: env([.packageRemove, .apt, .dpkg])
    )

    #expect(plan.packagesToRemove.map(\.identifier) == ["plugin.target"])
    #expect(plan.preservedSharedDependencies.map(\.identifier) == ["dep.one"])
    #expect(!plan.removesConfiguration)
    #expect(plan.residueCheckRequired)
}

@Test func removalPlanRequiresPackageRemoveCapability() throws {
    let target = pkg("plugin.target")
    let plan = try PackageRemovalPlanner().plan(
        request: .init(packageID: "plugin.target", mode: .purge),
        catalog: .init(packages: [target]),
        installed: .init(installedVersions: ["plugin.target": .debian("1.0")]),
        environment: env([.apt, .dpkg])
    )
    #expect(plan.unmetCapabilities == [.packageRemove])
    #expect(!plan.isExecutable)
}

@Test func purgeOperationHasDistinctStableIdentity() {
    let op = TransactionOperation.purgePackage("plugin.target")
    #expect(op.stableID == "pkg-purge:plugin.target")
}

@Test func packageRemovalJournalSchemaIsVersionedForPurgeTransactions() {
    #expect(PrismContractVersions.transactionJournalSchema == 3)
}

@Test func removalOfInstalledPackageMissingFromCatalogStaysProviderAgnostic() throws {
    let plan = try PackageRemovalPlanner().plan(
        request: .init(packageID: "plugin.unknown", mode: .remove, removeUnusedDependencies: false),
        catalog: .init(packages: []),
        installed: .init(installedVersions: ["plugin.unknown": .native("1.0")]),
        environment: PrismEnvironment(
            runtimeIdentity: "modern-runtime",
            architecture: "arm64",
            capabilityReport: [.packageRemove: .available]
        )
    )
    #expect(plan.unmetCapabilities.isEmpty)
    #expect(plan.isExecutable)
}

@Test func removalRequestPreservesDependenciesByDefault() {
    let request = PackageRemovalRequest(packageID: "plugin.demo", mode: .purge)
    #expect(!request.removeUnusedDependencies)
}
