import Testing
@testable import PrismDomain
@testable import PrismUIBridge

@Test func overlappingProtocolRangesNegotiateHighestCommonVersion() throws {
    let result = try RuntimeProtocolNegotiator.negotiate(runtime: 3...5, prism: 2...4)
    #expect(result == 4)
}

@Test func incompatibleProtocolRangeFailsWithoutFallback() {
    #expect(throws: RuntimeProtocolNegotiationError.self) {
        try RuntimeProtocolNegotiator.negotiate(runtime: 5...5, prism: 2...4)
    }
}

@Test func coreContractVersionsAreExplicitAndPositive() {
    #expect(PrismContractVersions.runtimeIntegration.current > 0)
    #expect(PrismContractVersions.packageService.current > 0)
    #expect(PrismContractVersions.repositoryProvider.current > 0)
    #expect(PrismContractVersions.transactionJournalSchema > 0)
    #expect(PrismContractVersions.environmentSchema > 0)
    #expect(PrismContractVersions.capabilitySchema > 0)
    #expect(PrismContractVersions.providerStateSchema > 0)
}

@Test func runtimeHandshakeCarriesCapabilitiesAndUnknownOptionalFeatures() {
    let handshake = RuntimeHandshake(
        protocolVersion: 3,
        minimumCompatibleVersion: 2,
        runtimeIdentity: "dev.relaxin.runtime",
        runtimeVersion: "2.0",
        prismVersion: "0.4.1",
        packageServiceVersion: 1,
        capabilities: [.packageService: .available],
        optionalFeatures: ["future-feature"]
    )
    #expect(handshake.optionalFeatures.contains("future-feature"))
}
