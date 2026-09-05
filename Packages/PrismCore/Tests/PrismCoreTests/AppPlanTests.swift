import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution

@Test func ipaInstallRequiresInstallAndRegistrationCapabilities() {
    let ipa = IPAInspectionSnapshot(bundleIdentifier: "dev.demo", displayName: "Demo", version: "1", architectures: ["arm64"])
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [.ipaInstall])
    let plan = AppInstallPlanner().plan(ipa: ipa, environment: env)
    #expect(plan.unmetCapabilities == [.appRegistration])
}

@Test func injectionChecksArtifactSpecificCapabilityAndArchitecture() {
    let app = PrismInstalledApp(bundleIdentifier: "dev.demo", displayName: "Demo", version: "1", architecture: "arm64")
    let artifact = InjectionArtifact(identifier: "tweak.demo", displayName: "Demo Tweak", kind: .dylib, supportedArchitectures: ["arm64"])
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [.appInjection])
    let plan = InjectionPlanner().plan(target: app, artifact: artifact, environment: env)
    #expect(plan.unmetCapabilities == [.dylibInjection])
}
