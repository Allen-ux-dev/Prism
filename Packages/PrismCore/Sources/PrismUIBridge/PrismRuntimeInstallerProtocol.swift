import PrismDomain

public protocol PrismRuntimeInstallerProtocol: Sendable {
    func inspectInstallation() async throws -> PrismInstallationState
    func install(request: PrismInstallRequest) async throws -> PrismInstallationReceipt
    func upgrade(request: PrismUpgradeRequest) async throws -> PrismInstallationReceipt
    func registerPrism() async throws
    func registerPackageService() async throws
    func registerLifecycle() async throws
    func activate() async throws
    func repair() async throws -> PrismRepairResult
    func deactivate() async throws
    func unregister() async throws
}
