import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismUIBridge

private struct ContainmentFixtureProvider: PrismProvider { let descriptor: PrismProviderDescriptor }

@Test func failedRepositoryProviderDoesNotDisableHealthyPackageService() async throws {
    let registry = ProviderRegistry()
    await registry.register(ContainmentFixtureProvider(descriptor: .init(identifier: "repo", kind: .repository, version: "1", health: .unavailable("offline"))))
    await registry.register(ContainmentFixtureProvider(descriptor: .init(identifier: "service", kind: .packageService, version: "1", operatingModes: [.modern], supportedRequirements: ["packageInstall"], supportedFormats: [.relaxinPackage], recoveryStrategies: [.reconcile], health: .healthy)))

    let environment = PrismEnvironment(runtimeIdentity: "runtime", architecture: "arm64", capabilityReport: [.packageInstall: .available])
    let resolver = DefaultProviderResolver(registry: registry, kind: .packageService)
    let candidates = await resolver.candidates(for: .init(capabilities: ["packageInstall"], packageFormats: [.relaxinPackage], isWrite: true), environment: environment)
    #expect(candidates.count == 1)
    #expect(candidates[0].identity.providerID == "service")
}
