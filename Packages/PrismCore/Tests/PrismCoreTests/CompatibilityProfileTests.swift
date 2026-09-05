import Testing
@testable import PrismDomain

@Test func compatibilityProfileCanRepresentPartialEnvironmentWithoutBinaryFailure() {
    let profile = PrismCompatibilityProfile(
        runtimeCompatibility: .compatible,
        osCompatibility: .compatible,
        architectureCompatibility: .compatible,
        packageFormatCompatibility: .partiallyCompatible,
        providerCompatibility: .degraded,
        requiredCapabilities: ["packageInstall"],
        optionalCapabilities: ["userspaceRestart"]
    )

    #expect(profile.overallLevel == .degraded)
    #expect(profile.requiredCapabilities.contains("packageInstall"))
}
