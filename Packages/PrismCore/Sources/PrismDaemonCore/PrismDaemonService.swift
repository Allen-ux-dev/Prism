import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions
import PrismPrivilegedProtocol

public protocol SourceSynchronizing: Sendable { func sync(_ sources: [RepositorySourceDescriptor]) async throws }
public struct NoopSourceSynchronizer: SourceSynchronizing { public init() {}; public func sync(_ sources: [RepositorySourceDescriptor]) async throws {} }

public struct PrismDaemonRuntimeComposition: Sendable {
    public let environment: PrismEnvironment
    public let backend: any PackageExecutionBackend

    public init(environment: PrismEnvironment, backend: any PackageExecutionBackend) {
        self.environment = environment
        self.backend = backend
    }
}

public actor PrismDaemonService {
    public typealias RuntimeCompositionRecomposer = @Sendable () async -> PrismDaemonRuntimeComposition

    private var environment: PrismEnvironment
    private var backend: any PackageExecutionBackend
    private let journalStore: any TransactionJournalStore
    private let sourceSynchronizer: any SourceSynchronizing
    private let allowedClientIdentifiers: Set<String>
    private let runtimeBridgeCoordinator: RuntimeServiceBridgeCoordinator?
    private let runtimeCompositionRecomposer: RuntimeCompositionRecomposer?
    private var authenticatedSessions: Set<UUID> = []
    private var transactions: [UUID: PrismTransaction] = [:]
    private var didRestorePersistedTransactions = false

    public init(
        environment: PrismEnvironment,
        backend: any PackageExecutionBackend,
        journalStore: any TransactionJournalStore,
        sourceSynchronizer: any SourceSynchronizing = NoopSourceSynchronizer(),
        allowedClientIdentifiers: Set<String>,
        runtimeBridgeCoordinator: RuntimeServiceBridgeCoordinator? = nil,
        runtimeCompositionRecomposer: RuntimeCompositionRecomposer? = nil
    ) {
        self.environment = environment
        self.backend = backend
        self.journalStore = journalStore
        self.sourceSynchronizer = sourceSynchronizer
        self.allowedClientIdentifiers = allowedClientIdentifiers
        self.runtimeBridgeCoordinator = runtimeBridgeCoordinator
        self.runtimeCompositionRecomposer = runtimeCompositionRecomposer
    }

    public func handle(_ request: PrivilegedRequest, sessionID: UUID) async -> PrivilegedResponse {
        if case .handshake(let hello) = request {
            guard hello.protocolVersion == 1, allowedClientIdentifiers.contains(hello.clientIdentifier) else { return .rejected("Client validation failed") }
            authenticatedSessions.insert(sessionID); return .hello(.init(serviceVersion: "0.4.1"))
        }
        guard authenticatedSessions.contains(sessionID) else { return .rejected("Handshake required") }
        do {
            switch request {
            case .handshake: return .rejected("Handshake already completed")
            case .queryEnvironment: return .environment(environment)
            case .queryCapabilities: return .capabilities(environment.capabilities)
            case .queryTransactions:
                try await restorePersistedTransactionsIfNeeded()
                return .transactions(transactions.values.sorted { $0.createdAt < $1.createdAt })
            case .submitTransaction(let transaction):
                let beforePackages = try await backend.inspectPackageState(); let beforeApps = try await backend.inspectApplicationState()
                var journal = TransactionJournal(transaction: transaction, stateBeforePackages: beforePackages, stateBeforeApplications: beforeApps)
                try await journalStore.save(journal); transactions[transaction.id] = transaction
                let completed = await TransactionExecutor().execute(transaction, backend: backend)
                journal.transaction = completed; journal.lastKnownPackages = try await backend.inspectPackageState(); journal.lastKnownApplications = try await backend.inspectApplicationState()
                try await journalStore.save(journal); transactions[completed.id] = completed
                return .transaction(completed)
            case .cancelTransaction(let id):
                guard var tx = transactions[id] else { return .rejected("Unknown transaction") }
                if [.created, .preparing, .resolving, .ready].contains(tx.phase) { tx.phase = .cancelled; tx.updatedAt = Date(); transactions[id] = tx; return .transaction(tx) }
                return .rejected("Transaction cannot be cancelled in its current phase")
            case .queryPackageState: return .packageState(try await backend.inspectPackageState())
            case .queryApplicationState: return .applicationState(try await backend.inspectApplicationState())
            case .reconcileState(let id):
                guard let journal = try await journalStore.load(id: id) else { return .rejected("Unknown transaction") }
                let reconciled = try await TransactionReconciler().reconcile(journal, backend: backend)
                try await journalStore.save(reconciled); transactions[id] = reconciled.transaction; return .transaction(reconciled.transaction)
            case .syncSources(let sources):
                try await sourceSynchronizer.sync(sources)
                return .accepted
            case .queryRuntimeBridgeStatus:
                guard let runtimeBridgeCoordinator else {
                    return .runtimeBridgeStatus(.init(connectionState: .offline))
                }
                return .runtimeBridgeStatus(await runtimeBridgeCoordinator.currentStatus())
            case .reconnectRuntimeBridge:
                guard let runtimeBridgeCoordinator else {
                    return .runtimeBridgeStatus(.init(connectionState: .offline))
                }
                guard !hasActiveWriteTransaction else {
                    return .rejected("Runtime bridge recompose blocked by active transaction")
                }
                let status = await runtimeBridgeCoordinator.reconnect()
                if let runtimeCompositionRecomposer {
                    let composition = await runtimeCompositionRecomposer()
                    environment = composition.environment
                    backend = composition.backend
                }
                return .runtimeBridgeStatus(status)
            case .setRuntimeBackgroundEnabled(let enabled):
                guard let runtimeBridgeCoordinator else {
                    return .rejected("Runtime bridge unavailable")
                }
                _ = try await runtimeBridgeCoordinator.setBackgroundEnabled(enabled)
                return .runtimeBridgeStatus(await runtimeBridgeCoordinator.currentStatus())
            }
        } catch { return .rejected(String(describing: error)) }
    }

    private var hasActiveWriteTransaction: Bool {
        transactions.values.contains { transaction in
            switch transaction.phase {
            case .created, .preparing, .resolving, .ready, .executing, .reconciling, .interrupted, .needsRecovery, .rollingBack:
                return true
            case .completed, .failed, .cancelled, .rolledBack, .needsReview:
                return false
            }
        }
    }

    private func restorePersistedTransactionsIfNeeded() async throws {
        guard !didRestorePersistedTransactions else { return }
        let journals = try await journalStore.loadAll()
        for journal in journals {
            if [TransactionPhase.completed, .failed, .cancelled].contains(journal.transaction.phase) {
                transactions[journal.transaction.id] = journal.transaction
                continue
            }
            let reconciled = try await TransactionReconciler().reconcile(journal, backend: backend)
            try await journalStore.save(reconciled)
            transactions[reconciled.transaction.id] = reconciled.transaction
        }
        didRestorePersistedTransactions = true
    }
}
