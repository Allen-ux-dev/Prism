import Foundation
import PrismDomain
import PrismEnvironment

public struct AppInstallPlan: Codable, Sendable, Equatable {
    public let ipa: IPAInspectionSnapshot
    public let requiredCapabilities: Set<EnvironmentCapability>
    public let unmetCapabilities: Set<EnvironmentCapability>
    public let warnings: [String]
    public var isExecutable: Bool { unmetCapabilities.isEmpty }
}

public struct AppInstallPlanner: Sendable {
    public init() {}
    public func plan(ipa: IPAInspectionSnapshot, environment: PrismEnvironment) -> AppInstallPlan {
        let required: Set<EnvironmentCapability> = [.appInstall, .appRegistration]
        var warnings: [String] = []
        if !ipa.architectures.contains(environment.architecture) && !ipa.architectures.contains("universal") {
            warnings.append("IPA architecture does not match the current environment.")
        }
        return AppInstallPlan(ipa: ipa, requiredCapabilities: required,
                              unmetCapabilities: required.subtracting(environment.capabilities), warnings: warnings)
    }
}

public struct InjectionPlan: Codable, Sendable, Equatable {
    public let target: PrismInstalledApp
    public let artifact: InjectionArtifact
    public let requiredCapabilities: Set<EnvironmentCapability>
    public let unmetCapabilities: Set<EnvironmentCapability>
    public let warnings: [String]
    public var isExecutable: Bool { unmetCapabilities.isEmpty && warnings.isEmpty }
}

public struct InjectionPlanner: Sendable {
    public init() {}
    public func plan(target: PrismInstalledApp, artifact: InjectionArtifact, environment: PrismEnvironment) -> InjectionPlan {
        var required: Set<EnvironmentCapability> = [.appInjection]
        switch artifact.kind {
        case .dylib: required.insert(.dylibInjection)
        case .framework: required.insert(.frameworkInjection)
        case .bundle: required.insert(.bundleInjection)
        }
        var warnings: [String] = []
        if !artifact.supportedArchitectures.contains(target.architecture) && !artifact.supportedArchitectures.contains("universal") {
            warnings.append("Injection artifact architecture does not match the target app.")
        }
        return InjectionPlan(target: target, artifact: artifact, requiredCapabilities: required,
                             unmetCapabilities: required.subtracting(environment.capabilities), warnings: warnings)
    }
}
