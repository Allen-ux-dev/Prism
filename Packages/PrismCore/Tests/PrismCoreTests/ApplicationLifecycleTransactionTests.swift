import Foundation
import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismTransactions

@Test func applicationLifecycleOperationsHaveStableDistinctIDs() {
    let op = AppInstallOperation(bundleIdentifier: "dev.demo.app", displayName: "Demo", version: "2.0")
    #expect(TransactionOperation.installApp(op).stableID == "app-install:dev.demo.app")
    #expect(TransactionOperation.replaceApp(op).stableID == "app-replace:dev.demo.app")
    #expect(TransactionOperation.removeApp("dev.demo.app").stableID == "app-remove:dev.demo.app")
    #expect(TransactionOperation.refreshApp("dev.demo.app").stableID == "app-refresh:dev.demo.app")
}

@Test func mockBackendExecutesReplaceRefreshAndRemoveApplicationLifecycle() async throws {
    let old = PrismInstalledApp(
        bundleIdentifier: "dev.demo.app", displayName: "Old", version: "1.0", architecture: "arm64",
        installationSource: .prism, registrationState: .registered
    )
    let injection = InjectionStateKey(bundleIdentifier: old.bundleIdentifier, artifactIdentifier: "demo.inject")
    let backend = MockPackageExecutionBackend(appState: .init(
        installedApps: [old.bundleIdentifier: old],
        registeredBundleIdentifiers: [old.bundleIdentifier],
        activeInjections: [injection]
    ))

    let replacement = AppInstallOperation(bundleIdentifier: old.bundleIdentifier, displayName: "New", version: "2.0")
    _ = try await backend.execute(.replaceApp(replacement))
    var state = try await backend.inspectApplicationState()
    #expect(state.installedApps[old.bundleIdentifier]?.version == "2.0")

    _ = try await backend.execute(.refreshApp(old.bundleIdentifier))
    state = try await backend.inspectApplicationState()
    #expect(state.registeredBundleIdentifiers.contains(old.bundleIdentifier))

    _ = try await backend.execute(.removeApp(old.bundleIdentifier))
    state = try await backend.inspectApplicationState()
    #expect(state.installedApps[old.bundleIdentifier] == nil)
    #expect(!state.registeredBundleIdentifiers.contains(old.bundleIdentifier))
    #expect(!state.activeInjections.contains(injection))
}

@Test func reconcilerVerifiesReplaceVersionAndRefreshRegistration() async throws {
    let replacement = AppInstallOperation(bundleIdentifier: "dev.demo.app", displayName: "Demo", version: "2.0")
    let tx = PrismTransaction(
        operations: [.replaceApp(replacement), .refreshApp(replacement.bundleIdentifier)],
        phase: .reconciling
    )
    let app = PrismInstalledApp(
        bundleIdentifier: replacement.bundleIdentifier, displayName: "Demo", version: "2.0", architecture: "arm64",
        installationSource: .prism, registrationState: .registered
    )
    let backend = MockPackageExecutionBackend(appState: .init(
        installedApps: [app.bundleIdentifier: app],
        registeredBundleIdentifiers: [app.bundleIdentifier]
    ))
    let journal = TransactionJournal(
        transaction: tx,
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init()
    )

    let reconciled = try await TransactionReconciler().reconcile(journal, backend: backend)
    #expect(reconciled.transaction.phase == .completed)
    #expect(reconciled.transaction.completedOperationIDs == Set(tx.operations.map(\.stableID)))
}

@Test func reconcilerDoesNotAcceptWrongReplacementVersion() async throws {
    let replacement = AppInstallOperation(bundleIdentifier: "dev.demo.app", displayName: "Demo", version: "2.0")
    let tx = PrismTransaction(operations: [.replaceApp(replacement)], phase: .reconciling)
    let old = PrismInstalledApp(bundleIdentifier: replacement.bundleIdentifier, displayName: "Demo", version: "1.0", architecture: "arm64")
    let backend = MockPackageExecutionBackend(appState: .init(installedApps: [old.bundleIdentifier: old]))
    let journal = TransactionJournal(
        transaction: tx,
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init(installedApps: [old.bundleIdentifier: old])
    )

    let reconciled = try await TransactionReconciler().reconcile(journal, backend: backend)
    #expect(reconciled.transaction.phase == .needsRecovery)
    #expect(reconciled.transaction.completedOperationIDs.isEmpty)
}
