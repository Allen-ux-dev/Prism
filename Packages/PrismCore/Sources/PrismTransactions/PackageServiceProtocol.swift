import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution

public enum PackageServiceError: Error, Equatable, Sendable {
    case unavailable(String)
    case planNotExecutable
    case transactionNotFound(UUID)
    case unsupportedRecovery(String)
    case invalidResponse(String)
}

public struct PackageServicePreparation: Sendable, Equatable {
    public let providerIdentifier: String
    public let providerVersion: String
    public let plan: InstallPlan

    public init(providerIdentifier: String, providerVersion: String, plan: InstallPlan) {
        self.providerIdentifier = providerIdentifier
        self.providerVersion = providerVersion
        self.plan = plan
    }
}

public protocol PackageServiceProtocol:
    PrismProvider,
    PackageStateService,
    PackagePlanningService,
    PackageExecutionService,
    PackageRecoveryService
{}

public extension PackagePlanningService where Self: PrismProvider {
    func resolve(
        request: InstallRequest,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        environment: PrismEnvironment
    ) async throws -> InstallPlan {
        try InstallPlanner().plan(request: request, catalog: catalog, installed: installed, environment: environment)
    }

    func prepare(_ plan: InstallPlan) async throws -> PackageServicePreparation {
        guard plan.isExecutable else { throw PackageServiceError.planNotExecutable }
        return PackageServicePreparation(providerIdentifier: descriptor.identifier, providerVersion: descriptor.version, plan: plan)
    }

    func syncRepositorySources(_ sources: [URL]) async throws {}
}

public extension PackageRecoveryService where Self: PrismProvider {
    var recoveryStrategies: Set<ProviderRecoveryStrategy> { descriptor.recoveryStrategies }

    func rollback(_ transactionID: UUID) async throws -> PrismTransaction {
        throw PackageServiceError.unsupportedRecovery("rollback")
    }

    func safeAbort(_ transactionID: UUID) async throws -> PrismTransaction {
        throw PackageServiceError.unsupportedRecovery("safeAbort")
    }
}
