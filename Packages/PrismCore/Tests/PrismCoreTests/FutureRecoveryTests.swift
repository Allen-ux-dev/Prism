import Foundation
import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismTransactions

@Test func recoveryNeverSilentlyMigratesProviderMidTransaction() async throws {
    let operation = TransactionOperation.installPackage(.init(packageIdentifier: "demo", version: .native("1")))
    var tx = PrismTransaction(operations: [operation])
    tx.phase = .interrupted
    let journal = TransactionJournal(
        transaction: tx,
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init(),
        providerIdentifier: "provider-a",
        providerVersion: "1.0"
    )
    let backend = MockPackageExecutionBackend()
    let recovered = try await TransactionReconciler().reconcile(journal, backend: backend, activeProviderIdentifier: "provider-b")
    #expect(recovered.transaction.phase == .needsReview)
    #expect(await backend.executionCount(for: operation.stableID) == 0)
}

@Test func transactionStateMachineSupportsRollbackLifecycle() throws {
    var tx = PrismTransaction(operations: [])
    tx.phase = .needsRecovery
    let rolling = try TransactionStateMachine().transition(tx, to: .rollingBack)
    let rolled = try TransactionStateMachine().transition(rolling, to: .rolledBack)
    #expect(rolled.phase == .rolledBack)
}

@Test func providerRecoveryTokenRemainsOpaqueInJournal() throws {
    let journal = TransactionJournal(
        transaction: .init(operations: []),
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init(),
        providerIdentifier: "modern",
        providerVersion: "2",
        providerRecoveryToken: "opaque-provider-token"
    )
    let data = try JSONEncoder().encode(journal)
    let decoded = try JSONDecoder().decode(TransactionJournal.self, from: data)
    #expect(decoded.providerRecoveryToken == "opaque-provider-token")
}
