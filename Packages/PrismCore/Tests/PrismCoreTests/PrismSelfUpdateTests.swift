import Foundation
import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismUIBridge

@Test func writeTransactionForcesPrismUpdateToWaitForSafePoint() async throws {
    let journal = TransactionJournal(
        transaction: PrismTransaction(operations: [.removePackage("demo")], phase: .executing),
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init(),
        providerIdentifier: "provider"
    )
    let runtime = RecordingUpdateRuntime()
    let coordinator = PrismUpdateCoordinator(runtime: runtime, journalSource: { [journal] })
    let state = await coordinator.requestActivation(.init(target: .prism, version: "0.4.1"))
    #expect(state == .waitingForSafePoint)
    #expect(await runtime.activationCount == 0)
}

@Test func activationFailureRollsBackPreviousPrismInstallation() async throws {
    let runtime = RecordingUpdateRuntime(failure: .activation)
    let coordinator = PrismUpdateCoordinator(runtime: runtime, journalSource: { [] })
    let state = await coordinator.requestActivation(.init(target: .prism, version: "0.4.1"))
    #expect(state == .rolledBack)
    #expect(await runtime.restoreCount == 1)
}

@Test func successfulUpdateCommitsOnlyAfterHandshakeAndHealthCheck() async throws {
    let runtime = RecordingUpdateRuntime()
    let coordinator = PrismUpdateCoordinator(runtime: runtime, journalSource: { [] })
    let state = await coordinator.requestActivation(.init(target: .prism, version: "0.4.1"))
    #expect(state == .committed)
    #expect(await runtime.handshakeCount == 1)
    #expect(await runtime.healthCount == 1)
}

private enum UpdateFailure { case activation, handshake, health }

private actor RecordingUpdateRuntime: PrismUpdateRuntimeAdapter {
    let failure: UpdateFailure?
    private(set) var activationCount = 0
    private(set) var restoreCount = 0
    private(set) var handshakeCount = 0
    private(set) var healthCount = 0
    init(failure: UpdateFailure? = nil) { self.failure = failure }
    func stage(_ candidate: PrismUpdateCandidate) async throws {}
    func snapshotCurrentInstallation(for target: PrismUpdateTarget) async throws -> PrismUpdateSnapshot {
        .init(installedVersion: "0.4.0", providerRegistrations: [])
    }
    func activate(_ candidate: PrismUpdateCandidate) async throws {
        activationCount += 1
        if failure == .activation { throw PackageServiceError.unavailable("activation") }
    }
    func verifyHandshake(for candidate: PrismUpdateCandidate) async throws {
        handshakeCount += 1
        if failure == .handshake { throw PackageServiceError.unavailable("handshake") }
    }
    func healthCheck(for candidate: PrismUpdateCandidate) async throws -> Bool {
        healthCount += 1
        return failure != .health
    }
    func restore(_ snapshot: PrismUpdateSnapshot, for target: PrismUpdateTarget) async throws { restoreCount += 1 }
}

@Test func runtimeManagedOwnershipPreventsIndependentPrismSelfReplacement() async throws {
    let runtime = RecordingUpdateRuntime()
    let coordinator = PrismUpdateCoordinator(
        runtime: runtime,
        journalSource: { [] },
        ownershipSource: { .runtimeManaged(runtimeID: "dev.relaxin.runtime") }
    )

    let state = await coordinator.requestActivation(.init(target: .prism, version: "0.4.1"))

    guard case .failed(let reason) = state else {
        Issue.record("Expected runtime ownership to reject independent Prism replacement")
        return
    }
    #expect(reason.contains("dev.relaxin.runtime"))
    #expect(await runtime.activationCount == 0)
}
