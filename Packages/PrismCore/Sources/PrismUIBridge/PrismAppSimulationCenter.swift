import Foundation
import PrismDomain
import PrismEnvironment
import PrismTransactions

public enum PrismAppSimulationError: Error, Equatable, Sendable {
    case installPlanNotExecutable
    case injectionPlanNotExecutable
    case targetAppNotFound(String)
}

public struct PrismAppSimulationSnapshot: Sendable, Hashable {
    public let apps: [PrismAppRow]
    public let transactions: [PrismTransactionRow]

    public init(apps: [PrismAppRow] = [], transactions: [PrismTransactionRow] = []) {
        self.apps = apps
        self.transactions = transactions
    }
}

public actor PrismAppSimulationCenter {
    private let environment: PrismEnvironment
    private let service: MockPackageServiceProvider
    private let installProvider = MockTrollStoreStyleProvider()
    private let injectionProvider = MockTrollFoolsStyleProvider()

    public init(faultController: MockProviderFaultController = .init()) {
        let environment = PrismEnvironment(
            runtimeIdentity: "dev.prism.runtime.simulation",
            runtimeVersion: "1.0",
            architecture: "arm64",
            capabilityReport: [
                .appInstall: .available,
                .appRegistration: .available,
                .appInjection: .available,
                .dylibInjection: .available,
                .frameworkInjection: .available,
                .bundleInjection: .available,
                .transactionReconcile: .available,
                .safeAbort: .available
            ],
            compatibilityLayers: []
        )
        self.environment = environment
        self.service = MockPackageServiceProvider(environment: environment, faultController: faultController)
    }


    @discardableResult
    public func simulateDemoInstall() async throws -> PrismTransaction {
        try await simulateInstall(.init(
            bundleIdentifier: "dev.prism.simulation.demo",
            displayName: "Prism Demo App",
            version: "1.0",
            architectures: ["arm64"]
        ))
    }

    @discardableResult
    public func simulateDemoInjection() async throws -> PrismTransaction {
        try await simulateInjection(
            targetBundleIdentifier: "dev.prism.simulation.demo",
            artifact: .init(
                identifier: "dev.prism.simulation.tweak",
                displayName: "Prism Demo Tweak",
                kind: .dylib,
                supportedArchitectures: ["arm64"]
            )
        )
    }

    @discardableResult
    public func simulateDemoInjectionRemoval() async throws -> PrismTransaction {
        try await simulateRemoveInjection(
            targetBundleIdentifier: "dev.prism.simulation.demo",
            artifact: .init(
                identifier: "dev.prism.simulation.tweak",
                displayName: "Prism Demo Tweak",
                kind: .dylib,
                supportedArchitectures: ["arm64"]
            )
        )
    }

    @discardableResult
    public func simulateInstall(_ ipa: IPAInspectionSnapshot) async throws -> PrismTransaction {
        let plan = installProvider.plan(ipa: ipa, environment: environment)
        guard plan.isExecutable else { throw PrismAppSimulationError.installPlanNotExecutable }
        let completed = try await service.execute(installProvider.transaction(for: plan))
        return try await service.reconcile(completed.id)
    }

    @discardableResult
    public func simulateInjection(targetBundleIdentifier: String, artifact: InjectionArtifact) async throws -> PrismTransaction {
        let appState = try await service.inspectApplicationState()
        guard let target = appState.installedApps[targetBundleIdentifier] else {
            throw PrismAppSimulationError.targetAppNotFound(targetBundleIdentifier)
        }
        let plan = injectionProvider.plan(target: target, artifact: artifact, environment: environment)
        guard plan.isExecutable else { throw PrismAppSimulationError.injectionPlanNotExecutable }
        let completed = try await service.execute(injectionProvider.applyTransaction(for: plan))
        return try await service.reconcile(completed.id)
    }

    @discardableResult
    public func simulateRemoveInjection(targetBundleIdentifier: String, artifact: InjectionArtifact) async throws -> PrismTransaction {
        let appState = try await service.inspectApplicationState()
        guard let target = appState.installedApps[targetBundleIdentifier] else {
            throw PrismAppSimulationError.targetAppNotFound(targetBundleIdentifier)
        }
        let completed = try await service.execute(injectionProvider.removeTransaction(target: target, artifact: artifact))
        return try await service.reconcile(completed.id)
    }

    public func snapshot() async throws -> PrismAppSimulationSnapshot {
        let appState = try await service.inspectApplicationState()
        let apps = appState.installedApps.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }.map { app in
            let count = appState.activeInjections.filter { $0.bundleIdentifier == app.bundleIdentifier }.count
            return PrismAppRow(id: app.bundleIdentifier, name: app.displayName, version: app.version, injectionCount: count)
        }
        let transactions = try await service.queryTransactions().sorted { $0.createdAt < $1.createdAt }.map(Self.transactionRow)
        return PrismAppSimulationSnapshot(apps: apps, transactions: transactions)
    }

    private static func transactionRow(_ tx: PrismTransaction) -> PrismTransactionRow {
        let completed = Double(tx.completedOperationIDs.count)
        let total = Double(max(1, tx.operations.count))
        return .init(
            id: tx.id,
            title: tx.operations.first.map(\.stableID) ?? "Simulation Transaction",
            phase: tx.phase.rawValue,
            progress: completed / total
        )
    }
}
