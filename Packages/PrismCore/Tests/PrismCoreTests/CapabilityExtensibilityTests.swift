import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismUIBridge

@Test func unknownCapabilityRoundTripsWithoutCoreKnowledge() throws {
    let future = CapabilityIdentifier(rawValue: "future.vendor.capability.quantum-package-service")
    let handshake = RuntimeHandshake(
        protocolVersion: 2,
        minimumCompatibleVersion: 1,
        runtimeIdentity: "future.runtime",
        runtimeVersion: "9.0",
        prismVersion: "0.4.2",
        packageServiceVersion: 2,
        capabilityStates: [
            future: CapabilityState(identifier: future, availability: .available, version: 7, metadata: ["transport": "future"])
        ]
    )

    let data = try JSONEncoder().encode(handshake)
    let decoded = try JSONDecoder().decode(RuntimeHandshake.self, from: data)

    #expect(decoded.capabilityStates[future]?.availability == .available)
    #expect(decoded.capabilityStates[future]?.version == 7)
    #expect(decoded.capabilityStates[future]?.metadata["transport"] == "future")
}

@Test func unknownOptionalCapabilityDoesNotMakeProfileIncompatible() {
    let future = CapabilityIdentifier(rawValue: "future.vendor.capability.optional-ui")
    let states: [CapabilityIdentifier: CapabilityState] = [:]
    let requirements = [CapabilityRequirement(identifier: future, required: false)]

    let evaluation = CapabilityRequirementEvaluator.evaluate(requirements, against: states)

    #expect(evaluation.isCompatible)
    #expect(evaluation.missingRequired.isEmpty)
    #expect(evaluation.missingOptional == [future])
}

@Test func unknownRequiredCapabilityBecomesExplicitIncompatibility() {
    let future = CapabilityIdentifier(rawValue: "future.vendor.capability.required-store")
    let requirements = [CapabilityRequirement(identifier: future, minimumVersion: 2, required: true)]

    let evaluation = CapabilityRequirementEvaluator.evaluate(requirements, against: [:])

    #expect(!evaluation.isCompatible)
    #expect(evaluation.missingRequired == [future])
}

@Test func legacyRuntimeCapabilitiesMigrateToOpenIdentifiers() {
    let converted = LegacyCapabilityAdapter.convert([
        .packageService: .available,
        .lifecycleRecovery: .degraded
    ])

    #expect(converted[.packageService]?.availability == .available)
    #expect(converted[.lifecycleRecovery]?.availability == .degraded)
}

@Test func standardCapabilityNamespaceRemainsStable() {
    #expect(CapabilityIdentifier.packageService.rawValue == "dev.prism.capability.package-service")
    #expect(CapabilityIdentifier.backgroundExecution.rawValue == "dev.prism.capability.background-execution")
    #expect(CapabilityIdentifier.serviceRegistration.rawValue == "dev.prism.capability.service-registration")
    #expect(CapabilityIdentifier.lifecycleRecovery.rawValue == "dev.prism.capability.lifecycle-recovery")
    #expect(CapabilityIdentifier.packageStoreAccess.rawValue == "dev.prism.capability.package-store-access")
    #expect(CapabilityIdentifier.repositoryNetworking.rawValue == "dev.prism.capability.repository-networking")
    #expect(CapabilityIdentifier.appRegistration.rawValue == "dev.prism.capability.app-registration")
}

@Test func futureEnvironmentCapabilityRoundTripsWithoutLegacyEnum() throws {
    let future = CapabilityIdentifier(rawValue: "future.vendor.capability.repository-v3")
    let environment = PrismEnvironment(
        runtimeIdentity: "future.runtime",
        architecture: "arm64",
        capabilityStates: [
            future: CapabilityState(identifier: future, availability: .available, version: 3)
        ]
    )

    let data = try JSONEncoder().encode(environment)
    let decoded = try JSONDecoder().decode(PrismEnvironment.self, from: data)

    #expect(decoded.capabilityStates[future]?.availability == .available)
    #expect(decoded.capabilityStates[future]?.version == 3)
}

@Test func legacyEnvironmentCapabilityMigratesToIdentifier() {
    let identifier = LegacyEnvironmentCapabilityAdapter.convert(.packageInstall)
    #expect(identifier.rawValue == "dev.prism.capability.environment.packageInstall")
    #expect(LegacyEnvironmentCapabilityAdapter.legacyCapability(for: identifier) == .packageInstall)
}

@Test func bridgeDescriptorsPreserveUnknownCapabilityIdentifiers() throws {
    let future = CapabilityIdentifier(rawValue: "future.vendor.capability.bridge-v4")
    let state = CapabilityState(identifier: future, availability: .available, version: 4)
    let runtime = RuntimeDescriptor(
        runtimeIdentity: "future.runtime",
        displayName: "Future Runtime",
        runtimeVersion: "4",
        operatingMode: .modern,
        architecture: "arm64",
        environmentState: "ready",
        runtimeCapabilityStates: [future: state]
    )
    let service = PackageServiceDescriptor(
        serviceIdentity: "future.service",
        serviceVersion: "4",
        protocolVersion: "2",
        capabilityStates: [future: state],
        supportedPackageFormats: [.prismNative],
        recoveryStrategies: [.reconcile],
        sessionBehavior: .persistent
    )
    let session = RelaxinBridgeSession(negotiatedProtocolVersion: "2", runtime: runtime, service: service)

    let data = try JSONEncoder().encode(session)
    let decoded = try JSONDecoder().decode(RelaxinBridgeSession.self, from: data)

    #expect(decoded.runtime.runtimeCapabilityStates[future]?.version == 4)
    #expect(decoded.service.capabilityStates[future]?.availability == .available)
}
