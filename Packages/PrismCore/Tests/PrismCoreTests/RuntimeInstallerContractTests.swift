import Testing
@testable import PrismDomain
@testable import PrismUIBridge

@Test func runtimeManagedOwnershipKeepsLifecycleAuthorityWithRuntime() {
    let ownership = PrismInstallationOwnership.runtimeManaged(runtimeID: "dev.relaxin.runtime")
    #expect(ownership.lifecycleOwnerID == "dev.relaxin.runtime")
    #expect(ownership.isRuntimeManaged)
}

@Test func standaloneOwnershipKeepsLifecycleAuthorityWithPrism() {
    #expect(PrismInstallationOwnership.standalone.lifecycleOwnerID == "dev.prism")
    #expect(!PrismInstallationOwnership.standalone.isRuntimeManaged)
}

@Test func installerContractCanRepresentInstallUpgradeRepairLifecycle() async throws {
    let installer = RecordingRuntimeInstaller()
    let receipt = try await installer.install(request: .init(targetVersion: "0.4.1"))
    #expect(receipt.installedVersion == "0.4.1")
    _ = try await installer.upgrade(request: .init(fromVersion: "0.4.0", targetVersion: "0.4.1"))
    try await installer.registerPrism()
    try await installer.registerPackageService()
    try await installer.registerLifecycle()
    try await installer.activate()
    let repair = try await installer.repair()
    #expect(repair.state == .ready)
    try await installer.deactivate()
    try await installer.unregister()
}

private actor RecordingRuntimeInstaller: PrismRuntimeInstallerProtocol {
    func inspectInstallation() async throws -> PrismInstallationState { .notInstalled }
    func install(request: PrismInstallRequest) async throws -> PrismInstallationReceipt {
        .init(installedVersion: request.targetVersion, ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime"))
    }
    func upgrade(request: PrismUpgradeRequest) async throws -> PrismInstallationReceipt {
        .init(installedVersion: request.targetVersion, ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime"))
    }
    func registerPrism() async throws {}
    func registerPackageService() async throws {}
    func registerLifecycle() async throws {}
    func activate() async throws {}
    func repair() async throws -> PrismRepairResult { .init(state: .ready, repairedComponents: ["packageService"]) }
    func deactivate() async throws {}
    func unregister() async throws {}
}
