import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions

public actor MockPackageServiceProvider: PackageServiceProtocol, PrismRuntimeStateReporting {
    public nonisolated let descriptor = PrismProviderDescriptor(
        identifier: "dev.prism.service.mock", kind: .packageService, version: "1.0", priority: 1,
        operatingModes: [.modern, .hybrid, .legacy],
        supportedRequirements: ["packageInstall", "packageRemove", "packageUpgrade", "appInstall", "appInjection"],
        supportedFormats: [.debianDeb, .prismNative, .prismSource, .relaxinPackage],
        recoveryStrategies: [.reconcile, .rollback, .safeAbort],
        health: .healthy,
        diagnosticsMetadata: ["simulation": "true", "faultHarness": "deterministic"]
    )

    private let environment: PrismEnvironment
    private let backend: MockPackageExecutionBackend
    private let journalStore: any TransactionJournalStore
    private let faultController: MockProviderFaultController

    public init(
        environment: PrismEnvironment,
        backend: MockPackageExecutionBackend = .init(),
        journalStore: any TransactionJournalStore = InMemoryTransactionJournalStore(),
        faultController: MockProviderFaultController = .init()
    ) {
        self.environment = environment
        self.backend = backend
        self.journalStore = journalStore
        self.faultController = faultController
    }

    public func activate() async throws {}
    public func deactivate() async {}
    public func queryEnvironment() async throws -> PrismEnvironment { environment }
    public func queryCapabilities() async throws -> [EnvironmentCapability : CapabilityStatus] { environment.capabilityReport }
    public func inspectPackageState() async throws -> PackageStateSnapshot { try await backend.inspectPackageState() }
    public func inspectApplicationState() async throws -> ApplicationStateSnapshot { try await backend.inspectApplicationState() }
    public func queryTransactions() async throws -> [PrismTransaction] { try await journalStore.loadAll().map(\.transaction) }

    public func providerRuntimeState() async -> ProviderRuntimeState {
        var state = descriptor.initialRuntimeState()
        state.health = await faultController.providerHealth()
        state.diagnosticSummary = state.health.reason
        return state
    }

    public func execute(_ transaction: PrismTransaction) async throws -> PrismTransaction {
        let beforePackages = try await backend.inspectPackageState()
        let beforeApps = try await backend.inspectApplicationState()
        var journal = TransactionJournal(
            transaction: transaction,
            stateBeforePackages: beforePackages,
            stateBeforeApplications: beforeApps,
            providerIdentifier: descriptor.identifier,
            providerVersion: descriptor.version
        )
        try await journalStore.save(journal)

        let mode = await faultController.currentMode()
        let result: PrismTransaction
        switch mode {
        case .failBeforeExecution:
            var tx = transaction
            tx.phase = .failed
            tx.failureMessage = "Simulated failure before execution"
            tx.updatedAt = Date()
            result = tx
        case .degradedBeforeExecution:
            var tx = transaction
            tx.phase = .interrupted
            tx.failureMessage = "Provider degraded before execution"
            tx.updatedAt = Date()
            result = tx
        case .failAfterOperation(let index):
            result = try await executePrefix(transaction, through: index, terminalPhase: .failed, markCompleted: true, message: "Simulated failure during execution")
        case .interruptAfterOperation(let index):
            result = try await executePrefix(transaction, through: index, terminalPhase: .interrupted, markCompleted: true, message: "Simulated interruption")
        case .degradedDuringExecution:
            result = try await executePrefix(transaction, through: 0, terminalPhase: .interrupted, markCompleted: true, message: "Provider degraded during execution")
        case .reconcileAlreadyApplied:
            result = try await executePrefix(transaction, through: max(0, transaction.operations.count - 1), terminalPhase: .interrupted, markCompleted: false, message: "Simulated lost completion acknowledgement")
        case .reconcilePartiallyApplied:
            result = try await executePrefix(transaction, through: 0, terminalPhase: .interrupted, markCompleted: false, message: "Simulated partial application")
        case .normal, .rollbackSucceeds, .rollbackFails, .safeAbortSucceeds, .safeAbortFails:
            result = await TransactionExecutor().execute(transaction, backend: backend)
        }

        journal.transaction = result
        journal.lastKnownPackages = try await backend.inspectPackageState()
        journal.lastKnownApplications = try await backend.inspectApplicationState()
        try await journalStore.save(journal)
        return result
    }

    public func reconcile(_ transactionID: UUID) async throws -> PrismTransaction {
        guard let journal = try await journalStore.load(id: transactionID) else { throw PackageServiceError.transactionNotFound(transactionID) }
        let reconciled = try await TransactionReconciler().reconcile(journal, backend: backend, activeProviderIdentifier: descriptor.identifier)
        try await journalStore.save(reconciled)
        return reconciled.transaction
    }

    public func rollback(_ transactionID: UUID) async throws -> PrismTransaction {
        guard var journal = try await journalStore.load(id: transactionID) else { throw PackageServiceError.transactionNotFound(transactionID) }
        if await faultController.currentMode() == .rollbackFails {
            journal.transaction.phase = .needsReview
            journal.transaction.failureMessage = "Simulated rollback failure"
            journal.transaction.updatedAt = Date()
            try await journalStore.save(journal)
            return journal.transaction
        }
        await backend.replaceState(packages: journal.stateBeforePackages, applications: journal.stateBeforeApplications)
        journal.transaction.phase = .rolledBack
        journal.transaction.completedOperationIDs = []
        journal.transaction.updatedAt = Date()
        journal.lastKnownPackages = journal.stateBeforePackages
        journal.lastKnownApplications = journal.stateBeforeApplications
        try await journalStore.save(journal)
        return journal.transaction
    }

    public func safeAbort(_ transactionID: UUID) async throws -> PrismTransaction {
        guard var journal = try await journalStore.load(id: transactionID) else { throw PackageServiceError.transactionNotFound(transactionID) }
        if await faultController.currentMode() == .safeAbortFails {
            journal.transaction.phase = .needsReview
            journal.transaction.failureMessage = "Simulated safe-abort failure"
            journal.transaction.updatedAt = Date()
            try await journalStore.save(journal)
            return journal.transaction
        }
        guard ![.completed, .rolledBack].contains(journal.transaction.phase) else {
            throw PackageServiceError.unsupportedRecovery("transaction already finalized")
        }
        journal.transaction.phase = .cancelled
        journal.transaction.updatedAt = Date()
        try await journalStore.save(journal)
        return journal.transaction
    }

    private func executePrefix(
        _ transaction: PrismTransaction,
        through requestedIndex: Int,
        terminalPhase: TransactionPhase,
        markCompleted: Bool,
        message: String
    ) async throws -> PrismTransaction {
        var tx = transaction
        tx.phase = .executing
        guard !transaction.operations.isEmpty else {
            tx.phase = terminalPhase
            tx.failureMessage = message
            return tx
        }
        let lastIndex = min(max(requestedIndex, 0), transaction.operations.count - 1)
        for index in 0...lastIndex {
            let operation = transaction.operations[index]
            _ = try await backend.execute(operation)
            if markCompleted { tx.completedOperationIDs.insert(operation.stableID) }
        }
        tx.phase = terminalPhase
        tx.failureMessage = message
        tx.updatedAt = Date()
        return tx
    }
}
