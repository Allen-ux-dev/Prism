import PrismDomain

public protocol RelaxinRuntimeInstallerTransport: Sendable {
    func inspectInstallation() async throws -> PrismInstallationState
    func install(_ request: PrismInstallRequest) async throws -> PrismInstallationReceipt
    func upgrade(_ request: PrismUpgradeRequest) async throws -> PrismInstallationReceipt
    func registerPrism() async throws
    func registerPackageService() async throws
    func registerLifecycle() async throws
    func activate() async throws
    func repair() async throws -> PrismRepairResult
    func deactivate() async throws
    func unregister() async throws
}

public struct RelaxinRuntimeInstallerAdapter: PrismRuntimeInstallerProtocol, Sendable {
    private let transport: any RelaxinRuntimeInstallerTransport

    public init(transport: any RelaxinRuntimeInstallerTransport) {
        self.transport = transport
    }

    public func inspectInstallation() async throws -> PrismInstallationState { try await transport.inspectInstallation() }
    public func install(request: PrismInstallRequest) async throws -> PrismInstallationReceipt { try await transport.install(request) }
    public func upgrade(request: PrismUpgradeRequest) async throws -> PrismInstallationReceipt { try await transport.upgrade(request) }
    public func registerPrism() async throws { try await transport.registerPrism() }
    public func registerPackageService() async throws { try await transport.registerPackageService() }
    public func registerLifecycle() async throws { try await transport.registerLifecycle() }
    public func activate() async throws { try await transport.activate() }
    public func repair() async throws -> PrismRepairResult { try await transport.repair() }
    public func deactivate() async throws { try await transport.deactivate() }
    public func unregister() async throws { try await transport.unregister() }
}
