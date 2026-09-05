import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismUIBridge

private func conformanceEnvironment() -> PrismEnvironment {
    PrismEnvironment(
        runtimeIdentity: "dev.prism.runtime.conformance",
        architecture: "arm64",
        capabilityReport: [
            .packageInstall: .available,
            .packageRemove: .available,
            .packageUpgrade: .available,
            .transactionReconcile: .available,
            .transactionRollback: .available,
            .safeAbort: .available
        ]
    )
}

@Test func writeProviderConformanceCoversStatePlanPrepareAndExecute() async throws {
    let service = MockPackageServiceProvider(environment: conformanceEnvironment())
    try await service.activate()
    #expect((try await service.queryCapabilities())[.packageInstall] == .available)
    #expect((try await service.inspectPackageState()).installedVersions.isEmpty)

    let package = PrismPackage(
        identifier: "demo",
        name: "Demo",
        version: .native("1.0"),
        architecture: "arm64",
        description: "Conformance package",
        requirements: [.init(identifier: "packageInstall")],
        distribution: .prismNative
    )
    let catalog = PackageCatalogSnapshot(packages: [package])
    let installed = PackageStateSnapshot(installedVersions: [:])
    let environment = try await service.queryEnvironment()
    let plan = try await service.resolve(
        request: .init(packageIDs: ["demo"]), catalog: catalog, installed: installed, environment: environment
    )
    let preparation = try await service.prepare(plan)
    #expect(preparation.providerIdentifier == service.descriptor.identifier)

    let result = try await service.execute(PrismTransaction.from(installPlan: plan))
    #expect(result.phase == TransactionPhase.completed)
    #expect((try await service.inspectPackageState()).installedVersions["demo"] == .native("1.0"))
    #expect((try await service.queryTransactions()).contains { $0.id == result.id })
}

@Test func writeProviderConformanceCoversInterruptReconcileRollbackAndSafeAbort() async throws {
    let controller = MockProviderFaultController(mode: .reconcileAlreadyApplied)
    let backend = MockPackageExecutionBackend()
    let journals = InMemoryTransactionJournalStore()
    let service = MockPackageServiceProvider(
        environment: conformanceEnvironment(), backend: backend, journalStore: journals, faultController: controller
    )
    let operation = TransactionOperation.installPackage(.init(packageIdentifier: "demo", version: .native("1")))

    let interrupted = try await service.execute(.init(operations: [operation]))
    #expect(interrupted.phase == .interrupted)
    let reconciled = try await service.reconcile(interrupted.id)
    #expect(reconciled.phase == .completed)

    await controller.setMode(.interruptAfterOperation(0))
    let second = try await service.execute(.init(operations: [
        .installPackage(.init(packageIdentifier: "rollback-demo", version: .native("1")))
    ]))
    await controller.setMode(.rollbackSucceeds)
    #expect((try await service.rollback(second.id)).phase == .rolledBack)

    await controller.setMode(.degradedBeforeExecution)
    let third = try await service.execute(.init(operations: [
        .installPackage(.init(packageIdentifier: "abort-demo", version: .native("1")))
    ]))
    await controller.setMode(.safeAbortSucceeds)
    #expect((try await service.safeAbort(third.id)).phase == .cancelled)
}

@Test func providerReconnectReusesJournalAndReconcilesWithoutDuplicateExecution() async throws {
    let controller = MockProviderFaultController(mode: .reconcileAlreadyApplied)
    let backend = MockPackageExecutionBackend()
    let journals = InMemoryTransactionJournalStore()
    let first = MockPackageServiceProvider(
        environment: conformanceEnvironment(), backend: backend, journalStore: journals, faultController: controller
    )
    let operation = TransactionOperation.installPackage(.init(packageIdentifier: "demo", version: .native("1")))
    let interrupted = try await first.execute(.init(operations: [operation]))
    #expect(await backend.executionCount(for: operation.stableID) == 1)

    let reconnected = MockPackageServiceProvider(
        environment: conformanceEnvironment(), backend: backend, journalStore: journals, faultController: .init()
    )
    let recovered = try await reconnected.reconcile(interrupted.id)

    #expect(recovered.phase == .completed)
    #expect(await backend.executionCount(for: operation.stableID) == 1)
}
