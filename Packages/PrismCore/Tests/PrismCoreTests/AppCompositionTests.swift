import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismUIBridge

private actor CompositionFixtureService: PackageServiceProtocol, PrismRuntimeStateReporting {
    nonisolated let descriptor: PrismProviderDescriptor
    private let environment: PrismEnvironment
    private var health: ProviderHealth

    init(id: String, modes: Set<PrismOperatingMode>, priority: Int, health: ProviderHealth = .healthy, legacy: Bool = false) {
        self.descriptor = .init(
            identifier: id,
            kind: .packageService,
            version: "1",
            priority: priority,
            operatingModes: modes,
            supportedRequirements: ["packageInstall", "packageRemove", "packageUpgrade"],
            supportedFormats: [.debianDeb, .prismNative],
            recoveryStrategies: [.reconcile],
            health: health
        )
        self.health = health
        self.environment = PrismEnvironment(
            runtimeIdentity: id + ".runtime",
            runtimeDisplayName: id + " Runtime",
            architecture: "arm64",
            capabilityReport: [.packageInstall: .available],
            compatibilityLayers: legacy ? ["legacy-bootstrap"] : [],
            legacy: legacy ? .init(bootstrapIdentifier: "fixture", rootStyle: .rootless) : nil
        )
    }

    func setHealth(_ health: ProviderHealth) { self.health = health }
    func providerRuntimeState() async -> ProviderRuntimeState {
        var state = descriptor.initialRuntimeState()
        state.health = health
        return state
    }
    func activate() async throws {}
    func deactivate() async {}
    func queryEnvironment() async throws -> PrismEnvironment { environment }
    func queryCapabilities() async throws -> [EnvironmentCapability: CapabilityStatus] { environment.capabilityReport }
    func inspectPackageState() async throws -> PackageStateSnapshot { .init(installedVersions: [:]) }
    func inspectApplicationState() async throws -> ApplicationStateSnapshot { .init(installedApps: [:], activeInjections: []) }
    func queryTransactions() async throws -> [PrismTransaction] { [] }
    func execute(_ transaction: PrismTransaction) async throws -> PrismTransaction { transaction }
    func reconcile(_ transactionID: UUID) async throws -> PrismTransaction { throw PackageServiceError.transactionNotFound(transactionID) }
}

@Test func modernRuntimeIsPreferredWhenAvailable() async throws {
    let modern = CompositionFixtureService(id: "modern", modes: [.modern], priority: 1)
    let legacy = CompositionFixtureService(id: "legacy", modes: [.legacy], priority: 999, legacy: true)
    let resolver = PrismRuntimeCompositionResolver(providers: [legacy, modern], preference: .modernFirst)

    let session = try await resolver.resolve(requirements: .init(capabilities: [], isWrite: false))

    #expect(session.providerIdentity.providerID == "modern")
}

@Test func legacyProviderUsedWhenModernUnavailable() async throws {
    let modern = CompositionFixtureService(id: "modern", modes: [.modern], priority: 999, health: .unavailable("offline"))
    let legacy = CompositionFixtureService(id: "legacy", modes: [.legacy], priority: 1, legacy: true)
    let resolver = PrismRuntimeCompositionResolver(providers: [modern, legacy], preference: .modernFirst)

    let session = try await resolver.resolve(requirements: .init(capabilities: [], isWrite: false))

    #expect(session.providerIdentity.providerID == "legacy")
}

@Test func runtimeReconnectRecomposesProviderSession() async throws {
    let modern = CompositionFixtureService(id: "modern", modes: [.modern], priority: 100)
    let legacy = CompositionFixtureService(id: "legacy", modes: [.legacy], priority: 1, legacy: true)
    let resolver = PrismRuntimeCompositionResolver(providers: [modern, legacy], preference: .modernFirst)

    let first = try await resolver.resolve(requirements: .init(capabilities: [], isWrite: false))
    #expect(first.providerIdentity.providerID == "modern")

    await modern.setHealth(.unavailable("runtime disconnected"))
    await resolver.invalidate()
    let second = try await resolver.resolve(requirements: .init(capabilities: [], isWrite: false))

    #expect(second.providerIdentity.providerID == "legacy")
}

@Test func explicitProviderPreferenceUsesPolicyPath() async throws {
    let modern = CompositionFixtureService(id: "modern", modes: [.modern], priority: 100)
    let legacy = CompositionFixtureService(id: "legacy", modes: [.legacy], priority: 1, legacy: true)
    let resolver = PrismRuntimeCompositionResolver(providers: [modern, legacy], preference: .explicit("legacy"))

    let session = try await resolver.resolve(requirements: .init(capabilities: [], isWrite: false))

    #expect(session.providerIdentity.providerID == "legacy")
}

@Test func runtimeDiscoveryAddedAfterLaunchIsPreferredOnRecomposition() async throws {
    let legacy = CompositionFixtureService(id: "legacy", modes: [.legacy], priority: 1, legacy: true)
    let modern = CompositionFixtureService(id: "discovered-modern", modes: [.modern], priority: 100)
    let discovery = RuntimePackageServiceRegistry()
    let resolver = PrismRuntimeCompositionResolver(
        providers: [legacy],
        discovery: discovery,
        preference: .modernFirst
    )

    let before = try await resolver.resolve(requirements: .init(capabilities: [], isWrite: false))
    #expect(before.providerIdentity.providerID == "legacy")

    await discovery.register(modern)
    await resolver.invalidate()
    let after = try await resolver.resolve(requirements: .init(capabilities: [], isWrite: false))
    #expect(after.providerIdentity.providerID == "discovered-modern")
}
