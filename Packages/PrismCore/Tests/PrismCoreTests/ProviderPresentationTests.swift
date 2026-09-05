import Foundation
import Testing
import PrismDomain
import PrismEnvironment
import PrismUIBridge

@Test func degradedProviderAppearsConciseInDailyPackageServiceStatus() {
    let env = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        runtimeVersion: "3.0",
        architecture: "arm64",
        osVersion: "26.6",
        capabilityReport: [.packageInstall: .available],
        compatibilityLayers: []
    )
    let diagnostics = ProviderDiagnosticsSnapshot(
        identity: .init(
            providerID: "dev.relaxin.package-service",
            providerKind: .packageService,
            providerVersion: "0.4.0",
            protocolVersion: "1"
        ),
        runtimeState: .init(
            health: .degraded("Runtime module restarting"),
            supportedFormats: [.relaxinPackage],
            supportedVersionSchemes: ["native"],
            recoveryStrategies: [.reconcile, .safeAbort],
            lastHealthChange: Date(timeIntervalSince1970: 1_700_000_000),
            diagnosticSummary: "Service reconnect in progress"
        )
    )

    let presentation = PrismEnvironmentPresentation.make(
        environment: env,
        mode: .modern,
        serviceStatus: .connected,
        serviceProvider: diagnostics.identity.providerID,
        providerDiagnostics: diagnostics
    )

    let packageService = try! #require(presentation.dailyRows.first { $0.title == "Package Service" })
    #expect(packageService.value == "Degraded")
    #expect(packageService.detail == "Runtime module restarting")
    #expect(presentation.dailyRows.count == 4)
}

@Test func advancedDiagnosticsExposeProviderIdentityFormatsRecoveryAndHealthWithoutPaths() {
    let env = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        runtimeVersion: "3.0",
        architecture: "arm64",
        osVersion: "26.6",
        capabilityReport: [.packageInstall: .available],
        compatibilityLayers: []
    )
    let diagnostics = ProviderDiagnosticsSnapshot(
        identity: .init(
            providerID: "dev.relaxin.package-service",
            providerKind: .packageService,
            providerVersion: "0.4.0",
            protocolVersion: "1"
        ),
        runtimeState: .init(
            health: .healthy,
            supportedFormats: [.relaxinPackage, .debianDeb],
            supportedVersionSchemes: ["native", "debian"],
            recoveryStrategies: [.reconcile, .rollback],
            lastHealthChange: Date(timeIntervalSince1970: 1_700_000_000),
            diagnosticSummary: "Healthy provider session"
        )
    )

    let presentation = PrismEnvironmentPresentation.make(
        environment: env,
        mode: .hybrid,
        serviceStatus: .connected,
        serviceProvider: diagnostics.identity.providerID,
        providerDiagnostics: diagnostics
    )

    let rows = Dictionary(uniqueKeysWithValues: presentation.advancedRows.map { ($0.title, $0.value) })
    #expect(rows["Provider ID"] == "dev.relaxin.package-service")
    #expect(rows["Provider Version"] == "0.4.0")
    #expect(rows["Protocol Version"] == "1")
    #expect(rows["Provider Health"] == "Healthy")
    #expect(rows["Supported Formats"]?.contains("dev.relaxin.package") == true)
    #expect(rows["Recovery"]?.contains("reconcile") == true)
    #expect(rows["Last Health Change"] != nil)
    #expect(rows["Diagnostic Summary"] == "Healthy provider session")
    let joined = presentation.advancedRows.flatMap { [$0.title, $0.value, $0.detail ?? ""] }.joined(separator: " ")
    #expect(!joined.contains("/var/jb"))
    #expect(!joined.contains("apt-get"))
}

@Test func dashboardUsesLiveProviderDiagnosticsInsteadOfRegistrationSnapshot() async {
    let env = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        runtimeVersion: "3.0",
        architecture: "arm64",
        capabilityReport: [.packageInstall: .available],
        compatibilityLayers: []
    )
    let faults = MockProviderFaultController()
    await faults.setMode(.degradedBeforeExecution)
    let service = MockPackageServiceProvider(environment: env, faultController: faults)
    let facade = PrismClientFacade(service: service)

    let dashboard = await facade.connectAndLoad()
    let serviceRow = try! #require(dashboard.environment.dailyRows.first { $0.title == "Package Service" })

    #expect(dashboard.serviceStatus == .connected)
    #expect(serviceRow.value == "Degraded")
    #expect(serviceRow.detail == "Simulated provider degradation")
    #expect(dashboard.environment.advancedRows.contains { $0.title == "Provider Health" && $0.value == "Degraded" })
}
