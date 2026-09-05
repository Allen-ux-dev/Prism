import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismUIBridge

@Test func providerUpdateWaitsWhileTransactionIsPinnedToProvider() async throws {
    let identity = ProviderIdentity(providerID: "provider", providerKind: .packageService, providerVersion: "1", protocolVersion: "1")
    let journal = TransactionJournal(
        transaction: PrismTransaction(operations: [.removePackage("demo")], phase: .needsRecovery),
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init(),
        providerIdentifier: "provider",
        providerVersion: "1",
        providerProtocolVersion: "1"
    )
    let runtime = ProviderUpdateRuntimeFixture()
    let coordinator = PrismUpdateCoordinator(runtime: runtime, journalSource: { [journal] })
    let state = await coordinator.requestActivation(.init(target: .provider(identity), version: "2"))
    #expect(state == .waitingForSafePoint)
}

private actor ProviderUpdateRuntimeFixture: PrismUpdateRuntimeAdapter {
    func stage(_ candidate: PrismUpdateCandidate) async throws {}
    func snapshotCurrentInstallation(for target: PrismUpdateTarget) async throws -> PrismUpdateSnapshot { .init(installedVersion: "1", providerRegistrations: []) }
    func activate(_ candidate: PrismUpdateCandidate) async throws {}
    func verifyHandshake(for candidate: PrismUpdateCandidate) async throws {}
    func healthCheck(for candidate: PrismUpdateCandidate) async throws -> Bool { true }
    func restore(_ snapshot: PrismUpdateSnapshot, for target: PrismUpdateTarget) async throws {}
}
