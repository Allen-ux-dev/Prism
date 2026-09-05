import Testing
@testable import PrismDomain
@testable import PrismUIBridge

@Test func missingPrismInstallsRegistersAndActivatesBeforeReady() async throws {
    let installer = LifecycleRecordingInstaller(state: .notInstalled)
    let coordinator = PrismRuntimeIntegrationCoordinator(
        installer: installer,
        capabilities: RuntimeIntegrationCapability.requiredForManagedLifecycle,
        handshake: { true }
    )

    let state = await coordinator.integrate(targetVersion: "0.4.1")

    #expect(state == .ready)
    #expect(await coordinator.lifecycleState == .idle)
    #expect(await installer.events == [
        "inspect", "install:0.4.1", "registerPrism", "registerPackageService", "registerLifecycle", "activate"
    ])
}

@Test func installedPrismSkipsInstallButCompletesRegistrationLifecycle() async throws {
    let installer = LifecycleRecordingInstaller(
        state: .installed(version: "0.4.1", ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime"))
    )
    let coordinator = PrismRuntimeIntegrationCoordinator(
        installer: installer,
        capabilities: RuntimeIntegrationCapability.requiredForManagedLifecycle,
        handshake: { true }
    )

    let state = await coordinator.integrate(targetVersion: "0.4.1")

    #expect(state == .ready)
    #expect(!(await installer.events).contains { $0.hasPrefix("install:") || $0.hasPrefix("upgrade:") })
    #expect((await installer.events).contains("activate"))
}

@Test func runtimeIntegrationMissingRequiredCapabilityBecomesDegradedWithoutInstalling() async throws {
    let installer = LifecycleRecordingInstaller(state: .notInstalled)
    var capabilities = RuntimeIntegrationCapability.requiredForManagedLifecycle
    capabilities[.serviceRegistration] = .unavailable
    let coordinator = PrismRuntimeIntegrationCoordinator(
        installer: installer,
        capabilities: capabilities,
        handshake: { true }
    )

    let state = await coordinator.integrate(targetVersion: "0.4.1")

    guard case .degraded(let reason) = state else {
        Issue.record("Expected degraded state")
        return
    }
    #expect(reason.contains("serviceRegistration"))
    #expect(await installer.events == [])
}

@Test func runtimeReconnectRepairUsesInstallerRepairAndReturnsReportedState() async throws {
    let installer = LifecycleRecordingInstaller(state: .installed(version: "0.4.1", ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime")))
    await installer.setRepairResult(.init(state: .ready, repairedComponents: ["packageService", "lifecycle"]))
    let coordinator = PrismRuntimeIntegrationCoordinator(
        installer: installer,
        capabilities: RuntimeIntegrationCapability.requiredForManagedLifecycle,
        handshake: { true }
    )

    let state = await coordinator.repair()

    #expect(state == .ready)
    #expect(await installer.events == ["repair"])
}

actor LifecycleRecordingInstaller: PrismRuntimeInstallerProtocol {
    private var installationState: PrismInstallationState
    private var repairResult = PrismRepairResult(state: .ready)
    private(set) var events: [String] = []

    init(state: PrismInstallationState) { self.installationState = state }

    func setRepairResult(_ result: PrismRepairResult) { repairResult = result }
    func inspectInstallation() async throws -> PrismInstallationState { events.append("inspect"); return installationState }
    func install(request: PrismInstallRequest) async throws -> PrismInstallationReceipt {
        events.append("install:\(request.targetVersion)")
        let receipt = PrismInstallationReceipt(installedVersion: request.targetVersion, ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime"))
        installationState = .installed(version: request.targetVersion, ownership: receipt.ownership)
        return receipt
    }
    func upgrade(request: PrismUpgradeRequest) async throws -> PrismInstallationReceipt {
        events.append("upgrade:\(request.fromVersion)->\(request.targetVersion)")
        let receipt = PrismInstallationReceipt(installedVersion: request.targetVersion, ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime"))
        installationState = .installed(version: request.targetVersion, ownership: receipt.ownership)
        return receipt
    }
    func registerPrism() async throws { events.append("registerPrism") }
    func registerPackageService() async throws { events.append("registerPackageService") }
    func registerLifecycle() async throws { events.append("registerLifecycle") }
    func activate() async throws { events.append("activate") }
    func repair() async throws -> PrismRepairResult { events.append("repair"); return repairResult }
    func deactivate() async throws { events.append("deactivate") }
    func unregister() async throws { events.append("unregister") }
}

@Test func integrationPresentationUsesOnlyHighLevelStateAndReason() {
    let ready = PrismIntegrationPresentation(state: .ready, lifecycle: .idle)
    #expect(ready.rows.map(\.title) == ["Prism", "Lifecycle"])
    #expect(ready.rows.map(\.value) == ["Ready", "Idle"])

    let degraded = PrismIntegrationPresentation(state: .degraded(reason: "runtime reconnecting"), lifecycle: .recovering)
    #expect(degraded.rows[0].value == "Degraded")
    #expect(degraded.rows[0].detail == "runtime reconnecting")
    #expect(!degraded.rows.map(\.value).joined().contains("/var/jb"))
}
