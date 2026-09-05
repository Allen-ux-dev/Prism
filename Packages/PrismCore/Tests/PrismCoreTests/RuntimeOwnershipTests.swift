import Testing
@testable import PrismDomain
@testable import PrismUIBridge

@Test func outdatedRuntimeManagedPrismUsesRuntimeInstallerUpgradePath() async throws {
    let installer = LifecycleRecordingInstaller(
        state: .outdated(
            currentVersion: "0.4.0",
            targetVersion: "0.4.1",
            ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime")
        )
    )
    let coordinator = PrismRuntimeIntegrationCoordinator(
        installer: installer,
        capabilities: RuntimeIntegrationCapability.requiredForManagedLifecycle,
        handshake: { true }
    )

    let state = await coordinator.integrate(targetVersion: "0.4.1")

    #expect(state == .ready)
    #expect((await installer.events).contains("upgrade:0.4.0->0.4.1"))
}

@Test func incompatibleInstalledPrismStopsBeforeRegistration() async throws {
    let installer = LifecycleRecordingInstaller(state: .incompatible(reason: "runtime protocol"))
    let coordinator = PrismRuntimeIntegrationCoordinator(
        installer: installer,
        capabilities: RuntimeIntegrationCapability.requiredForManagedLifecycle,
        handshake: { true }
    )

    let state = await coordinator.integrate(targetVersion: "0.4.1")

    #expect(state == .incompatible(reason: "runtime protocol"))
    #expect(await installer.events == ["inspect"])
}

@Test func failedHandshakeDoesNotReportReady() async throws {
    let installer = LifecycleRecordingInstaller(
        state: .installed(version: "0.4.1", ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime"))
    )
    let coordinator = PrismRuntimeIntegrationCoordinator(
        installer: installer,
        capabilities: RuntimeIntegrationCapability.requiredForManagedLifecycle,
        handshake: { false }
    )

    let state = await coordinator.integrate(targetVersion: "0.4.1")

    #expect(state == .incompatible(reason: "Runtime handshake failed"))
    #expect(!(await installer.events).contains("activate"))
}

@Test func standaloneOutdatedPrismIsNotUpgradedByRuntimeOwnedCoordinator() async throws {
    let installer = LifecycleRecordingInstaller(
        state: .outdated(currentVersion: "0.4.0", targetVersion: "0.4.1", ownership: .standalone)
    )
    let coordinator = PrismRuntimeIntegrationCoordinator(
        installer: installer,
        capabilities: RuntimeIntegrationCapability.requiredForManagedLifecycle,
        handshake: { true }
    )

    let state = await coordinator.integrate(targetVersion: "0.4.1")

    guard case .degraded(let reason) = state else {
        Issue.record("Expected ownership-aware degraded state")
        return
    }
    #expect(reason.contains("dev.prism"))
    #expect(!(await installer.events).contains { $0.hasPrefix("upgrade:") })
}
