import Foundation
import PrismDomain
import PrismEnvironment
import PrismTransactions

public enum RuntimeApplicationProviderKind: String, Codable, Sendable, Hashable {
    case native
    case compatibility
}

public struct RuntimeApplicationServiceDescriptor: Codable, Sendable, Hashable {
    public let identifier: String
    public let displayName: String
    public let providerKind: RuntimeApplicationProviderKind
    public let priority: Int
    public let capabilities: Set<CapabilityIdentifier>
    public let health: ProviderHealth
    public let metadata: [String: String]

    public init(
        identifier: String,
        displayName: String,
        providerKind: RuntimeApplicationProviderKind,
        priority: Int = 0,
        capabilities: Set<CapabilityIdentifier>,
        health: ProviderHealth = .unknown(nil),
        metadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.providerKind = providerKind
        self.priority = priority
        self.capabilities = capabilities
        self.health = health
        self.metadata = metadata
    }
}

public protocol RuntimeApplicationService: Sendable {
    var descriptor: RuntimeApplicationServiceDescriptor { get }
    func inspectInstalledApps() async throws -> [String: PrismInstalledApp]
    func inspectRegisteredBundleIdentifiers() async throws -> Set<String>
    func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult
    func replace(_ operation: AppInstallOperation) async throws -> BackendOperationResult
    func remove(bundleIdentifier: String) async throws -> BackendOperationResult
    func register(bundleIdentifier: String) async throws -> BackendOperationResult
    func refresh(bundleIdentifier: String) async throws -> BackendOperationResult
}

public extension RuntimeApplicationService {
    func replace(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        throw ExecutionProviderError.unsupportedOperation("app-replace")
    }
    func remove(bundleIdentifier: String) async throws -> BackendOperationResult {
        throw ExecutionProviderError.unsupportedOperation("app-remove")
    }
    func refresh(bundleIdentifier: String) async throws -> BackendOperationResult {
        throw ExecutionProviderError.unsupportedOperation("app-refresh")
    }
}

public protocol RuntimeInjectionService: Sendable {
    var descriptor: RuntimeApplicationServiceDescriptor { get }
    func inspectActiveInjections() async throws -> Set<InjectionStateKey>
    func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult
    func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult
}

public protocol RuntimeApplicationServiceDiscovering: Sendable {
    func discoverApplicationServices() async -> [any RuntimeApplicationService]
    func discoverInjectionServices() async -> [any RuntimeInjectionService]
}

public actor RuntimeApplicationServiceRegistry: RuntimeApplicationServiceDiscovering {
    public static let shared = RuntimeApplicationServiceRegistry()

    private var applicationServices: [String: any RuntimeApplicationService] = [:]
    private var injectionServices: [String: any RuntimeInjectionService] = [:]

    public init() {}

    public func registerApplication(_ service: any RuntimeApplicationService) {
        applicationServices[service.descriptor.identifier] = service
    }

    public func registerInjection(_ service: any RuntimeInjectionService) {
        injectionServices[service.descriptor.identifier] = service
    }

    public func unregisterApplication(identifier: String) {
        applicationServices.removeValue(forKey: identifier)
    }

    public func unregisterInjection(identifier: String) {
        injectionServices.removeValue(forKey: identifier)
    }

    public func removeAll() {
        applicationServices.removeAll()
        injectionServices.removeAll()
    }

    public func discoverApplicationServices() async -> [any RuntimeApplicationService] {
        applicationServices.values.sorted { $0.descriptor.identifier < $1.descriptor.identifier }
    }

    public func discoverInjectionServices() async -> [any RuntimeInjectionService] {
        injectionServices.values.sorted { $0.descriptor.identifier < $1.descriptor.identifier }
    }
}

public struct RuntimeApplicationExecutionProvider: ApplicationExecutionProvider, Sendable {
    public let service: any RuntimeApplicationService

    public init(service: any RuntimeApplicationService) {
        self.service = service
    }

    public nonisolated var identifier: String { service.descriptor.identifier }
    public nonisolated var capabilities: Set<EnvironmentCapability> {
        Set(service.descriptor.capabilities.compactMap(LegacyEnvironmentCapabilityAdapter.legacyCapability(for:)))
    }

    public func inspectInstalledApps() async throws -> [String: PrismInstalledApp] {
        try await service.inspectInstalledApps()
    }

    public func inspectRegisteredBundleIdentifiers() async throws -> Set<String> {
        try await service.inspectRegisteredBundleIdentifiers()
    }

    public func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        try await service.install(operation)
    }

    public func replace(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        try await service.replace(operation)
    }

    public func remove(bundleIdentifier: String) async throws -> BackendOperationResult {
        try await service.remove(bundleIdentifier: bundleIdentifier)
    }

    public func register(bundleIdentifier: String) async throws -> BackendOperationResult {
        try await service.register(bundleIdentifier: bundleIdentifier)
    }

    public func refresh(bundleIdentifier: String) async throws -> BackendOperationResult {
        try await service.refresh(bundleIdentifier: bundleIdentifier)
    }
}

public struct RuntimeInjectionExecutionProvider: InjectionExecutionProvider, Sendable {
    public let service: any RuntimeInjectionService

    public init(service: any RuntimeInjectionService) {
        self.service = service
    }

    public nonisolated var identifier: String { service.descriptor.identifier }
    public nonisolated var capabilities: Set<EnvironmentCapability> {
        Set(service.descriptor.capabilities.compactMap(LegacyEnvironmentCapabilityAdapter.legacyCapability(for:)))
    }

    public func inspectActiveInjections() async throws -> Set<InjectionStateKey> {
        try await service.inspectActiveInjections()
    }

    public func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult {
        try await service.apply(operation)
    }

    public func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult {
        try await service.remove(targetBundleIdentifier: targetBundleIdentifier, artifactIdentifier: artifactIdentifier)
    }
}

public struct ResolvedApplicationExecutionProvider: Sendable {
    public let descriptor: RuntimeApplicationServiceDescriptor
    public let provider: any ApplicationExecutionProvider
}

public struct ResolvedInjectionExecutionProvider: Sendable {
    public let descriptor: RuntimeApplicationServiceDescriptor
    public let provider: any InjectionExecutionProvider
}

public struct RuntimeExecutionProviderSet: Sendable {
    public let application: any ApplicationExecutionProvider
    public let injection: any InjectionExecutionProvider
    public let applicationDescriptor: RuntimeApplicationServiceDescriptor?
    public let injectionDescriptor: RuntimeApplicationServiceDescriptor?

    public init(
        application: any ApplicationExecutionProvider,
        injection: any InjectionExecutionProvider,
        applicationDescriptor: RuntimeApplicationServiceDescriptor? = nil,
        injectionDescriptor: RuntimeApplicationServiceDescriptor? = nil
    ) {
        self.application = application
        self.injection = injection
        self.applicationDescriptor = applicationDescriptor
        self.injectionDescriptor = injectionDescriptor
    }
}



public struct ApplicationRuntimeProviderResolver: Sendable {
    private let discovery: any RuntimeApplicationServiceDiscovering

    public init(discovery: any RuntimeApplicationServiceDiscovering = RuntimeApplicationServiceRegistry.shared) {
        self.discovery = discovery
    }

    public func resolveApplication(
        requiredCapabilities: Set<CapabilityIdentifier>
    ) async -> ResolvedApplicationExecutionProvider? {
        let services = await discovery.discoverApplicationServices()
        guard let service = select(services, requiredCapabilities: requiredCapabilities) else { return nil }
        let provider: any ApplicationExecutionProvider
        switch service.descriptor.providerKind {
        case .native:
            provider = RuntimeApplicationExecutionProvider(service: service)
        case .compatibility:
            provider = TrollStoreStyleApplicationExecutionAdapter(service: service)
        }
        return .init(descriptor: service.descriptor, provider: provider)
    }

    public func resolveInjection(
        requiredCapabilities: Set<CapabilityIdentifier>
    ) async -> ResolvedInjectionExecutionProvider? {
        let services = await discovery.discoverInjectionServices()
        guard let service = select(services, requiredCapabilities: requiredCapabilities) else { return nil }
        let provider: any InjectionExecutionProvider
        switch service.descriptor.providerKind {
        case .native:
            provider = RuntimeInjectionExecutionProvider(service: service)
        case .compatibility:
            provider = TrollFoolsStyleInjectionExecutionAdapter(service: service)
        }
        return .init(descriptor: service.descriptor, provider: provider)
    }

    public func resolveProviderSet() async -> RuntimeExecutionProviderSet {
        let application = await resolveApplication(requiredCapabilities: [.appInstall, .appRegistration])
        let injection = await resolveInjection(requiredCapabilities: [.appInjection])
        return .init(
            application: application?.provider ?? UnavailableApplicationExecutionProvider(),
            injection: injection?.provider ?? UnavailableInjectionExecutionProvider(),
            applicationDescriptor: application?.descriptor,
            injectionDescriptor: injection?.descriptor
        )
    }

    private func select<Service>(
        _ services: [Service],
        requiredCapabilities: Set<CapabilityIdentifier>
    ) -> Service? where Service: Sendable {
        let candidates: [(Service, RuntimeApplicationServiceDescriptor)] = services.compactMap { service in
            if let service = service as? any RuntimeApplicationService { return (service as! Service, service.descriptor) }
            if let service = service as? any RuntimeInjectionService { return (service as! Service, service.descriptor) }
            return nil
        }
        return candidates
            .filter { _, descriptor in
                descriptor.health.isUsable && requiredCapabilities.isSubset(of: descriptor.capabilities)
            }
            .sorted { lhs, rhs in
                let l = lhs.1
                let r = rhs.1
                if l.providerKind != r.providerKind { return l.providerKind == .native }
                if l.priority != r.priority { return l.priority > r.priority }
                return l.identifier < r.identifier
            }
            .first?.0
    }
}
