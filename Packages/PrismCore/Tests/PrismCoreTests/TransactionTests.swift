import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismTransactions

@Test func transactionStateMachineRejectsSkippingToExecution() {
    let tx = PrismTransaction(operations: [])
    #expect(throws: TransactionStateError.invalidTransition(from: .created, to: .executing)) { _ = try TransactionStateMachine().transition(tx, to: .executing) }
}

@Test func mockTransactionExecutesPackageExactlyOnce() async {
    let op = TransactionOperation.installPackage(.init(packageIdentifier: "demo", version: DebianVersion("1.0")))
    let backend = MockPackageExecutionBackend()
    let result = await TransactionExecutor().execute(PrismTransaction(operations: [op]), backend: backend)
    #expect(result.phase == .completed)
    #expect(await backend.executionCount(for: op.stableID) == 1)
    let snapshot = try! await backend.inspectPackageState()
    #expect(snapshot.installedVersions["demo"] == .debian("1.0"))
}
