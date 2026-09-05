import Foundation
import PrismDomain
import PrismEnvironment

public enum BuildStep: Codable, Sendable, Equatable {
    case compile(sourceFiles: [String], output: String)
    case copyResource(source: String, destination: String)
    case packageArtifact(input: String, output: String)
}

public struct ArtifactDescription: Codable, Sendable, Equatable {
    public let relativePath: String
    public let kind: PackageDistribution
    public init(relativePath: String, kind: PackageDistribution) { self.relativePath = relativePath; self.kind = kind }
}

public struct SourcePackageManifest: Codable, Sendable, Equatable {
    public let packageIdentifier: String
    public let sourceReference: String
    public let requiredCapabilities: Set<EnvironmentCapability>
    public let toolchainRequirements: [String]
    public let steps: [BuildStep]
    public let artifact: ArtifactDescription

    public init(packageIdentifier: String, sourceReference: String, requiredCapabilities: Set<EnvironmentCapability>,
                toolchainRequirements: [String], steps: [BuildStep], artifact: ArtifactDescription) {
        self.packageIdentifier = packageIdentifier
        self.sourceReference = sourceReference
        self.requiredCapabilities = requiredCapabilities
        self.toolchainRequirements = toolchainRequirements
        self.steps = steps
        self.artifact = artifact
    }
}

public struct BuildPlan: Codable, Sendable, Equatable {
    public let manifest: SourcePackageManifest
    public let unmetCapabilities: Set<EnvironmentCapability>
    public var isExecutable: Bool { unmetCapabilities.isEmpty }
}

public struct BuildPlanner: Sendable {
    public init() {}
    public func plan(manifest: SourcePackageManifest, environment: PrismEnvironment) -> BuildPlan {
        var required = manifest.requiredCapabilities
        required.insert(.sourceBuild)
        if !manifest.toolchainRequirements.isEmpty || manifest.steps.contains(where: { if case .compile = $0 { return true }; return false }) {
            required.insert(.compiler)
        }
        return BuildPlan(manifest: manifest, unmetCapabilities: required.subtracting(environment.capabilities))
    }
}
