import Foundation

public struct ProviderCandidate: Sendable, Hashable {
    public let descriptor: PrismProviderDescriptor

    public init(descriptor: PrismProviderDescriptor) {
        self.descriptor = descriptor
    }

    public var identity: ProviderIdentity { descriptor.identity }
    public var runtimeState: ProviderRuntimeState { descriptor.initialRuntimeState() }
}

public protocol ProviderPolicyEvaluating: Sendable {
    func select(
        from candidates: [ProviderCandidate],
        context: ProviderSelectionContext
    ) async -> ProviderCandidate?
}

public struct DefaultProviderPolicy: ProviderPolicyEvaluating {
    public init() {}

    public func select(
        from candidates: [ProviderCandidate],
        context: ProviderSelectionContext
    ) async -> ProviderCandidate? {
        if let explicit = context.explicitProviderIdentifier {
            return candidates.first { $0.identity.providerID == explicit && $0.descriptor.health.isUsable }
        }

        return candidates
            .filter { $0.descriptor.health.isUsable }
            .sorted { lhs, rhs in
                let lhsMode = modeRank(lhs.descriptor, requested: context.mode)
                let rhsMode = modeRank(rhs.descriptor, requested: context.mode)
                if lhsMode != rhsMode { return lhsMode < rhsMode }
                if lhs.descriptor.priority != rhs.descriptor.priority { return lhs.descriptor.priority > rhs.descriptor.priority }
                return lhs.identity.providerID < rhs.identity.providerID
            }
            .first
    }

    private func modeRank(_ descriptor: PrismProviderDescriptor, requested: PrismOperatingMode) -> Int {
        switch requested {
        case .modern:
            return descriptor.operatingModes.contains(.modern) ? 0 : 10
        case .hybrid:
            if descriptor.operatingModes.contains(.modern) { return 0 }
            if descriptor.operatingModes.contains(.hybrid) { return 1 }
            return descriptor.operatingModes.contains(.legacy) ? 2 : 10
        case .legacy:
            return descriptor.operatingModes.contains(.legacy) ? 0 : 10
        }
    }
}
