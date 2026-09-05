import Foundation
import Testing
@testable import PrismDomain
@testable import PrismTransactions
@testable import PrismDaemonCore
@testable import PrismUIBridge

private struct WiringApplicationService: RuntimeApplicationService {
    let descriptor: RuntimeApplicationServiceDescriptor
    func inspectInstalledApps() async throws -> [String: PrismInstalledApp] { [:] }
    func inspectRegisteredBundleIdentifiers() async throws -> Set<String> { [] }
    func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult { .init(operationID: "app-install:\(operation.bundleIdentifier)") }
    func register(bundleIdentifier: String) async throws -> BackendOperationResult { .init(operationID: "app-register:\(bundleIdentifier)") }
}

private struct WiringInjectionService: RuntimeInjectionService {
    let descriptor: RuntimeApplicationServiceDescriptor
    func inspectActiveInjections() async throws -> Set<InjectionStateKey> { [] }
    func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult { .init(operationID: "inject:\(operation.targetBundleIdentifier):\(operation.artifact.identifier)") }
    func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult { .init(operationID: "inject-remove:\(targetBundleIdentifier):\(artifactIdentifier)") }
}

@Test func runtimeProviderSetUsesRegisteredNativeApplicationService() async {
    let registry = RuntimeApplicationServiceRegistry()
    let native = WiringApplicationService(descriptor: .init(
        identifier: "native.install", displayName: "Native Install", providerKind: .native,
        priority: 1, capabilities: [.appInstall, .appRegistration], health: .healthy
    ))
    await registry.registerApplication(native)
    let providers = await ApplicationRuntimeProviderResolver(discovery: registry).resolveProviderSet()
    #expect(providers.application.identifier == "native.install")
    #expect(providers.injection.identifier == "injection-unavailable")
}

@Test func runtimeProviderSetFallsBackToUnavailableWhenNoServiceExists() async {
    let registry = RuntimeApplicationServiceRegistry()
    let providers = await ApplicationRuntimeProviderResolver(discovery: registry).resolveProviderSet()
    #expect(providers.application.identifier == "application-unavailable")
    #expect(providers.injection.identifier == "injection-unavailable")
}

@Test func runtimeProviderSetResolvesInstallationAndInjectionIndependently() async {
    let registry = RuntimeApplicationServiceRegistry()
    let install = WiringApplicationService(descriptor: .init(
        identifier: "compat.install", displayName: "Compatibility Install", providerKind: .compatibility,
        priority: 1, capabilities: [.appInstall, .appRegistration], health: .healthy
    ))
    let injection = WiringInjectionService(descriptor: .init(
        identifier: "native.inject", displayName: "Native Injection", providerKind: .native,
        priority: 1, capabilities: [.appInjection], health: .healthy
    ))
    await registry.registerApplication(install)
    await registry.registerInjection(injection)
    let providers = await ApplicationRuntimeProviderResolver(discovery: registry).resolveProviderSet()
    #expect(providers.application.identifier == "compat.install")
    #expect(providers.injection.identifier == "native.inject")
}

@Test func modernRuntimeAdvertisesApplicationTransactionRequirements() {
    #expect(RelaxinRuntimeProvider.applicationRuntimeRequirements == [
        "appInstall", "appRegistration", "appReplace", "appRemoval", "appRefresh", "appInjection"
    ])
}
