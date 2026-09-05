import Testing
@testable import PrismDomain
@testable import PrismEnvironment

@Test func applicationCapabilityIdentifiersRemainStable() {
    #expect(CapabilityIdentifier.appInstall.rawValue == "dev.prism.capability.app-install")
    #expect(CapabilityIdentifier.appRegistration.rawValue == "dev.prism.capability.app-registration")
    #expect(CapabilityIdentifier.appReplace.rawValue == "dev.prism.capability.app-replace")
    #expect(CapabilityIdentifier.appRemoval.rawValue == "dev.prism.capability.app-removal")
    #expect(CapabilityIdentifier.appRefresh.rawValue == "dev.prism.capability.app-refresh")
    #expect(CapabilityIdentifier.appInjection.rawValue == "dev.prism.capability.app-injection")
    #expect(CapabilityIdentifier.dylibInjection.rawValue == "dev.prism.capability.dylib-injection")
    #expect(CapabilityIdentifier.frameworkInjection.rawValue == "dev.prism.capability.framework-injection")
    #expect(CapabilityIdentifier.bundleInjection.rawValue == "dev.prism.capability.bundle-injection")
}

@Test func legacyApplicationCapabilitiesMigrateToOpenIdentifiers() {
    #expect(LegacyEnvironmentCapabilityAdapter.convert(.appInstall) == .appInstall)
    #expect(LegacyEnvironmentCapabilityAdapter.convert(.ipaInstall) == .appInstall)
    #expect(LegacyEnvironmentCapabilityAdapter.convert(.appRegistration) == .appRegistration)
    #expect(LegacyEnvironmentCapabilityAdapter.convert(.appInjection) == .appInjection)
    #expect(LegacyEnvironmentCapabilityAdapter.convert(.dylibInjection) == .dylibInjection)
    #expect(LegacyEnvironmentCapabilityAdapter.convert(.frameworkInjection) == .frameworkInjection)
    #expect(LegacyEnvironmentCapabilityAdapter.convert(.bundleInjection) == .bundleInjection)
}

@Test func legacyApplicationCapabilityAliasesMergeWithoutDuplicateIdentifierCrash() {
    let states = LegacyEnvironmentCapabilityAdapter.convert([
        .appInstall: .available,
        .ipaInstall: .available
    ])
    #expect(states.count == 1)
    #expect(states[.appInstall]?.availability == .available)
}
