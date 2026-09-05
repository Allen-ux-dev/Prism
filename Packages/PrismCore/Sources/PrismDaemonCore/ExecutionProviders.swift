import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions

public enum ExecutionProviderError: Error, Equatable, Sendable {
    case providerUnavailable(String)
    case unsupportedOperation(String)
}

/// Typed boundary for application installation/registration implementations.
/// Concrete deployment adapters may wrap a system service or a third-party
/// helper, but Prism's transaction/IPC layers never receive raw commands.
public protocol ApplicationExecutionProvider: Sendable {
    nonisolated var identifier: String { get }
    nonisolated var capabilities: Set<EnvironmentCapability> { get }
    func inspectInstalledApps() async throws -> [String: PrismInstalledApp]
    func inspectRegisteredBundleIdentifiers() async throws -> Set<String>
    func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult
    func replace(_ operation: AppInstallOperation) async throws -> BackendOperationResult
    func remove(bundleIdentifier: String) async throws -> BackendOperationResult
    func register(bundleIdentifier: String) async throws -> BackendOperationResult
    func refresh(bundleIdentifier: String) async throws -> BackendOperationResult
}

public extension ApplicationExecutionProvider {
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

/// Typed boundary for app injection implementations. The only inputs are
/// already-validated Prism domain operations; there is intentionally no raw
/// process, path, argument, or shell-command surface here.
public protocol InjectionExecutionProvider: Sendable {
    nonisolated var identifier: String { get }
    nonisolated var capabilities: Set<EnvironmentCapability> { get }
    func inspectActiveInjections() async throws -> Set<InjectionStateKey>
    func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult
    func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult
}

public struct UnavailableApplicationExecutionProvider: ApplicationExecutionProvider, Sendable {
    public let identifier = "application-unavailable"
    public let capabilities: Set<EnvironmentCapability> = []
    public init() {}
    public func inspectInstalledApps() async throws -> [String: PrismInstalledApp] { [:] }
    public func inspectRegisteredBundleIdentifiers() async throws -> Set<String> { [] }
    public func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        throw ExecutionProviderError.providerUnavailable("application")
    }
    public func replace(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        throw ExecutionProviderError.providerUnavailable("application")
    }
    public func remove(bundleIdentifier: String) async throws -> BackendOperationResult {
        throw ExecutionProviderError.providerUnavailable("application")
    }
    public func register(bundleIdentifier: String) async throws -> BackendOperationResult {
        throw ExecutionProviderError.providerUnavailable("application")
    }
    public func refresh(bundleIdentifier: String) async throws -> BackendOperationResult {
        throw ExecutionProviderError.providerUnavailable("application")
    }
}

public struct UnavailableInjectionExecutionProvider: InjectionExecutionProvider, Sendable {
    public let identifier = "injection-unavailable"
    public let capabilities: Set<EnvironmentCapability> = []
    public init() {}
    public func inspectActiveInjections() async throws -> Set<InjectionStateKey> { [] }
    public func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult {
        throw ExecutionProviderError.providerUnavailable("injection")
    }
    public func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult {
        throw ExecutionProviderError.providerUnavailable("injection")
    }
}

public struct ExecutionProviderCapabilities: Sendable, Equatable {
    public let capabilities: Set<EnvironmentCapability>
    public init(applicationProvider: any ApplicationExecutionProvider, injectionProvider: any InjectionExecutionProvider) {
        capabilities = applicationProvider.capabilities.union(injectionProvider.capabilities)
    }
}

/// Routes each typed transaction operation to its narrow execution provider.
/// This keeps package, app installation, and injection runtimes replaceable
/// without teaching Prism Domain or the UI about implementation details.
public actor ComposableExecutionBackend: PackageExecutionBackend {
    private let packageBackend: any PackageExecutionBackend
    private let applicationProvider: any ApplicationExecutionProvider
    private let injectionProvider: any InjectionExecutionProvider

    public init(
        packageBackend: any PackageExecutionBackend,
        applicationProvider: any ApplicationExecutionProvider,
        injectionProvider: any InjectionExecutionProvider
    ) {
        self.packageBackend = packageBackend
        self.applicationProvider = applicationProvider
        self.injectionProvider = injectionProvider
    }

    public func inspectPackageState() async throws -> PackageStateSnapshot {
        try await packageBackend.inspectPackageState()
    }

    public func inspectApplicationState() async throws -> ApplicationStateSnapshot {
        let apps = try await applicationProvider.inspectInstalledApps()
        let registered = try await applicationProvider.inspectRegisteredBundleIdentifiers()
        let injections = try await injectionProvider.inspectActiveInjections()
        return ApplicationStateSnapshot(
            installedApps: apps,
            registeredBundleIdentifiers: registered,
            activeInjections: injections
        )
    }

    public func execute(_ operation: TransactionOperation) async throws -> BackendOperationResult {
        switch operation {
        case .installPackage, .upgradePackage, .removePackage, .purgePackage:
            return try await packageBackend.execute(operation)
        case .installApp(let app):
            return try await applicationProvider.install(app)
        case .replaceApp(let app):
            return try await applicationProvider.replace(app)
        case .removeApp(let bundleIdentifier):
            return try await applicationProvider.remove(bundleIdentifier: bundleIdentifier)
        case .registerApp(let bundleIdentifier):
            return try await applicationProvider.register(bundleIdentifier: bundleIdentifier)
        case .refreshApp(let bundleIdentifier):
            return try await applicationProvider.refresh(bundleIdentifier: bundleIdentifier)
        case .applyInjection(let injection):
            return try await injectionProvider.apply(injection)
        case .removeInjection(let targetBundleIdentifier, let artifactIdentifier):
            return try await injectionProvider.remove(
                targetBundleIdentifier: targetBundleIdentifier,
                artifactIdentifier: artifactIdentifier
            )
        }
    }
}
