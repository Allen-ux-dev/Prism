import Foundation
import Testing
@testable import PrismRepositories

@Test func sileoPackagesNormalizeIntoPrismPackages() throws {
    let url = Bundle.module.url(forResource: "SileoPackages", withExtension: "fixture")!
    let packagesData = try Data(contentsOf: url)
    let releaseData = Data("Origin: Prism Test Repo\nLabel: Prism Test\n".utf8)
    let baseURL = URL(string: "https://repo.example/")!

    let snapshot = try SileoRepositoryProvider().normalizeRepository(
        metadata: releaseData,
        packagesIndex: packagesData,
        baseURL: baseURL
    )

    #expect(snapshot.packages.count == 2)
    #expect(snapshot.packages[0].distribution == .deb)
    #expect(snapshot.packages[0].metadata["SileoDepiction"] != nil)
    #expect(snapshot.packages[0].description.contains("continued description"))
    #expect(snapshot.packages[0].dependencies.count == 2)
}

@Test func unsupportedDependencyAlternativeProducesWarningWithoutDiscardingRawMetadata() throws {
    let packages = Data("""
    Package: dev.prism.alt
    Name: Alternative Demo
    Version: 1.0
    Architecture: iphoneos-arm64
    Depends: first-choice | second-choice
    Filename: debs/alt.deb
    Description: Alternative dependency demo

    """.utf8)

    let snapshot = try SileoRepositoryProvider().normalizeRepository(
        metadata: Data(),
        packagesIndex: packages,
        baseURL: URL(string: "https://repo.example/")!
    )

    #expect(snapshot.warnings.isEmpty)
    #expect(snapshot.packages[0].metadata["Depends"] == "first-choice | second-choice")
    #expect(snapshot.packages[0].dependencyGroups.first?.alternatives.map(\.packageIdentifier) == ["first-choice", "second-choice"])
}
