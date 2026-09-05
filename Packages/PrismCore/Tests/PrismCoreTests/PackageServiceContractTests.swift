import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismTransactions
@testable import PrismUIBridge

private func requireState<T: PackageStateService>(_ value: T) {}
private func requirePlanning<T: PackagePlanningService>(_ value: T) {}
private func requireExecution<T: PackageExecutionService>(_ value: T) {}
private func requireRecovery<T: PackageRecoveryService>(_ value: T) {}

@Test func aggregatePackageServiceConformsToAllServiceSlices() {
    let provider = MockPackageServiceProvider(
        environment: PrismEnvironment(runtimeIdentity: "mock", architecture: "arm64", capabilityReport: [.packageInstall: .available])
    )
    requireState(provider)
    requirePlanning(provider)
    requireExecution(provider)
    requireRecovery(provider)
}
