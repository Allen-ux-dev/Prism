import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismUIBridge

@Test func modernPackageServiceWorksWithoutDaemonTransport() async throws {
    let environment = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime", runtimeVersion: "2.0", architecture: "arm64",
        capabilityReport: [.packageInstall: .available, .transactionReconcile: .available, .safeAbort: .available]
    )
    let transport = FixtureRelaxinRuntimeTransport(environment: environment)
    let provider = RelaxinRuntimeProvider(transport: transport)

    try await provider.activate()
    #expect((try await provider.queryEnvironment()).runtimeIdentity == "dev.relaxin.runtime")
    #expect((try await provider.queryCapabilities())[.packageInstall] == .available)

    let tx = PrismTransaction(operations: [.installPackage(.init(packageIdentifier: "demo", version: .native("1.0")))])
    let result = try await provider.execute(tx)
    #expect(result.phase == .completed)
}

@Test func facadeCanUseInjectedPackageServiceInsteadOfPrismd() async throws {
    let environment = PrismEnvironment(runtimeIdentity: "mock-modern", architecture: "arm64", capabilityReport: [.packageInstall: .available, .transactionReconcile: .available])
    let service = MockPackageServiceProvider(environment: environment)
    let facade = PrismClientFacade(service: service)
    let snapshot = await facade.connectAndLoad()
    #expect(snapshot.serviceStatus == .connected)
    #expect(snapshot.environment.runtime == "mock-modern")
}

private actor FixtureRelaxinRuntimeTransport: RelaxinRuntimeServiceTransport {
    let environment: PrismEnvironment
    var packageState = PackageStateSnapshot(installedVersions: [:])
    var transactions: [UUID: PrismTransaction] = [:]
    init(environment: PrismEnvironment) { self.environment = environment }
    func handshake(_ request: RelaxinBridgeHandshake) async throws -> RelaxinBridgeSession {
        .init(
            negotiatedProtocolVersion: "1",
            runtime: .init(
                runtimeIdentity: environment.runtimeIdentity,
                runtimeVersion: environment.runtimeVersion,
                architecture: environment.architecture,
                osVersion: environment.osVersion,
                osBuild: environment.osBuild,
                environmentState: "ready",
                compatibilityLayers: environment.compatibilityLayers,
                runtimeCapabilities: environment.capabilityReport
            ),
            service: .init(
                serviceIdentity: "dev.relaxin.package-service",
                serviceVersion: "1.0",
                protocolVersion: "1",
                capabilityReport: environment.capabilityReport,
                supportedPackageFormats: [.relaxinPackage, .prismNative, .prismSource],
                supportedVersionSchemes: ["native"],
                recoveryStrategies: [.reconcile],
                sessionBehavior: .persistent
            )
        )
    }
    func activate() async throws {}
    func deactivate() async {}
    func queryEnvironment() async throws -> PrismEnvironment { environment }
    func inspectPackageState() async throws -> PackageStateSnapshot { packageState }
    func inspectApplicationState() async throws -> ApplicationStateSnapshot { .init() }
    func queryTransactions() async throws -> [PrismTransaction] { Array(transactions.values) }
    func execute(_ transaction: PrismTransaction) async throws -> PrismTransaction {
        var copy = transaction; copy.phase = .completed; transactions[copy.id] = copy; return copy
    }
    func reconcile(_ transactionID: UUID) async throws -> PrismTransaction {
        guard let tx = transactions[transactionID] else { throw PackageServiceError.transactionNotFound(transactionID) }
        return tx
    }
    func syncRepositorySources(_ sources: [URL]) async throws {}
}

@Test func facadePreviewsAndExecutesCompletePackageRemoval() async throws {
    let environment = PrismEnvironment(
        providerIdentifier: "fixture",
        bootstrapIdentifier: nil,
        rootStyle: .rootless,
        rootPrefix: URL(fileURLWithPath: "/fixture"),
        architecture: "arm64",
        capabilities: [.packageRemove, .apt, .dpkg, .transactionReconcile]
    )
    let backend = MockPackageExecutionBackend(packageState: .init(installedVersions: ["plugin.demo": .debian("1.0")]))
    let service = MockPackageServiceProvider(environment: environment, backend: backend)
    let facade = PrismClientFacade(service: service)
    _ = await facade.connectAndLoad()

    let review = try await facade.prepareRemoval(packageID: "plugin.demo", mode: .purge)
    #expect(review.mode == .purge)
    #expect(review.removesConfiguration)
    let row = try await facade.confirmRemoval(reviewID: review.id)
    #expect(row.phase == TransactionPhase.completed.rawValue)
    #expect((try await service.inspectPackageState()).installedVersions["plugin.demo"] == nil)
}
