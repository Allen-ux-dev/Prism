import Testing
@testable import PrismDomain

@Test func integrationStateRepresentsRepairingRecoveringAndIncompatible() {
    #expect(PrismIntegrationState.repairing != .ready)
    #expect(PrismIntegrationState.recovering != .ready)
    #expect(PrismIntegrationState.incompatible(reason: "protocol") != .ready)
}

@Test func runtimeIntegrationCapabilitiesRemainImplementationAgnostic() {
    let expected: Set<RuntimeIntegrationCapability> = [
        .packageService, .backgroundExecution, .serviceRegistration, .lifecycleRecovery,
        .packageStoreAccess, .repositoryNetworking, .userspaceRestart, .appRegistration, .runtimeDiagnostics
    ]
    #expect(Set(RuntimeIntegrationCapability.allCases) == expected)
}

@Test func packageServiceLifecycleReturnsToIdleAfterFinishing() {
    #expect(PackageServiceLifecycleState.finishing != .active)
    #expect(PackageServiceLifecycleState.idle != .active)
}
