import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismUIBridge

@Test func mockTrollStoreStyleFlowUsesPlanTransactionJournalAndReconcile() async throws {
    let environment = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime", architecture: "arm64",
        capabilityReport: [.appInstall: .available, .appRegistration: .available, .transactionReconcile: .available]
    )
    let installer = MockTrollStoreStyleProvider()
    let ipa = IPAInspectionSnapshot(bundleIdentifier: "dev.demo.app", displayName: "Demo", version: "1.0", architectures: ["arm64"])
    let plan = installer.plan(ipa: ipa, environment: environment)
    #expect(plan.isExecutable)

    let service = MockPackageServiceProvider(environment: environment)
    try await service.activate()
    let tx = installer.transaction(for: plan)
    let completed = try await service.execute(tx)
    #expect(completed.phase == .completed)
    let state = try await service.inspectApplicationState()
    #expect(state.installedApps["dev.demo.app"] != nil)
    #expect(state.registeredBundleIdentifiers.contains("dev.demo.app"))
    let reconciled = try await service.reconcile(completed.id)
    #expect(reconciled.phase == .completed)
}

@Test func mockTrollFoolsStyleFlowIsTypedAndReversible() async throws {
    let environment = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime", architecture: "arm64",
        capabilityReport: [.appInjection: .available, .dylibInjection: .available, .transactionReconcile: .available]
    )
    let target = PrismInstalledApp(bundleIdentifier: "dev.demo.app", displayName: "Demo", version: "1", architecture: "arm64")
    let artifact = InjectionArtifact(identifier: "dev.demo.tweak", displayName: "Demo Tweak", kind: .dylib, supportedArchitectures: ["arm64"])
    let provider = MockTrollFoolsStyleProvider()
    let plan = provider.plan(target: target, artifact: artifact, environment: environment)
    #expect(plan.isExecutable)

    let backend = MockPackageExecutionBackend(appState: .init(installedApps: [target.bundleIdentifier: target]))
    let service = MockPackageServiceProvider(environment: environment, backend: backend)
    let applied = try await service.execute(provider.applyTransaction(for: plan))
    #expect(applied.phase == .completed)
    #expect((try await service.inspectApplicationState()).activeInjections.contains(.init(bundleIdentifier: target.bundleIdentifier, artifactIdentifier: artifact.identifier)))

    let removed = try await service.execute(provider.removeTransaction(target: target, artifact: artifact))
    #expect(removed.phase == .completed)
    #expect(!(try await service.inspectApplicationState()).activeInjections.contains(.init(bundleIdentifier: target.bundleIdentifier, artifactIdentifier: artifact.identifier)))
}

@Test func simulationCenterRunsInstallInjectionAndRemovalThroughTransactions() async throws {
    let center = PrismAppSimulationCenter()
    let ipa = IPAInspectionSnapshot(
        bundleIdentifier: "dev.prism.simulation.demo",
        displayName: "Prism Demo App",
        version: "1.0",
        architectures: ["arm64"]
    )
    _ = try await center.simulateInstall(ipa)
    var snapshot = try await center.snapshot()
    #expect(snapshot.apps.count == 1)
    #expect(snapshot.apps[0].injectionCount == 0)
    #expect(snapshot.transactions.count == 1)

    let artifact = InjectionArtifact(
        identifier: "dev.prism.simulation.tweak",
        displayName: "Prism Demo Tweak",
        kind: .dylib,
        supportedArchitectures: ["arm64"]
    )
    _ = try await center.simulateInjection(targetBundleIdentifier: ipa.bundleIdentifier, artifact: artifact)
    snapshot = try await center.snapshot()
    #expect(snapshot.apps[0].injectionCount == 1)
    #expect(snapshot.transactions.count == 2)

    _ = try await center.simulateRemoveInjection(targetBundleIdentifier: ipa.bundleIdentifier, artifact: artifact)
    snapshot = try await center.snapshot()
    #expect(snapshot.apps[0].injectionCount == 0)
    #expect(snapshot.transactions.count == 3)
}

@Test func mockApplicationInstallTransactionCarriesInspectedVersion() {
    let environment = PrismEnvironment(
        runtimeIdentity: "dev.runtime.fixture", architecture: "arm64",
        capabilityReport: [.appInstall: .available, .appRegistration: .available]
    )
    let ipa = IPAInspectionSnapshot(
        bundleIdentifier: "dev.demo.versioned", displayName: "Versioned", version: "2.5",
        architectures: ["arm64"]
    )
    let provider = MockTrollStoreStyleProvider()
    let tx = provider.transaction(for: provider.plan(ipa: ipa, environment: environment))
    guard case .installApp(let operation) = tx.operations.first else {
        Issue.record("Expected install operation")
        return
    }
    #expect(operation.version == "2.5")
}
