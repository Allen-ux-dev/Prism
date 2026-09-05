import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismUIBridge

@Test func runtimeDisplayNameComesFromDescriptorNotProductName() {
    let environment = PrismEnvironment(
        runtimeIdentity: "dev.relaxin.runtime",
        runtimeDisplayName: "Runtime Supplied Name",
        runtimeVersion: "3.0",
        architecture: "arm64",
        capabilityReport: [.packageInstall: .available]
    )
    let provider = PrismProviderDescriptor(
        identifier: "future.package.service",
        kind: .packageService,
        version: "1",
        operatingModes: [.modern],
        health: .healthy
    )

    let descriptor = RuntimePresentationDescriptor.derive(environment: environment, serviceDescriptor: provider, serviceHealth: .healthy)

    #expect(descriptor.displayName == "Runtime Supplied Name")
    #expect(descriptor.operatingMode == .modern)
}

@Test func runtimeModeComesFromProviderAndCompatibilityState() {
    let environment = PrismEnvironment(
        runtimeIdentity: "arbitrary.runtime",
        architecture: "arm64",
        capabilityReport: [.legacyDebCompatibility: .available, .packageInstall: .available],
        compatibilityLayers: ["legacy-bootstrap"],
        legacy: .init(bootstrapIdentifier: "fixture", rootStyle: .rootless)
    )
    let provider = PrismProviderDescriptor(
        identifier: "legacy.service",
        kind: .packageService,
        version: "1",
        operatingModes: [.legacy],
        health: .healthy
    )

    let descriptor = RuntimePresentationDescriptor.derive(environment: environment, serviceDescriptor: provider, serviceHealth: .healthy)

    #expect(descriptor.operatingMode == .legacy)
}

@Test func noPackageServiceProducesReadOnlyRuntimePresentation() {
    let environment = PrismEnvironment(runtimeIdentity: "", architecture: "arm64", capabilityReport: [:])

    let descriptor = RuntimePresentationDescriptor.derive(environment: environment, serviceDescriptor: nil, serviceHealth: nil)

    #expect(descriptor.operatingMode == .readOnly)
}

@Test func unknownRuntimeIdentityIsDisplayedWithoutProductLookup() {
    let environment = PrismEnvironment(runtimeIdentity: "future.vendor.runtime", architecture: "arm64", capabilityReport: [:])
    let provider = PrismProviderDescriptor(identifier: "future.service", kind: .packageService, version: "1", operatingModes: [.modern], health: .healthy)

    let descriptor = RuntimePresentationDescriptor.derive(environment: environment, serviceDescriptor: provider, serviceHealth: .healthy)

    #expect(descriptor.displayName == "future.vendor.runtime")
}

@Test func runtimeOperatingModeCanComeFromNormalizedRuntimeDescriptor() {
    let environment = PrismEnvironment(
        runtimeIdentity: "future.runtime",
        runtimeDisplayName: "Future Runtime",
        runtimeOperatingMode: .readOnly,
        architecture: "arm64",
        capabilityReport: [:]
    )
    let service = PrismProviderDescriptor(
        identifier: "generic.service",
        kind: .packageService,
        version: "1",
        operatingModes: [.modern],
        health: .healthy
    )

    let presentation = RuntimePresentationDescriptor.derive(
        environment: environment,
        serviceDescriptor: service,
        serviceHealth: .healthy
    )

    #expect(presentation.operatingMode == .readOnly)
    #expect(presentation.compatibilityLevel == .partiallyCompatible)
}
