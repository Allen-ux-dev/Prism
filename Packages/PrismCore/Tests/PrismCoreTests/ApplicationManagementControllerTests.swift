import Foundation
import Testing
@testable import PrismDomain
@testable import PrismPrivilegedProtocol
@testable import PrismTransactions
@testable import PrismUIBridge

private actor SubmittedTransactionRecorder {
    private(set) var transactions: [PrismTransaction] = []
    func record(_ transaction: PrismTransaction) { transactions.append(transaction) }
    func last() -> PrismTransaction? { transactions.last }
}

private func applicationStateFixture() -> ApplicationStateSnapshot {
    let app = PrismInstalledApp(
        bundleIdentifier: "dev.example.demo",
        displayName: "Demo",
        version: "2.0",
        architecture: "arm64",
        minimumOS: "15.0",
        installationSource: .prism,
        registrationState: .registered
    )
    return ApplicationStateSnapshot(
        installedApps: [app.bundleIdentifier: app],
        registeredBundleIdentifiers: [app.bundleIdentifier],
        activeInjections: [.init(bundleIdentifier: app.bundleIdentifier, artifactIdentifier: "plugin.demo")]
    )
}

private func applicationController(recorder: SubmittedTransactionRecorder) -> ApplicationManagementController {
    let state = applicationStateFixture()
    let transport = InMemoryPrivilegedTransport { request in
        switch request {
        case .handshake:
            return .hello(.init(serviceVersion: "test"))
        case .queryApplicationState:
            return .applicationState(state)
        case .submitTransaction(let transaction):
            await recorder.record(transaction)
            var completed = transaction
            completed.phase = .completed
            completed.completedOperationIDs = Set(transaction.operations.map(\.stableID))
            return .transaction(completed)
        default:
            return .rejected("unexpected")
        }
    }
    return ApplicationManagementController(
        session: PrivilegedSessionManager(transport: transport, clientIdentifier: "tests")
    )
}

@Test func applicationManagementSnapshotMapsRegistrationArchitectureSourceAndInjectionCount() async throws {
    let controller = applicationController(recorder: SubmittedTransactionRecorder())
    let snapshot = try await controller.snapshot()

    #expect(snapshot.apps.count == 1)
    #expect(snapshot.apps[0].id == "dev.example.demo")
    #expect(snapshot.apps[0].architecture == "arm64")
    #expect(snapshot.apps[0].registrationState == "Registered")
    #expect(snapshot.apps[0].installationSource == "Prism")
    #expect(snapshot.apps[0].injectionCount == 1)
}

@Test func applicationManagementRegisterSubmitsTypedTransaction() async throws {
    let recorder = SubmittedTransactionRecorder()
    let controller = applicationController(recorder: recorder)
    let result = try await controller.register(bundleIdentifier: "dev.example.demo")
    let submitted = await recorder.last()

    #expect(submitted?.operations == [.registerApp("dev.example.demo")])
    #expect(result.transaction.phase == "completed")
    #expect(result.apps.count == 1)
}

@Test func applicationManagementRefreshSubmitsTypedRepairTransaction() async throws {
    let recorder = SubmittedTransactionRecorder()
    let controller = applicationController(recorder: recorder)
    _ = try await controller.refresh(bundleIdentifier: "dev.example.demo")
    let submitted = await recorder.last()

    #expect(submitted?.operations == [.refreshApp("dev.example.demo")])
}

@Test func applicationManagementRemoveSubmitsTypedRemovalTransaction() async throws {
    let recorder = SubmittedTransactionRecorder()
    let controller = applicationController(recorder: recorder)
    _ = try await controller.remove(bundleIdentifier: "dev.example.demo")
    let submitted = await recorder.last()

    #expect(submitted?.operations == [.removeApp("dev.example.demo")])
}

@Test func applicationManagementRejectedResponseIsNotReportedAsSuccess() async throws {
    let transport = InMemoryPrivilegedTransport { request in
        switch request {
        case .handshake: return .hello(.init(serviceVersion: "test"))
        case .submitTransaction: return .rejected("runtime unavailable")
        default: return .rejected("unexpected")
        }
    }
    let controller = ApplicationManagementController(
        session: PrivilegedSessionManager(transport: transport, clientIdentifier: "tests")
    )

    await #expect(throws: ApplicationManagementControllerError.rejected("runtime unavailable")) {
        _ = try await controller.refresh(bundleIdentifier: "dev.example.demo")
    }
}
