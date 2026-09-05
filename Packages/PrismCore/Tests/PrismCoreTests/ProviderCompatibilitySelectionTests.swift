import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismUIBridge

private struct CompatibilityFixtureProvider: PrismProvider {
    let descriptor: PrismProviderDescriptor
}

@Test func hybridDebRequestSelectsServiceThatSupportsDebCompatibility() async throws {
    let registry = ProviderRegistry()
    await registry.register(CompatibilityFixtureProvider(descriptor: .init(
        identifier: "modern",
        kind: .packageService,
        version: "1",
        priority: 100,
        operatingModes: [.modern, .hybrid],
        supportedRequirements: ["packageInstall"],
        supportedFormats: [.relaxinPackage],
        recoveryStrategies: [.reconcile],
        health: .healthy
    )))
    await registry.register(CompatibilityFixtureProvider(descriptor: .init(
        identifier: "legacy",
        kind: .packageService,
        version: "1",
        priority: 20,
        operatingModes: [.hybrid, .legacy],
        supportedRequirements: ["packageInstall", "legacyDebCompatibility"],
        supportedFormats: [.debianDeb],
        recoveryStrategies: [.reconcile],
        health: .healthy
    )))

    let package = PrismPackage(
        identifier: "demo",
        version: .debian("1.0"),
        requirements: [.init(identifier: "legacyDebCompatibility")],
        distribution: .debianDeb
    )
    let requirements = ProviderOperationRequirements.install(packages: [package])
    let selected = try await registry.select(kind: .packageService, context: requirements.selectionContext(mode: .hybrid))

    #expect(selected.identifier == "legacy")
}

@Test func modernRelaxinPackageNeverFallsBackToLegacyProvider() async throws {
    let registry = ProviderRegistry()
    await registry.register(CompatibilityFixtureProvider(descriptor: .init(
        identifier: "legacy",
        kind: .packageService,
        version: "1",
        priority: 100,
        operatingModes: [.hybrid, .legacy],
        supportedRequirements: ["packageInstall", "legacyDebCompatibility"],
        supportedFormats: [.debianDeb],
        recoveryStrategies: [.reconcile],
        health: .healthy
    )))

    let package = PrismPackage(identifier: "modern", version: .native("1"), distribution: .relaxinPackage)
    let requirements = ProviderOperationRequirements.install(packages: [package])

    await #expect(throws: ProviderRegistryError.noCompatibleProvider(.packageService)) {
        _ = try await registry.select(kind: .packageService, context: requirements.selectionContext(mode: .modern))
    }
}

@Test func installRequirementsComeFromPackageMetadataInsteadOfFormatSwitches() {
    let package = PrismPackage(
        identifier: "custom",
        version: .native("1"),
        requirements: [.init(identifier: "runtimeHookSupport")],
        distribution: PackageFormatIdentifier(rawValue: "dev.example.custom")
    )
    let requirements = ProviderOperationRequirements.install(packages: [package])

    #expect(requirements.capabilities == ["packageInstall", "runtimeHookSupport"])
    #expect(requirements.packageFormats == [PackageFormatIdentifier(rawValue: "dev.example.custom")])
}
