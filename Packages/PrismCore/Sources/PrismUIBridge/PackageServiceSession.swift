import Foundation
import PrismDomain
import PrismEnvironment
import PrismTransactions

public actor PackageServiceSession {
    public nonisolated let providerIdentity: ProviderIdentity
    public nonisolated let service: any PackageServiceProtocol
    private let registry: ProviderRegistry
    public private(set) var runtimeState: ProviderRuntimeState

    init(providerIdentity: ProviderIdentity, runtimeState: ProviderRuntimeState, service: any PackageServiceProtocol, registry: ProviderRegistry) {
        self.providerIdentity = providerIdentity
        self.runtimeState = runtimeState
        self.service = service
        self.registry = registry
    }

    public func refreshProviderState() async {
        if let refreshed = try? await registry.refreshHealth(providerIdentity.providerID) {
            runtimeState = refreshed
        }
    }

    public func reconnectIfSupported() async throws {
        await service.deactivate()
        try await service.activate()
        await refreshProviderState()
    }

    public func diagnosticsSnapshot() async -> ProviderDiagnosticsSnapshot {
        let all = await registry.diagnosticsSnapshot()
        return all.first(where: { $0.identity.providerID == providerIdentity.providerID })
            ?? .init(identity: providerIdentity, runtimeState: runtimeState)
    }
}

public actor PackageServiceSessionFactory {
    private let registry: ProviderRegistry
    private let services: [String: any PackageServiceProtocol]
    private let policy: any ProviderPolicyEvaluating
    private var registered = false

    public init(
        registry: ProviderRegistry = ProviderRegistry(),
        services: [any PackageServiceProtocol],
        policy: any ProviderPolicyEvaluating = DefaultProviderPolicy()
    ) {
        self.registry = registry
        self.services = Dictionary(uniqueKeysWithValues: services.map { ($0.descriptor.identifier, $0) })
        self.policy = policy
    }

    public func makeSession(
        mode: PrismOperatingMode,
        runtimeIdentity: String? = nil,
        requiredRequirements: Set<String> = [],
        requiredFormats: Set<PackageFormatIdentifier> = [],
        explicitProviderIdentifier: String? = nil
    ) async throws -> PackageServiceSession {
        try await ensureRegistered()
        let requirements = ProviderOperationRequirements(
            capabilities: requiredRequirements,
            packageFormats: requiredFormats,
            runtimeIdentity: runtimeIdentity,
            isWrite: !requiredRequirements.isDisjoint(with: ["packageInstall", "packageRemove", "packageUpgrade", "appInstall", "appReplace", "appRemoval", "appRefresh", "appInjection"])
        )
        let selectionEnvironment = PrismEnvironment(
            runtimeIdentity: runtimeIdentity ?? "unknown",
            architecture: "unknown",
            capabilityReport: [:]
        )
        let resolver = DefaultProviderResolver(registry: registry, kind: .packageService)
        let candidates = await resolver.candidates(for: requirements, environment: selectionEnvironment)
        let context = requirements.selectionContext(mode: mode, explicitProviderIdentifier: explicitProviderIdentifier)
        guard let selected = await policy.select(from: candidates, context: context) else {
            throw ProviderRegistryError.noCompatibleProvider(.packageService)
        }
        guard let service = services[selected.identity.providerID] else {
            throw ProviderRegistryError.providerNotFound(selected.identity.providerID)
        }
        let state = try await registry.runtimeState(selected.identity.providerID)
        return PackageServiceSession(providerIdentity: selected.identity, runtimeState: state, service: service, registry: registry)
    }


    public func refreshProviderStates() async {
        try? await ensureRegistered()
        await registry.refreshHealth()
    }

    public func diagnosticsSnapshot() async throws -> [ProviderDiagnosticsSnapshot] {
        try await ensureRegistered()
        return await registry.diagnosticsSnapshot()
    }

    private func ensureRegistered() async throws {
        guard !registered else { return }
        for service in services.values.sorted(by: { $0.descriptor.identifier < $1.descriptor.identifier }) {
            await registry.register(service)
        }
        registered = true
    }
}
