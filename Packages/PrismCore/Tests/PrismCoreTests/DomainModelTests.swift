import Testing
@testable import PrismDomain

@Test func debianVersionsCompareNumericSegments() {
    #expect(DebianVersion("2.10") > DebianVersion("2.9"))
}

@Test func debianVersionsRespectEpochAndRevision() {
    #expect(DebianVersion("1:1.0-1") > DebianVersion("2.0-99"))
    #expect(DebianVersion("1.0-2") > DebianVersion("1.0-1"))
}

@Test func debianTildeSortsBeforeRelease() {
    #expect(DebianVersion("1.0~beta1") < DebianVersion("1.0"))
}

@Test func dependencyRelationCanRequireMinimumVersion() {
    let dependency = PackageDependency(
        packageIdentifier: "libexample",
        relation: .greaterThanOrEqual,
        requiredVersion: DebianVersion("1.3")
    )
    #expect(dependency.isSatisfied(by: DebianVersion("1.4")))
    #expect(!dependency.isSatisfied(by: DebianVersion("1.2")))
}

@Test func prismPackageCarriesStructuredDependencies() {
    let package = PrismPackage(
        identifier: "dev.prism.demo",
        name: "Demo",
        version: DebianVersion("1.0-1"),
        architecture: "iphoneos-arm64",
        author: "Prism",
        description: "Demo package",
        repositoryID: "repo.example",
        dependencies: [
            PackageDependency(
                packageIdentifier: "libexample",
                relation: .greaterThanOrEqual,
                requiredVersion: DebianVersion("1.0")
            )
        ],
        conflicts: [],
        requirements: [],
        distribution: .deb,
        installationState: .notInstalled,
        metadata: [:]
    )

    #expect(package.dependencies.first?.packageIdentifier == "libexample")
    #expect(package.distribution == .deb)
}
