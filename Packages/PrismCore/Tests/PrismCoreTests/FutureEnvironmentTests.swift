import Foundation
import Testing
@testable import PrismEnvironment

@Test func modernEnvironmentIsValidWithoutLegacyBootstrapOrRootPrefix() {
    let environment = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        runtimeVersion: "2.0",
        architecture: "arm64",
        osVersion: "26.6",
        osBuild: "23G80",
        capabilityReport: [
            .packageInstall: .available,
            .transactionReconcile: .available,
            .legacyDebCompatibility: .unavailable
        ],
        storageNamespace: URL(fileURLWithPath: "/runtime/prism"),
        packageStore: "relaxin-package-store",
        compatibilityLayers: [],
        legacy: nil
    )

    #expect(environment.legacy == nil)
    #expect(environment.runtimeIdentity == "dev.relaxin.runtime")
    #expect(environment.status(of: .packageInstall).isUsable)
    #expect(environment.status(of: .legacyDebCompatibility) == .unavailable)
}

@Test func capabilityStatusCarriesDegradedAndUnknownReasons() {
    let degraded = CapabilityStatus.degraded("runtime service restarting")
    let unknown = CapabilityStatus.unknown("probe pending")
    #expect(degraded.isUsable)
    #expect(degraded.reason == "runtime service restarting")
    #expect(!unknown.isUsable)
    #expect(unknown.reason == "probe pending")
}
