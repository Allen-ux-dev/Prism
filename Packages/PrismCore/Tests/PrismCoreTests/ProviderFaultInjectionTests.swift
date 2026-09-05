import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismTransactions
@testable import PrismUIBridge

private func faultEnvironment() -> PrismEnvironment {
    PrismEnvironment(
        runtimeIdentity: "dev.prism.runtime.simulation",
        architecture: "arm64",
        capabilityReport: [
            .packageInstall: .available,
            .appInstall: .available,
            .appRegistration: .available,
            .appInjection: .available,
            .dylibInjection: .available,
            .transactionReconcile: .available,
            .transactionRollback: .available,
            .safeAbort: .available
        ]
    )
}

@Test func mockFaultFailBeforeExecutionDoesNotMutateBackend() async throws {
    let controller = MockProviderFaultController(mode: .failBeforeExecution)
    let backend = MockPackageExecutionBackend()
    let service = MockPackageServiceProvider(environment: faultEnvironment(), backend: backend, faultController: controller)
    let operation = TransactionOperation.installPackage(.init(packageIdentifier: "demo", version: .native("1")))

    let result = try await service.execute(.init(operations: [operation]))

    #expect(result.phase == .failed)
    #expect((try await backend.inspectPackageState()).installedVersions["demo"] == nil)
    #expect(await backend.executionCount(for: operation.stableID) == 0)
}

@Test func interruptedOperationReconcilesFromActualStateWithoutDuplicateExecution() async throws {
    let controller = MockProviderFaultController(mode: .reconcileAlreadyApplied)
    let backend = MockPackageExecutionBackend()
    let service = MockPackageServiceProvider(environment: faultEnvironment(), backend: backend, faultController: controller)
    let operation = TransactionOperation.installPackage(.init(packageIdentifier: "demo", version: .native("1")))

    let interrupted = try await service.execute(.init(operations: [operation]))
    #expect(interrupted.phase == .interrupted)
    let recovered = try await service.reconcile(interrupted.id)

    #expect(recovered.phase == .completed)
    #expect(await backend.executionCount(for: operation.stableID) == 1)
}

@Test func rollbackRestoresPreTransactionState() async throws {
    let controller = MockProviderFaultController(mode: .interruptAfterOperation(0))
    let backend = MockPackageExecutionBackend()
    let service = MockPackageServiceProvider(environment: faultEnvironment(), backend: backend, faultController: controller)
    let operation = TransactionOperation.installPackage(.init(packageIdentifier: "demo", version: .native("1")))
    let interrupted = try await service.execute(.init(operations: [operation]))
    #expect((try await backend.inspectPackageState()).installedVersions["demo"] != nil)

    await controller.setMode(.rollbackSucceeds)
    let rolledBack = try await service.rollback(interrupted.id)

    #expect(rolledBack.phase == .rolledBack)
    #expect((try await backend.inspectPackageState()).installedVersions["demo"] == nil)
}

@Test func rollbackFailureMovesTransactionToNeedsReview() async throws {
    let controller = MockProviderFaultController(mode: .interruptAfterOperation(0))
    let service = MockPackageServiceProvider(environment: faultEnvironment(), faultController: controller)
    let interrupted = try await service.execute(.init(operations: [
        .installPackage(.init(packageIdentifier: "demo", version: .native("1")))
    ]))

    await controller.setMode(.rollbackFails)
    let result = try await service.rollback(interrupted.id)

    #expect(result.phase == .needsReview)
}

@Test func degradedFaultIsVisibleThroughProviderRuntimeState() async throws {
    let controller = MockProviderFaultController(mode: .degradedBeforeExecution)
    let service = MockPackageServiceProvider(environment: faultEnvironment(), faultController: controller)
    let state = await service.providerRuntimeState()

    #expect(state.health == .degraded("Simulated provider degradation"))
}

@Test func appSimulationUsesSameFaultHarnessWithoutTouchingRealApps() async throws {
    let controller = MockProviderFaultController(mode: .interruptAfterOperation(0))
    let center = PrismAppSimulationCenter(faultController: controller)

    let result = try await center.simulateDemoInstall()
    let snapshot = try await center.snapshot()

    #expect(result.phase == .needsRecovery)
    #expect(snapshot.apps.map(\.id).contains("dev.prism.simulation.demo"))
}
