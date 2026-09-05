import Testing
@testable import PrismDomain

private struct UnsafeWriteProvider: PrismProvider {
    let descriptor = PrismProviderDescriptor(
        identifier: "unsafe-write",
        kind: .packageService,
        version: "1",
        priority: 100,
        operatingModes: [.modern],
        supportedRequirements: ["packageInstall"],
        supportedFormats: [.relaxinPackage],
        health: .healthy
    )
}

private struct SafeWriteProvider: PrismProvider {
    let descriptor = PrismProviderDescriptor(
        identifier: "safe-write",
        kind: .packageService,
        version: "1",
        priority: 10,
        operatingModes: [.modern],
        supportedRequirements: ["packageInstall"],
        supportedFormats: [.relaxinPackage],
        recoveryStrategies: [.reconcile],
        health: .healthy
    )
}

@Test func writeProviderWithoutRecoveryStrategyIsUnavailableForWriteSelection() async throws {
    let registry = ProviderRegistry()
    await registry.register(UnsafeWriteProvider())

    await #expect(throws: ProviderRegistryError.missingRecoveryStrategy("unsafe-write")) {
        _ = try await registry.select(
            kind: .packageService,
            context: .init(
                mode: .modern,
                requiredRequirements: ["packageInstall"],
                requiredFormats: [.relaxinPackage]
            )
        )
    }
}

@Test func writeProviderWithRecoveryStrategyRemainsSelectable() async throws {
    let registry = ProviderRegistry()
    await registry.register(SafeWriteProvider())

    let selected = try await registry.select(
        kind: .packageService,
        context: .init(
            mode: .modern,
            requiredRequirements: ["packageInstall"],
            requiredFormats: [.relaxinPackage]
        )
    )

    #expect(selected.identifier == "safe-write")
    #expect(selected.recoveryStrategies == [.reconcile])
}
