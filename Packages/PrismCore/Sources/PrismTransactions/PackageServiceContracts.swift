import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution

public protocol PackageStateService: Sendable {
    func queryEnvironment() async throws -> PrismEnvironment
    func queryCapabilities() async throws -> [EnvironmentCapability: CapabilityStatus]
    func inspectPackageState() async throws -> PackageStateSnapshot
    func inspectApplicationState() async throws -> ApplicationStateSnapshot
    func queryTransactions() async throws -> [PrismTransaction]
}


public extension PackageStateService {
    func queryCapabilityStates() async throws -> [CapabilityIdentifier: CapabilityState] {
        LegacyEnvironmentCapabilityAdapter.convert(try await queryCapabilities())
    }
}

public protocol PackagePlanningService: Sendable {
    func resolve(
        request: InstallRequest,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        environment: PrismEnvironment
    ) async throws -> InstallPlan
    func prepare(_ plan: InstallPlan) async throws -> PackageServicePreparation
    func syncRepositorySources(_ sources: [URL]) async throws
}

public protocol PackageExecutionService: Sendable {
    func activate() async throws
    func deactivate() async
    func execute(_ transaction: PrismTransaction) async throws -> PrismTransaction
}

public protocol PackageRecoveryService: Sendable {
    var recoveryStrategies: Set<ProviderRecoveryStrategy> { get }
    func reconcile(_ transactionID: UUID) async throws -> PrismTransaction
    func rollback(_ transactionID: UUID) async throws -> PrismTransaction
    func safeAbort(_ transactionID: UUID) async throws -> PrismTransaction
}
