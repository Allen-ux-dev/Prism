import Foundation
import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismTransactions

@Test func reconciliationDoesNotRepeatAlreadyAppliedOperation() async throws {
    let op = TransactionOperation.installPackage(.init(packageIdentifier: "demo", version: DebianVersion("1.0")))
    let backend = MockPackageExecutionBackend()
    _ = try await backend.execute(op)
    var tx = PrismTransaction(operations: [op]); tx.phase = .executing
    let journal = TransactionJournal(transaction: tx, stateBeforePackages: .init(installedVersions: [:]), stateBeforeApplications: .init())
    let reconciled = try await TransactionReconciler().reconcile(journal, backend: backend)
    #expect(reconciled.transaction.phase == .completed)
    #expect(await backend.executionCount(for: op.stableID) == 1)
}

@Test func atomicJournalRoundTrips() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = AtomicJSONTransactionJournalStore(directory: dir)
    let tx = PrismTransaction(operations: [])
    let journal = TransactionJournal(transaction: tx, stateBeforePackages: .init(installedVersions: [:]), stateBeforeApplications: .init())
    try await store.save(journal)
    #expect(try await store.load(id: tx.id) == journal)
    try? FileManager.default.removeItem(at: dir)
}
