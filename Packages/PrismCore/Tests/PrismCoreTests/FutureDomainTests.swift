import Testing
@testable import PrismDomain

@Test func packageVersionsUseDeclaredSchemes() throws {
    let registry = VersionSchemeRegistry.standard
    let debianA = PackageVersion(rawValue: "2.10", schemeIdentifier: .debian)
    let debianB = PackageVersion(rawValue: "2.9", schemeIdentifier: .debian)
    #expect(try registry.compare(debianA, debianB) == .orderedDescending)

    let semverA = PackageVersion(rawValue: "1.10.0", schemeIdentifier: .semantic)
    let semverB = PackageVersion(rawValue: "1.9.9", schemeIdentifier: .semantic)
    #expect(try registry.compare(semverA, semverB) == .orderedDescending)
}

@Test func unsupportedVersionSchemeNeverFallsBackToLexicalCompatibility() {
    let registry = VersionSchemeRegistry.standard
    let version = PackageVersion(rawValue: "10", schemeIdentifier: .init(rawValue: "dev.example.unknown"))
    #expect(throws: VersionSchemeRegistryError.self) {
        _ = try registry.normalize(version)
    }
}

@Test func packageFormatIdentifierIsOpenEnded() {
    let future = PackageFormatIdentifier(rawValue: "dev.relaxin.future-format")
    #expect(future.rawValue == "dev.relaxin.future-format")
    #expect(PackageFormatIdentifier.debianDeb.rawValue == "org.debian.deb")
}
