import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismUIBridge

private actor BridgeFixtureTransport: RelaxinRuntimeServiceTransport {
    let protocolVersion: String
    let environment = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        runtimeVersion: "3.0",
        architecture: "arm64",
        osVersion: "26.6",
        osBuild: "23G93",
        capabilityReport: [.packageInstall: .available, .transactionReconcile: .available]
    )

    init(protocolVersion: String) { self.protocolVersion = protocolVersion }

    func handshake(_ request: RelaxinBridgeHandshake) async throws -> RelaxinBridgeSession {
        .init(
            negotiatedProtocolVersion: protocolVersion,
            runtime: .init(
                runtimeIdentity: "dev.relaxin.runtime",
                runtimeVersion: "3.0",
                architecture: "arm64",
                socFamily: "A13",
                osVersion: "26.6",
                osBuild: "23G93",
                environmentState: "ready",
                compatibilityLayers: [],
                runtimeCapabilities: environment.capabilityReport
            ),
            service: .init(
                serviceIdentity: "dev.relaxin.package-service",
                serviceVersion: "3.0",
                protocolVersion: protocolVersion,
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

@Test func relaxinBridgeRejectsUnsupportedProtocolBeforeCreatingSession() async throws {
    let provider = RelaxinRuntimeProvider(transport: BridgeFixtureTransport(protocolVersion: "99"))
    await #expect(throws: BridgeError.unsupportedProtocol("99")) {
        try await provider.activate()
    }
    let state = await provider.providerRuntimeState()
    #expect(state.health == .unavailable("Unsupported bridge protocol"))
}

@Test func relaxinBridgePublishesRuntimeAndServiceDescriptorsAfterHandshake() async throws {
    let provider = RelaxinRuntimeProvider(transport: BridgeFixtureTransport(protocolVersion: "1"))
    try await provider.activate()

    let session = try await provider.bridgeSession()

    #expect(session.runtime.runtimeIdentity == "dev.relaxin.runtime")
    #expect(session.runtime.socFamily == "A13")
    #expect(session.service.supportedPackageFormats.contains(.relaxinPackage))
    #expect(session.service.recoveryStrategies == [.reconcile])
}
