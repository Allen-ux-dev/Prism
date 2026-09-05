import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismUIBridge

private struct ResolverFixtureProvider: PrismProvider {
    let descriptor: PrismProviderDescriptor
}

@Test func resolverReturnsCompatibleCandidatesWithoutChoosingPolicyWinner() async throws {
    let registry = ProviderRegistry()
    await registry.register(ResolverFixtureProvider(descriptor: .init(
        identifier: "modern-a", kind: .packageService, version: "1", priority: 10,
        operatingModes: [.modern], supportedRequirements: ["packageInstall"],
        supportedFormats: [.relaxinPackage], recoveryStrategies: [.reconcile], health: .healthy
    )))
    await registry.register(ResolverFixtureProvider(descriptor: .init(
        identifier: "modern-b", kind: .packageService, version: "1", priority: 20,
        operatingModes: [.modern], supportedRequirements: ["packageInstall"],
        supportedFormats: [.relaxinPackage], recoveryStrategies: [.rollback], health: .healthy
    )))
    let resolver = DefaultProviderResolver(registry: registry, kind: .packageService)
    let environment = PrismEnvironment(runtimeIdentity: "dev.relaxin.runtime", architecture: "arm64", capabilityReport: [.packageInstall: .available])
    let candidates = await resolver.candidates(
        for: .init(capabilities: ["packageInstall"], packageFormats: [.relaxinPackage], runtimeIdentity: nil, isWrite: true),
        environment: environment
    )
    #expect(Set(candidates.map(\.identity.providerID)) == ["modern-a", "modern-b"])
}

@Test func policySelectsHighestPriorityModernCandidateDeterministically() async throws {
    let candidates = [
        ProviderCandidate(descriptor: .init(identifier: "a", kind: .packageService, version: "1", priority: 10, operatingModes: [.modern], health: .healthy)),
        ProviderCandidate(descriptor: .init(identifier: "b", kind: .packageService, version: "1", priority: 20, operatingModes: [.modern], health: .healthy))
    ]
    let selected = await DefaultProviderPolicy().select(from: candidates, context: .init(mode: .modern))
    #expect(selected?.identity.providerID == "b")
}
