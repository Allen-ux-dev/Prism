import Testing
@testable import PrismDomain
@testable import PrismUIBridge

@Test func relaxinRuntimeInstallerAdapterDelegatesOnlyTypedLifecycleOperations() async throws {
    let transport = RuntimeInstallerTransportFixture()
    let adapter = RelaxinRuntimeInstallerAdapter(transport: transport)

    #expect(try await adapter.inspectInstallation() == .notInstalled)
    _ = try await adapter.install(request: .init(targetVersion: "0.4.1"))
    try await adapter.registerPrism()
    try await adapter.registerPackageService()
    try await adapter.registerLifecycle()
    try await adapter.activate()
    _ = try await adapter.repair()
    try await adapter.deactivate()
    try await adapter.unregister()

    #expect(await transport.events == [
        "inspect", "install", "registerPrism", "registerPackageService", "registerLifecycle", "activate", "repair", "deactivate", "unregister"
    ])
}

private actor RuntimeInstallerTransportFixture: RelaxinRuntimeInstallerTransport {
    private(set) var events: [String] = []
    func inspectInstallation() async throws -> PrismInstallationState { events.append("inspect"); return .notInstalled }
    func install(_ request: PrismInstallRequest) async throws -> PrismInstallationReceipt { events.append("install"); return .init(installedVersion: request.targetVersion, ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime")) }
    func upgrade(_ request: PrismUpgradeRequest) async throws -> PrismInstallationReceipt { events.append("upgrade"); return .init(installedVersion: request.targetVersion, ownership: .runtimeManaged(runtimeID: "dev.relaxin.runtime")) }
    func registerPrism() async throws { events.append("registerPrism") }
    func registerPackageService() async throws { events.append("registerPackageService") }
    func registerLifecycle() async throws { events.append("registerLifecycle") }
    func activate() async throws { events.append("activate") }
    func repair() async throws -> PrismRepairResult { events.append("repair"); return .init(state: .ready) }
    func deactivate() async throws { events.append("deactivate") }
    func unregister() async throws { events.append("unregister") }
}
