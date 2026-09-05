import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismUIBridge

@Test func runtimeHandshakeIgnoresUnknownCapabilityAndPreservesUnknownOptionalFeature() throws {
    let json = #"{"protocolVersion":2,"minimumCompatibleVersion":1,"runtimeIdentity":"dev.relaxin.runtime","runtimeVersion":"4","prismVersion":"0.4.1","packageServiceVersion":1,"capabilities":{"packageService":"available","futureCapability":"available"},"optionalFeatures":["future-feature"]}"#.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(RuntimeHandshake.self, from: json)

    #expect(decoded.capabilities[.packageService] == .available)
    #expect(decoded.capabilities.count == 1)
    #expect(decoded.optionalFeatures.contains("future-feature"))
}

@Test func relaxinBridgeDegradedPackageServiceMakesProviderDegraded() async throws {
    let transport = ConformanceRelaxinTransport(packageInstall: .degraded("service warming up"))
    let provider = RelaxinRuntimeProvider(transport: transport)
    try await provider.activate()

    let state = await provider.providerRuntimeState()
    #expect(state.health == .degraded("service warming up"))
}

@Test func relaxinBridgeUnavailablePackageServiceMakesProviderUnavailable() async throws {
    let transport = ConformanceRelaxinTransport(packageInstall: .unavailable)
    let provider = RelaxinRuntimeProvider(transport: transport)
    try await provider.activate()

    let state = await provider.providerRuntimeState()
    #expect(state.health == .unavailable("Package service unavailable"))
}

@Test func relaxinRuntimeDisconnectInvalidatesSessionAndHealth() async throws {
    let provider = RelaxinRuntimeProvider(transport: ConformanceRelaxinTransport(packageInstall: .available))
    try await provider.activate()
    await provider.deactivate()

    do {
        _ = try await provider.bridgeSession()
        Issue.record("Expected bridge session to be unavailable after disconnect")
    } catch let error as BridgeError {
        #expect(error == .sessionUnavailable)
    }
    let state = await provider.providerRuntimeState()
    #expect(!state.health.isUsable)
}

private actor ConformanceRelaxinTransport: RelaxinRuntimeServiceTransport {
    let packageInstall: CapabilityStatus
    init(packageInstall: CapabilityStatus) { self.packageInstall = packageInstall }

    private var environment: PrismEnvironment {
        PrismEnvironment(
            runtimeIdentity: "dev.relaxin.runtime",
            runtimeVersion: "4.0",
            architecture: "arm64",
            osVersion: "26.6",
            capabilityReport: [.packageInstall: packageInstall, .transactionReconcile: .available]
        )
    }

    func handshake(_ request: RelaxinBridgeHandshake) async throws -> RelaxinBridgeSession {
        .init(
            negotiatedProtocolVersion: "1",
            runtime: .init(
                runtimeIdentity: "dev.relaxin.runtime",
                runtimeVersion: "4.0",
                architecture: "arm64",
                socFamily: "A13",
                osVersion: "26.6",
                environmentState: "ready",
                runtimeCapabilities: environment.capabilityReport
            ),
            service: .init(
                serviceIdentity: "dev.relaxin.package-service",
                serviceVersion: "4.0",
                protocolVersion: "1",
                capabilityReport: environment.capabilityReport,
                supportedPackageFormats: [.relaxinPackage],
                supportedVersionSchemes: ["native"],
                recoveryStrategies: [.reconcile],
                sessionBehavior: .persistent
            )
        )
    }
    func activate() async throws {}
    func deactivate() async {}
    func queryEnvironment() async throws -> PrismEnvironment { environment }
    func inspectPackageState() async throws -> PackageStateSnapshot { .init(installedVersions: [:]) }
    func inspectApplicationState() async throws -> ApplicationStateSnapshot { .init() }
    func queryTransactions() async throws -> [PrismTransaction] { [] }
    func execute(_ transaction: PrismTransaction) async throws -> PrismTransaction { transaction }
    func reconcile(_ transactionID: UUID) async throws -> PrismTransaction { throw PackageServiceError.transactionNotFound(transactionID) }
    func syncRepositorySources(_ sources: [URL]) async throws {}
}
