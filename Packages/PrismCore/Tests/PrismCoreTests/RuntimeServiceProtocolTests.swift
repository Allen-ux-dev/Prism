import Foundation
import Testing
@testable import PrismDomain
@testable import PrismTransactions
@testable import PrismPrivilegedProtocol

@Test func runtimeServiceHandshakePreservesUnknownCapabilityIdentifiers() throws {
    let future = CapabilityIdentifier(rawValue: "future.vendor.capability.magic")
    let hello = RuntimeServiceHello(
        runtimeIdentity: "runtime.test",
        displayName: "Test Runtime",
        serviceVersion: "1.0",
        selectedProtocolVersion: 1,
        providerKind: .native,
        capabilityStates: [
            .appInstall: .init(identifier: .appInstall, availability: .available, version: 1),
            future: .init(identifier: future, availability: .available, version: 7)
        ],
        health: .healthy
    )
    let data = try JSONEncoder().encode(hello)
    let decoded = try JSONDecoder().decode(RuntimeServiceHello.self, from: data)
    #expect(decoded.capabilityStates[future]?.version == 7)
    #expect(decoded.capabilityStates[future]?.availability == .available)
}

@Test func runtimeServiceHandshakeNegotiatesVersionRange() {
    let request = RuntimeServiceHelloRequest(clientIdentifier: "dev.allenux.prism", supportedProtocolVersions: [1, 2])
    #expect(request.supportedProtocolVersions == [1, 2])
}

@Test func runtimeBackgroundSessionStateRoundTrips() throws {
    let state = RuntimeBackgroundSessionState.active
    let data = try JSONEncoder().encode(state)
    #expect(try JSONDecoder().decode(RuntimeBackgroundSessionState.self, from: data) == .active)
}

@Test func privilegedServiceCapabilityNamespaceIsStable() {
    #expect(CapabilityIdentifier.privilegedService.rawValue == "dev.prism.capability.privileged-service")
}

@Test func legacyAppInstallOperationWithoutArtifactStillDecodes() throws {
    let json = #"{"bundleIdentifier":"dev.example.app","displayName":"Example","version":"1.0"}"#.data(using: .utf8)!
    let operation = try JSONDecoder().decode(AppInstallOperation.self, from: json)
    #expect(operation.bundleIdentifier == "dev.example.app")
    #expect(operation.artifact == nil)
}

@Test func appArtifactReferenceRoundTripsOpaqueIdentifierAndDigest() throws {
    let reference = AppArtifactReference(stagingIdentifier: "stage-123", sha256: "abc123")
    let operation = AppInstallOperation(bundleIdentifier: "dev.example.app", displayName: "Example", version: "1.0", artifact: reference)
    let data = try JSONEncoder().encode(operation)
    let decoded = try JSONDecoder().decode(AppInstallOperation.self, from: data)
    #expect(decoded.artifact == reference)
}
