import PrismDomain
import PrismTransactions

public enum ProviderPreference: Sendable, Equatable {
    case modernFirst
    case compatibilityFirst
    case explicit(String)
}

public protocol RuntimePackageServiceDiscovering: Sendable {
    func discoverPackageServices() async -> [any PackageServiceProtocol]
}

public actor RuntimePackageServiceRegistry: RuntimePackageServiceDiscovering {
    public static let shared = RuntimePackageServiceRegistry()
    private var services: [String: any PackageServiceProtocol] = [:]

    public init() {}

    public func register(_ service: any PackageServiceProtocol) {
        services[service.descriptor.identifier] = service
    }

    public func unregister(providerID: String) {
        services.removeValue(forKey: providerID)
    }

    public func discoverPackageServices() async -> [any PackageServiceProtocol] {
        services.values.sorted { $0.descriptor.identifier < $1.descriptor.identifier }
    }
}

public struct EmptyRuntimePackageServiceDiscovery: RuntimePackageServiceDiscovering {
    public init() {}
    public func discoverPackageServices() async -> [any PackageServiceProtocol] { [] }
}

public protocol PrismRuntimeCompositionResolving: Sendable {
    func resolve(requirements: ProviderOperationRequirements) async throws -> PackageServiceSession
    func invalidate() async
}

public actor PrismRuntimeCompositionResolver: PrismRuntimeCompositionResolving {
    private let staticProviders: [any PackageServiceProtocol]
    private let discovery: any RuntimePackageServiceDiscovering
    private let preference: ProviderPreference
    private let policy: any ProviderPolicyEvaluating

    public init(
        providers: [any PackageServiceProtocol],
        discovery: any RuntimePackageServiceDiscovering = EmptyRuntimePackageServiceDiscovery(),
        preference: ProviderPreference = .modernFirst,
        policy: any ProviderPolicyEvaluating = DefaultProviderPolicy()
    ) {
        self.staticProviders = providers
        self.discovery = discovery
        self.preference = preference
        self.policy = policy
    }

    public func resolve(requirements: ProviderOperationRequirements) async throws -> PackageServiceSession {
        let discovered = await discovery.discoverPackageServices()
        let providers = deduplicated(discovered + staticProviders)
        let factory = PackageServiceSessionFactory(
            registry: ProviderRegistry(),
            services: providers,
            policy: policy
        )
        await factory.refreshProviderStates()

        switch preference {
        case .modernFirst:
            return try await factory.makeSession(
                mode: .modern,
                runtimeIdentity: requirements.runtimeIdentity,
                requiredRequirements: requirements.capabilities,
                requiredFormats: requirements.packageFormats
            )
        case .compatibilityFirst:
            return try await factory.makeSession(
                mode: .legacy,
                runtimeIdentity: requirements.runtimeIdentity,
                requiredRequirements: requirements.capabilities,
                requiredFormats: requirements.packageFormats
            )
        case .explicit(let identifier):
            return try await factory.makeSession(
                mode: .hybrid,
                runtimeIdentity: requirements.runtimeIdentity,
                requiredRequirements: requirements.capabilities,
                requiredFormats: requirements.packageFormats,
                explicitProviderIdentifier: identifier
            )
        }
    }

    public func invalidate() async {
        // Discovery is intentionally queried on every resolve. Invalidation is a semantic hook
        // for callers that need to mark the current session stale without pinning a replacement.
    }

    private func deduplicated(_ providers: [any PackageServiceProtocol]) -> [any PackageServiceProtocol] {
        var byID: [String: any PackageServiceProtocol] = [:]
        // Runtime-discovered providers appear first and therefore win duplicate identities.
        for provider in providers where byID[provider.descriptor.identifier] == nil {
            byID[provider.descriptor.identifier] = provider
        }
        return byID.values.sorted { lhs, rhs in
            if lhs.descriptor.priority != rhs.descriptor.priority { return lhs.descriptor.priority > rhs.descriptor.priority }
            return lhs.descriptor.identifier < rhs.descriptor.identifier
        }
    }
}
