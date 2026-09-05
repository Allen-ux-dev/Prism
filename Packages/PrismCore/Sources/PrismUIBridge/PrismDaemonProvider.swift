import Foundation
import PrismDomain
import PrismEnvironment
import PrismPrivilegedProtocol
import PrismResolution
import PrismTransactions

public actor PrismDaemonProvider: PackageServiceProtocol {
    public nonisolated let descriptor = PrismProviderDescriptor(
        identifier: "dev.prism.service.daemon",
        kind: .packageService,
        version: "0.4.1",
        priority: 20,
        operatingModes: [.hybrid, .legacy],
        supportedRequirements: ["packageInstall", "packageRemove", "packageUpgrade", "repositoryRefresh", "legacyDebCompatibility"],
        supportedFormats: [.debianDeb],
        recoveryStrategies: [.reconcile, .safeAbort],
        health: .healthy,
        diagnosticsMetadata: ["role": "Legacy compatibility service"]
    )

    private let session: PrivilegedSessionManager

    public init(socketPath: String, clientIdentifier: String) {
        self.session = PrivilegedSessionManager(
            transport: UnixSocketPrivilegedTransport(path: socketPath),
            clientIdentifier: clientIdentifier
        )
    }

    public init(session: PrivilegedSessionManager) { self.session = session }

    public func activate() async throws { _ = try await session.connect() }
    public func deactivate() async { }

    public func queryEnvironment() async throws -> PrismEnvironment {
        guard case .environment(let value) = try await session.request(.queryEnvironment) else {
            throw PackageServiceError.invalidResponse("Environment unavailable")
        }
        return value
    }

    public func queryCapabilities() async throws -> [EnvironmentCapability: CapabilityStatus] {
        let environment = try await queryEnvironment()
        return environment.capabilityReport
    }

    public func inspectPackageState() async throws -> PackageStateSnapshot {
        guard case .packageState(let value) = try await session.request(.queryPackageState) else {
            throw PackageServiceError.invalidResponse("Package state unavailable")
        }
        return value
    }

    public func inspectApplicationState() async throws -> ApplicationStateSnapshot {
        guard case .applicationState(let value) = try await session.request(.queryApplicationState) else {
            throw PackageServiceError.invalidResponse("Application state unavailable")
        }
        return value
    }

    public func queryTransactions() async throws -> [PrismTransaction] {
        guard case .transactions(let value) = try await session.request(.queryTransactions) else {
            throw PackageServiceError.invalidResponse("Transactions unavailable")
        }
        return value
    }

    public func execute(_ transaction: PrismTransaction) async throws -> PrismTransaction {
        let response = try await session.request(.submitTransaction(transaction))
        if case .transaction(let value) = response { return value }
        if case .rejected(let message) = response { throw PackageServiceError.unavailable(message) }
        throw PackageServiceError.invalidResponse("Unexpected transaction response")
    }

    public func reconcile(_ transactionID: UUID) async throws -> PrismTransaction {
        let response = try await session.request(.reconcileState(transactionID))
        if case .transaction(let value) = response { return value }
        if case .rejected(let message) = response { throw PackageServiceError.unavailable(message) }
        throw PackageServiceError.invalidResponse("Unexpected reconcile response")
    }

    public func safeAbort(_ transactionID: UUID) async throws -> PrismTransaction {
        let response = try await session.request(.cancelTransaction(transactionID))
        if case .transaction(let value) = response { return value }
        if case .rejected(let message) = response { throw PackageServiceError.unavailable(message) }
        throw PackageServiceError.invalidResponse("Unexpected abort response")
    }

    public func syncRepositorySources(_ sources: [URL]) async throws {
        let descriptors = sources.map(RepositorySourceDescriptor.init)
        let response = try await session.request(.syncSources(descriptors))
        if case .rejected(let message) = response { throw PackageServiceError.unavailable(message) }
    }
}
