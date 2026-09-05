import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismUIBridge

@Test func runtimeModeDefaultsToModernAndLegacyCompatibilityIsLazy() async {
    let controller = RuntimeModeController()
    #expect(await controller.mode == .modern)
    #expect(!(await controller.isActive(.legacyCompatibility)))
    await controller.activate(.legacyCompatibility)
    #expect(await controller.isActive(.legacyCompatibility))
    await controller.returnToIdle(.legacyCompatibility)
    #expect(!(await controller.isActive(.legacyCompatibility)))
}

@Test func normalRuntimePresentationDoesNotExposeLegacyImplementationDetails() {
    let environment = PrismEnvironment(
        providerIdentifier: "standard-rootless", bootstrapIdentifier: "procursus", rootStyle: .rootless,
        rootPrefix: URL(fileURLWithPath: "/var/jb"), architecture: "arm64",
        capabilities: [.packageInstall, .apt, .dpkg, .backgroundService],
        toolPaths: .init(aptGet: URL(fileURLWithPath: "/var/jb/usr/bin/apt-get"), dpkg: URL(fileURLWithPath: "/var/jb/usr/bin/dpkg"))
    )
    let presentation = RuntimeIsolationPolicy().normalPresentation(environment: environment, mode: .hybrid, backgroundActive: false)
    let combined = [presentation.runtime, presentation.packageService, presentation.compatibility, presentation.background].joined(separator: " ")
    #expect(!combined.contains("/var/jb"))
    #expect(!combined.contains("apt"))
    #expect(!combined.contains("dpkg"))
    #expect(presentation.compatibility == "Hybrid")
}

@Test func unrelatedProviderFailureDoesNotDisablePackageManagementPresentation() {
    let policy = RuntimeIsolationPolicy()
    let state = policy.featureAvailability(providerHealth: [
        .packageService: .healthy,
        .appInjection: .unavailable("provider offline")
    ])
    #expect(state.packageManagement)
    #expect(!state.appInjection)
}
