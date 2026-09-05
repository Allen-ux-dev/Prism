import Foundation

public enum ProviderRegistryError: Error, Equatable, Sendable {
    case providerNotFound(String)
    case providerUnavailable(String)
    case noCompatibleProvider(ProviderKind)
    case missingRecoveryStrategy(String)
}

public actor ProviderRegistry {
    private var providers: [String: any PrismProvider] = [:]
    private var runtimeStates: [String: ProviderRuntimeState] = [:]

    public init() {}

    public func register(_ provider: any PrismProvider) async {
        let identifier = provider.descriptor.identifier
        providers[identifier] = provider
        runtimeStates[identifier] = await loadRuntimeState(provider)
    }

    public func unregister(_ identifier: String) {
        providers.removeValue(forKey: identifier)
        runtimeStates.removeValue(forKey: identifier)
    }

    public func provider(_ identifier: String) throws -> any PrismProvider {
        guard let provider = providers[identifier] else { throw ProviderRegistryError.providerNotFound(identifier) }
        return provider
    }

    public func descriptors(kind: ProviderKind? = nil) -> [PrismProviderDescriptor] {
        providers.values.map { mergedDescriptor(for: $0) }
            .filter { kind == nil || $0.kind == kind! }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind < rhs.kind }
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.identifier < rhs.identifier
            }
    }

    @discardableResult
    public func refreshHealth(_ identifier: String) async throws -> ProviderRuntimeState {
        guard let provider = providers[identifier] else { throw ProviderRegistryError.providerNotFound(identifier) }
        let previous = runtimeStates[identifier]
        var refreshed = await loadRuntimeState(provider)
        if previous?.health == refreshed.health, let previous {
            refreshed.lastHealthChange = previous.lastHealthChange
        }
        runtimeStates[identifier] = refreshed
        return refreshed
    }

    public func refreshHealth() async {
        for identifier in providers.keys.sorted() {
            _ = try? await refreshHealth(identifier)
        }
    }

    public func runtimeState(_ identifier: String) throws -> ProviderRuntimeState {
        guard providers[identifier] != nil else { throw ProviderRegistryError.providerNotFound(identifier) }
        guard let state = runtimeStates[identifier] else { throw ProviderRegistryError.providerUnavailable(identifier) }
        return state
    }

    public func resolveCapabilities(_ identifier: String) throws -> [String: ProviderHealth] {
        try runtimeState(identifier).capabilityReport
    }

    public func diagnosticsSnapshot() -> [ProviderDiagnosticsSnapshot] {
        providers.values.compactMap { provider in
            let descriptor = provider.descriptor
            guard let runtimeState = runtimeStates[descriptor.identifier] else { return nil }
            return .init(identity: descriptor.identity, runtimeState: runtimeState, metadata: descriptor.diagnosticsMetadata)
        }.sorted { lhs, rhs in
            if lhs.identity.providerKind != rhs.identity.providerKind {
                return lhs.identity.providerKind < rhs.identity.providerKind
            }
            return lhs.identity.providerID < rhs.identity.providerID
        }
    }

    public func select(kind: ProviderKind, context: ProviderSelectionContext) throws -> PrismProviderDescriptor {
        if let explicit = context.explicitProviderIdentifier {
            guard let provider = providers[explicit], provider.descriptor.kind == kind else {
                throw ProviderRegistryError.providerNotFound(explicit)
            }
            let descriptor = mergedDescriptor(for: provider)
            guard descriptor.health.isUsable, isCompatible(descriptor, context: context) else {
                throw ProviderRegistryError.providerUnavailable(explicit)
            }
            if requiresSafeRecovery(context), descriptor.recoveryStrategies.isEmpty {
                throw ProviderRegistryError.missingRecoveryStrategy(explicit)
            }
            return descriptor
        }

        let compatible = providers.values.map { mergedDescriptor(for: $0) }
            .filter { $0.kind == kind && $0.health.isUsable && isCompatible($0, context: context) }

        if requiresSafeRecovery(context), !compatible.isEmpty, compatible.allSatisfy({ $0.recoveryStrategies.isEmpty }) {
            throw ProviderRegistryError.missingRecoveryStrategy(compatible.sorted { $0.identifier < $1.identifier }.first!.identifier)
        }

        let candidates = compatible
            .filter { !requiresSafeRecovery(context) || !$0.recoveryStrategies.isEmpty }
            .sorted { lhs, rhs in
                let lhsMode = modeRank(lhs, requested: context.mode)
                let rhsMode = modeRank(rhs, requested: context.mode)
                if lhsMode != rhsMode { return lhsMode < rhsMode }
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.identifier < rhs.identifier
            }

        guard let first = candidates.first else { throw ProviderRegistryError.noCompatibleProvider(kind) }
        return first
    }

    public func health() -> [String: ProviderHealth] {
        Dictionary(uniqueKeysWithValues: runtimeStates.map { ($0.key, $0.value.health) })
    }

    private func loadRuntimeState(_ provider: any PrismProvider) async -> ProviderRuntimeState {
        if let reporter = provider as? any PrismRuntimeStateReporting {
            return await reporter.providerRuntimeState()
        }
        return provider.descriptor.initialRuntimeState()
    }

    private func mergedDescriptor(for provider: any PrismProvider) -> PrismProviderDescriptor {
        let descriptor = provider.descriptor
        guard let state = runtimeStates[descriptor.identifier] else { return descriptor }
        return .init(
            identifier: descriptor.identifier,
            kind: descriptor.kind,
            version: descriptor.version,
            protocolVersion: descriptor.protocolVersion,
            priority: descriptor.priority,
            operatingModes: descriptor.operatingModes,
            supportedRequirements: descriptor.supportedRequirements,
            supportedFormats: state.supportedFormats,
            supportedVersionSchemes: state.supportedVersionSchemes,
            runtimeIdentities: descriptor.runtimeIdentities,
            recoveryStrategies: state.recoveryStrategies,
            health: state.health,
            diagnosticsMetadata: descriptor.diagnosticsMetadata
        )
    }

    private func isCompatible(_ descriptor: PrismProviderDescriptor, context: ProviderSelectionContext) -> Bool {
        guard descriptor.operatingModes.contains(context.mode) || (context.mode == .hybrid && (descriptor.operatingModes.contains(.modern) || descriptor.operatingModes.contains(.legacy))) else { return false }
        if !context.requiredRequirements.isSubset(of: descriptor.supportedRequirements) { return false }
        if !context.requiredFormats.isSubset(of: descriptor.supportedFormats) { return false }
        if let runtime = context.runtimeIdentity, !descriptor.runtimeIdentities.isEmpty, !descriptor.runtimeIdentities.contains(runtime) { return false }
        return true
    }

    private func requiresSafeRecovery(_ context: ProviderSelectionContext) -> Bool {
        let writeRequirements: Set<String> = ["packageInstall", "packageRemove", "packageUpgrade", "appInstall", "appReplace", "appRemoval", "appRefresh", "appInjection"]
        return !context.requiredRequirements.isDisjoint(with: writeRequirements)
    }

    private func modeRank(_ descriptor: PrismProviderDescriptor, requested: PrismOperatingMode) -> Int {
        switch requested {
        case .modern: return descriptor.operatingModes.contains(.modern) ? 0 : 10
        case .hybrid:
            if descriptor.operatingModes.contains(.modern) { return 0 }
            if descriptor.operatingModes.contains(.hybrid) { return 1 }
            return descriptor.operatingModes.contains(.legacy) ? 2 : 10
        case .legacy: return descriptor.operatingModes.contains(.legacy) ? 0 : 10
        }
    }
}
