import PrismDomain
import PrismEnvironment

public protocol ProviderResolving: Sendable {
    func candidates(
        for requirements: ProviderOperationRequirements,
        environment: PrismEnvironment
    ) async -> [ProviderCandidate]
}

public struct DefaultProviderResolver: ProviderResolving {
    private let registry: ProviderRegistry
    private let kind: ProviderKind

    public init(registry: ProviderRegistry, kind: ProviderKind) {
        self.registry = registry
        self.kind = kind
    }

    public func candidates(
        for requirements: ProviderOperationRequirements,
        environment: PrismEnvironment
    ) async -> [ProviderCandidate] {
        let environmentIdentity = environment.runtimeIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        let runtimeIdentity = requirements.runtimeIdentity ?? ((environmentIdentity.isEmpty || environmentIdentity == "unknown") ? nil : environmentIdentity)
        let descriptors = await registry.descriptors(kind: kind)
        return descriptors
            .filter { descriptor in
                guard descriptor.health.isUsable else { return false }
                guard requirements.capabilities.isSubset(of: descriptor.supportedRequirements) else { return false }
                guard requirements.packageFormats.isSubset(of: descriptor.supportedFormats) else { return false }
                if let runtimeIdentity, !descriptor.runtimeIdentities.isEmpty && !descriptor.runtimeIdentities.contains(runtimeIdentity) { return false }
                if requirements.isWrite && descriptor.recoveryStrategies.isEmpty { return false }
                return true
            }
            .map(ProviderCandidate.init(descriptor:))
    }
}
