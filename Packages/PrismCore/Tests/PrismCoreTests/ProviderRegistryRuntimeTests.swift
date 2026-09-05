import Foundation
import Testing
@testable import PrismDomain

private actor MutableHealthFixtureProvider: PrismRuntimeStateReporting {
    nonisolated let descriptor: PrismProviderDescriptor
    private var state: ProviderRuntimeState

    init(id: String, health: ProviderHealth) {
        descriptor = PrismProviderDescriptor(
            identifier: id,
            kind: .packageService,
            version: "1.0",
            priority: 10,
            operatingModes: [.modern],
            supportedRequirements: ["packageInstall"],
            supportedFormats: [.relaxinPackage],
            runtimeIdentities: ["dev.relaxin.runtime"],
            health: health
        )
        state = ProviderRuntimeState(
            health: health,
            capabilityReport: ["packageInstall": health],
            supportedFormats: [.relaxinPackage],
            supportedVersionSchemes: ["native"],
            recoveryStrategies: [.reconcile],
            lastHealthChange: Date(timeIntervalSince1970: 1),
            diagnosticSummary: nil
        )
    }

    func setHealth(_ health: ProviderHealth) {
        state.health = health
        state.lastHealthChange = Date(timeIntervalSince1970: 2)
    }

    func providerRuntimeState() async -> ProviderRuntimeState { state }
}

@Test func registryRefreshesLiveProviderHealthWithoutReregistering() async throws {
    let provider = MutableHealthFixtureProvider(id: "modern", health: .healthy)
    let registry = ProviderRegistry()
    await registry.register(provider)

    await provider.setHealth(.degraded("runtime restarting"))
    let refreshed = try await registry.refreshHealth("modern")

    #expect(refreshed.health == .degraded("runtime restarting"))
    #expect(refreshed.lastHealthChange == Date(timeIntervalSince1970: 2))
}

@Test func registryDiagnosticsExposeStableIdentityAndLiveStateSeparately() async throws {
    let registry = ProviderRegistry()
    await registry.register(MutableHealthFixtureProvider(id: "modern", health: .healthy))

    let snapshot = await registry.diagnosticsSnapshot()

    #expect(snapshot.count == 1)
    #expect(snapshot.first?.identity.providerID == "modern")
    #expect(snapshot.first?.identity.providerKind == .packageService)
    #expect(snapshot.first?.runtimeState.health == .healthy)
}
