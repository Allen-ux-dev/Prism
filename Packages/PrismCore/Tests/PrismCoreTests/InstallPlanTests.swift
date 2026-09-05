import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution

@Test func transitiveDependenciesProduceInstallAndUpgradeActions() throws {
    let packageC = PrismPackage(
        identifier: "c", name: "C", version: DebianVersion("1.0"), architecture: "iphoneos-arm64",
        description: "", distribution: .deb, installationState: .notInstalled
    )
    let packageB = PrismPackage(
        identifier: "b", name: "B", version: DebianVersion("2.0"), architecture: "iphoneos-arm64",
        description: "",
        dependencies: [PackageDependency(packageIdentifier: "c")],
        distribution: .deb, installationState: .updateAvailable
    )
    let packageA = PrismPackage(
        identifier: "a", name: "A", version: DebianVersion("1.0"), architecture: "iphoneos-arm64",
        description: "",
        dependencies: [PackageDependency(packageIdentifier: "b", relation: .greaterThanOrEqual, requiredVersion: DebianVersion("2.0"))],
        distribution: .deb, installationState: .notInstalled
    )

    let planner = InstallPlanner()
    let plan = try planner.plan(
        request: InstallRequest(packageIDs: ["a"]),
        catalog: PackageCatalogSnapshot(packages: [packageA, packageB, packageC]),
        installed: PackageStateSnapshot(installedVersions: ["b": .debian("1.5")]),
        environment: .fixturePackageEnvironment
    )

    #expect(plan.installs.map(\.identifier) == ["a", "c"])
    #expect(plan.upgrades.map(\.package.identifier) == ["b"])
    #expect(plan.unresolvedConflicts.isEmpty)
    #expect(plan.unmetCapabilities.isEmpty)
}

@Test func capabilityMismatchMakesPlanNonExecutable() throws {
    let source = PrismPackage(
        identifier: "source.demo",
        name: "Source Demo",
        version: DebianVersion("1.0"),
        architecture: "iphoneos-arm64",
        description: "",
        requirements: [PackageRequirement(identifier: EnvironmentCapability.sourceBuild.rawValue)],
        distribution: .source,
        installationState: .notInstalled
    )

    let planner = InstallPlanner()
    let plan = try planner.plan(
        request: InstallRequest(packageIDs: ["source.demo"]),
        catalog: PackageCatalogSnapshot(packages: [source]),
        installed: PackageStateSnapshot(installedVersions: [:]),
        environment: .fixturePackageEnvironment
    )

    #expect(plan.unmetCapabilities == [.sourceBuild])
    #expect(!plan.isExecutable)
}

@Test func dependencyCycleIsReportedStructurally() {
    let a = PrismPackage(
        identifier: "a", name: "A", version: DebianVersion("1"), architecture: "iphoneos-arm64", description: "",
        dependencies: [PackageDependency(packageIdentifier: "b")], distribution: .deb, installationState: .notInstalled
    )
    let b = PrismPackage(
        identifier: "b", name: "B", version: DebianVersion("1"), architecture: "iphoneos-arm64", description: "",
        dependencies: [PackageDependency(packageIdentifier: "a")], distribution: .deb, installationState: .notInstalled
    )

    #expect(throws: ResolutionError.dependencyCycle(["a", "b", "a"])) {
        try InstallPlanner().plan(
            request: InstallRequest(packageIDs: ["a"]),
            catalog: PackageCatalogSnapshot(packages: [a, b]),
            installed: PackageStateSnapshot(installedVersions: [:]),
            environment: .fixturePackageEnvironment
        )
    }
}

private extension PrismEnvironment {
    static let fixturePackageEnvironment = PrismEnvironment(
        providerIdentifier: "fixture",
        bootstrapIdentifier: "fixture",
        rootStyle: .rootless,
        rootPrefix: URL(fileURLWithPath: "/fixture-root"),
        architecture: "arm64",
        capabilities: [.backgroundService, .packageInstall, .apt, .dpkg]
    )
}


@Test func alternativeDependencyUsesAlreadyInstalledChoice() throws {
    let a = PrismPackage(identifier: "a", version: DebianVersion("1"), architecture: "iphoneos-arm64", dependencyGroups: [PackageDependencyGroup(alternatives: [PackageDependency(packageIdentifier: "b"), PackageDependency(packageIdentifier: "c")])], distribution: .deb)
    let b = PrismPackage(identifier: "b", version: DebianVersion("1"), architecture: "iphoneos-arm64", distribution: .deb)
    let c = PrismPackage(identifier: "c", version: DebianVersion("1"), architecture: "iphoneos-arm64", distribution: .deb)
    let plan = try InstallPlanner().plan(request: .init(packageIDs:["a"]), catalog: .init(packages:[a,b,c]), installed: .init(installedVersions:["c":.debian("1")]), environment: .fixturePackageEnvironment)
    #expect(plan.installs.map(\.identifier) == ["a"])
}

@Test func debPackageRequiresPackageInstallAndAPTCapabilities() throws {
    let package = PrismPackage(
        identifier: "deb.demo",
        name: "Deb Demo",
        version: DebianVersion("1.0"),
        architecture: "iphoneos-arm64",
        distribution: .deb
    )
    let environment = PrismEnvironment(
        providerIdentifier: "fixture",
        bootstrapIdentifier: nil,
        rootStyle: .rootless,
        rootPrefix: URL(fileURLWithPath: "/fixture-root"),
        architecture: "arm64",
        capabilities: []
    )
    let plan = try InstallPlanner().plan(
        request: .init(packageIDs: [package.identifier]),
        catalog: .init(packages: [package]),
        installed: .init(installedVersions: [:]),
        environment: environment
    )
    #expect(plan.unmetCapabilities == [.packageInstall, .apt, .dpkg])
    #expect(!plan.isExecutable)
}
