import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismTransactions
@testable import PrismUIBridge

@Test func bootstrapSelectsThroughRegistryWithoutConstructingLegacyProviderInFacade() async throws {
    let environment = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        architecture: "arm64",
        capabilityReport: [.packageInstall: .available, .transactionReconcile: .available]
    )
    let modern = MockPackageServiceProvider(environment: environment)
    let registry = ProviderRegistry()
    let factory = PackageServiceSessionFactory(registry: registry, services: [modern])

    let session = try await factory.makeSession(
        mode: .modern,
        runtimeIdentity: "dev.relaxin.runtime"
    )

    #expect(session.providerIdentity.providerID == modern.descriptor.identifier)
    #expect(session.providerIdentity.providerKind == .packageService)
}

@Test func packageServiceSessionRefreshesLiveRegistryState() async throws {
    let environment = PrismEnvironment(
        runtimeIdentity: "mock-modern",
        architecture: "arm64",
        capabilityReport: [.packageInstall: .available, .transactionReconcile: .available]
    )
    let service = MockPackageServiceProvider(environment: environment)
    let registry = ProviderRegistry()
    let factory = PackageServiceSessionFactory(registry: registry, services: [service])
    let session = try await factory.makeSession(mode: .modern)

    await session.refreshProviderState()
    let diagnostics = await session.diagnosticsSnapshot()

    #expect(diagnostics.identity.providerID == service.descriptor.identifier)
    #expect(diagnostics.runtimeState.health == .healthy)
}
