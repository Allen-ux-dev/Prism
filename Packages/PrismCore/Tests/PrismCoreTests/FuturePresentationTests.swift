import Foundation
import Testing
import PrismDomain
import PrismEnvironment
import PrismUIBridge

@Test func phoneNavigationRemainsExactlyFiveModernDestinations() {
    #expect(PrismNavigationContract.phonePrimaryDestinations == [
        .featured, .packages, .sources, .apps, .activity
    ])
    #expect(PrismNavigationContract.phonePrimaryDestinations.count == 5)
}

@Test func normalSettingsPresentationContainsOnlyDailyRuntimeRows() {
    let env = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        runtimeDisplayName: "RELAXIN-X Runtime",
        runtimeVersion: "2.0",
        architecture: "arm64",
        osVersion: "26.6",
        osBuild: "23G91",
        capabilityReport: [
            .packageInstall: .available,
            .appInstall: .degraded("registration service warming up"),
            .appInjection: .unavailable
        ],
        compatibilityLayers: []
    )
    let presentation = PrismEnvironmentPresentation.make(
        environment: env,
        mode: .modern,
        serviceStatus: .connected,
        serviceProvider: "dev.relaxin.service.runtime"
    )

    #expect(presentation.dailyRows.map(\.title) == ["Runtime", "Package Service", "Compatibility", "Background"])
    #expect(presentation.dailyRows.map(\.value) == ["RELAXIN-X Runtime", "Ready", "Modern", "Idle"])
    #expect(!presentation.dailyRows.map(\.value).joined().contains("/var/jb"))
    #expect(!presentation.dailyRows.map(\.value).joined().contains("dpkg"))
}

@Test func capabilityPresentationPreservesFourStateSemantics() {
    #expect(PrismCapabilityPresentation(status: .available).state == .available)
    #expect(PrismCapabilityPresentation(status: .degraded("warming up")).state == .degraded)
    #expect(PrismCapabilityPresentation(status: .unavailable).state == .unavailable)
    #expect(PrismCapabilityPresentation(status: .unknown("probing")).state == .unknown)
    #expect(PrismCapabilityPresentation(status: .degraded("warming up")).detail == "warming up")
}

@Test func advancedDiagnosticsRedactsLegacyPathsAndLabelsSimulationProviders() {
    let env = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        architecture: "arm64",
        capabilityReport: [.packageInstall: .available],
        compatibilityLayers: ["legacy-bootstrap"],
        legacy: .init(
            bootstrapIdentifier: "procursus",
            rootStyle: .rootless,
            rootPrefix: URL(fileURLWithPath: "/var/jb"),
            packageDatabase: .init(kind: "dpkg", path: URL(fileURLWithPath: "/var/jb/Library/dpkg"))
        )
    )
    let presentation = PrismEnvironmentPresentation.make(
        environment: env,
        mode: .hybrid,
        serviceStatus: .connected,
        serviceProvider: "dev.prism.app-install.mock-trollstore-style"
    )

    #expect(presentation.advancedRows.contains { $0.title == "Provider" && $0.value.contains("Simulation") })
    #expect(presentation.advancedRows.contains { $0.value == "…/jb" })
    #expect(presentation.advancedRows.contains { $0.value == "…/dpkg" })
    #expect(!presentation.advancedRows.map(\.value).joined(separator: " ").contains("/var/jb/Library"))
}
