import Foundation
import Testing
@testable import PrismUIBridge
import PrismDomain
import PrismEnvironment
import PrismResolution

private func actionPackage(_ id: String, _ version: String, deps: [PackageDependency] = []) -> PrismPackage {
    PrismPackage(
        identifier: id,
        name: id,
        version: DebianVersion(version),
        architecture: "arm64",
        dependencies: deps,
        distribution: .deb
    )
}

@Test func packageActionPlannerCreatesReviewFromInstallPlan() throws {
    let dep = PackageDependency(packageIdentifier: "lib.demo", relation: .greaterThanOrEqual, requiredVersion: DebianVersion("2.0"))
    let catalog = PackageCatalogSnapshot(packages: [actionPackage("app.demo", "1.0", deps: [dep]), actionPackage("lib.demo", "2.0")])
    let environment = PrismEnvironment(
        providerIdentifier: "test",
        bootstrapIdentifier: nil,
        rootStyle: .rootless,
        rootPrefix: URL(fileURLWithPath: "/test-root"),
        architecture: "arm64",
        capabilities: [.packageInstall, .apt, .dpkg]
    )

    let prepared = try PrismPackageActionPlanner().prepare(
        packageID: "app.demo",
        catalog: catalog,
        installed: .init(installedVersions: [:]),
        environment: environment
    )

    #expect(prepared.review.requestedPackageID == "app.demo")
    #expect(prepared.review.installs.map(\.identifier) == ["app.demo", "lib.demo"])
    #expect(prepared.review.upgrades.isEmpty)
    #expect(prepared.review.isExecutable)
    #expect(prepared.plan.isExecutable)
}

@Test func packageActionPlannerSurfacesUnmetCapabilities() throws {
    let package = PrismPackage(
        identifier: "source.demo",
        name: "Source Demo",
        version: DebianVersion("1.0"),
        architecture: "arm64",
        requirements: [PackageRequirement(identifier: EnvironmentCapability.sourceBuild.rawValue)],
        distribution: .source
    )
    let environment = PrismEnvironment(
        providerIdentifier: "test",
        bootstrapIdentifier: nil,
        rootStyle: .rootless,
        rootPrefix: URL(fileURLWithPath: "/test-root"),
        architecture: "arm64",
        capabilities: [.packageInstall]
    )
    let prepared = try PrismPackageActionPlanner().prepare(
        packageID: package.identifier,
        catalog: .init(packages: [package]),
        installed: .init(installedVersions: [:]),
        environment: environment
    )
    #expect(!prepared.review.isExecutable)
    #expect(prepared.review.unmetCapabilities == [EnvironmentCapability.sourceBuild.rawValue])
}

@Test func packageActionPlannerCreatesPurgeReviewAndPreservesDependenciesByDefault() throws {
    let dep = actionPackage("lib.keep", "1.0")
    let plugin = actionPackage("plugin.demo", "1.0", deps: [PackageDependency(packageIdentifier: "lib.keep")])
    let environment = PrismEnvironment(
        providerIdentifier: "test",
        bootstrapIdentifier: nil,
        rootStyle: .rootless,
        rootPrefix: URL(fileURLWithPath: "/test-root"),
        architecture: "arm64",
        capabilities: [.packageRemove, .apt, .dpkg]
    )
    let prepared = try PrismPackageActionPlanner().prepareRemoval(
        packageID: plugin.identifier,
        mode: .purge,
        removeUnusedDependencies: false,
        catalog: .init(packages: [plugin, dep]),
        installed: .init(installedVersions: [plugin.identifier: .debian("1.0"), dep.identifier: .debian("1.0")]),
        environment: environment
    )

    #expect(prepared.review.requestedPackageID == plugin.identifier)
    #expect(prepared.review.mode == .purge)
    #expect(prepared.review.packagesToRemove.map(\.identifier) == [plugin.identifier])
    #expect(prepared.review.preservedDependencies.map(\.identifier) == [dep.identifier])
    #expect(prepared.review.removesConfiguration)
    #expect(prepared.review.residueCheckRequired)
    #expect(prepared.review.isExecutable)
}
