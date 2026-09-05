import PrismDomain
import PrismEnvironment
import PrismTransactions

/// Compatibility adapter for an already-authorized application installation service.
/// It deliberately exposes only Prism's typed application operations.
public struct TrollStoreStyleApplicationExecutionAdapter: ApplicationExecutionProvider, Sendable {
    public let service: any RuntimeApplicationService

    public init(service: any RuntimeApplicationService) {
        self.service = service
    }

    public nonisolated var identifier: String { service.descriptor.identifier }
    public nonisolated var capabilities: Set<EnvironmentCapability> {
        Set(service.descriptor.capabilities.compactMap(LegacyEnvironmentCapabilityAdapter.legacyCapability(for:)))
            .intersection([.appInstall, .appRegistration, .appReplace, .appRemoval, .appRefresh, .ipaInstall])
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

/// Compatibility adapter for an already-authorized injection service.
/// No process IDs, executable paths, loader arguments, or shell commands cross this boundary.
public struct TrollFoolsStyleInjectionExecutionAdapter: InjectionExecutionProvider, Sendable {
    public let service: any RuntimeInjectionService

    public init(service: any RuntimeInjectionService) {
        self.service = service
    }

    public nonisolated var identifier: String { service.descriptor.identifier }
    public nonisolated var capabilities: Set<EnvironmentCapability> {
        Set(service.descriptor.capabilities.compactMap(LegacyEnvironmentCapabilityAdapter.legacyCapability(for:)))
            .intersection([.appInjection, .dylibInjection, .frameworkInjection, .bundleInjection])
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
