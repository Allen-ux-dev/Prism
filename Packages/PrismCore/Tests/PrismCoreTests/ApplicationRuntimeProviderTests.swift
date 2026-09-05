import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismTransactions
@testable import PrismDaemonCore

private struct TestRuntimeApplicationService: RuntimeApplicationService {
    let descriptor: RuntimeApplicationServiceDescriptor

    func inspectInstalledApps() async throws -> [String: PrismInstalledApp] { [:] }
    func inspectRegisteredBundleIdentifiers() async throws -> Set<String> { [] }
    func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        .init(operationID: "app-install:\(operation.bundleIdentifier)")
    }
    func register(bundleIdentifier: String) async throws -> BackendOperationResult {
        .init(operationID: "app-register:\(bundleIdentifier)")
    }
}

private struct TestRuntimeInjectionService: RuntimeInjectionService {
    let descriptor: RuntimeApplicationServiceDescriptor

    func inspectActiveInjections() async throws -> Set<InjectionStateKey> { [] }
    func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult {
        .init(operationID: "inject:\(operation.targetBundleIdentifier):\(operation.artifact.identifier)")
    }
    func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult {
        .init(operationID: "inject-remove:\(targetBundleIdentifier):\(artifactIdentifier)")
    }
}

private struct StaticRuntimeApplicationDiscovery: RuntimeApplicationServiceDiscovering {
    let apps: [any RuntimeApplicationService]
    let injections: [any RuntimeInjectionService]
    func discoverApplicationServices() async -> [any RuntimeApplicationService] { apps }
    func discoverInjectionServices() async -> [any RuntimeInjectionService] { injections }
}

@Test func runtimeNativeApplicationServiceIsPreferredOverCompatibility() async {
    let compatibility = TestRuntimeApplicationService(descriptor: .init(
        identifier: "compat", displayName: "Compatibility", providerKind: .compatibility,
        priority: 999, capabilities: [.appInstall, .appRegistration], health: .healthy
    ))
    let native = TestRuntimeApplicationService(descriptor: .init(
        identifier: "native", displayName: "Native", providerKind: .native,
        priority: 1, capabilities: [.appInstall, .appRegistration], health: .healthy
    ))
    let resolver = ApplicationRuntimeProviderResolver(discovery: StaticRuntimeApplicationDiscovery(apps: [compatibility, native], injections: []))
    let resolved = await resolver.resolveApplication(requiredCapabilities: [.appInstall, .appRegistration])
    #expect(resolved?.descriptor.identifier == "native")
}

@Test func compatibilityApplicationServiceIsUsedWhenNativeCannotSatisfyCapabilities() async {
    let native = TestRuntimeApplicationService(descriptor: .init(
        identifier: "native", displayName: "Native", providerKind: .native,
        priority: 100, capabilities: [.appInstall], health: .healthy
    ))
    let compatibility = TestRuntimeApplicationService(descriptor: .init(
        identifier: "compat", displayName: "Compatibility", providerKind: .compatibility,
        priority: 1, capabilities: [.appInstall, .appRegistration], health: .healthy
    ))
    let resolver = ApplicationRuntimeProviderResolver(discovery: StaticRuntimeApplicationDiscovery(apps: [native, compatibility], injections: []))
    let resolved = await resolver.resolveApplication(requiredCapabilities: [.appInstall, .appRegistration])
    #expect(resolved?.descriptor.identifier == "compat")
}

@Test func applicationResolverReturnsNilWhenNoProviderHasRequiredCapabilities() async {
    let service = TestRuntimeApplicationService(descriptor: .init(
        identifier: "read-only", displayName: "Read Only", providerKind: .native,
        priority: 1, capabilities: [.appRegistration], health: .healthy
    ))
    let resolver = ApplicationRuntimeProviderResolver(discovery: StaticRuntimeApplicationDiscovery(apps: [service], injections: []))
    #expect(await resolver.resolveApplication(requiredCapabilities: [.appInstall, .appRegistration]) == nil)
}

@Test func injectionProviderResolutionIsIndependentFromApplicationInstallation() async {
    let injection = TestRuntimeInjectionService(descriptor: .init(
        identifier: "inject-native", displayName: "Injection Native", providerKind: .native,
        priority: 1, capabilities: [.appInjection, .dylibInjection], health: .healthy
    ))
    let resolver = ApplicationRuntimeProviderResolver(discovery: StaticRuntimeApplicationDiscovery(apps: [], injections: [injection]))
    let resolved = await resolver.resolveInjection(requiredCapabilities: [.appInjection, .dylibInjection])
    #expect(resolved?.descriptor.identifier == "inject-native")
    #expect(await resolver.resolveApplication(requiredCapabilities: [.appInstall]) == nil)
}
