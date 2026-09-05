import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution

@Test func sourceBuildRequiresBuildAndCompilerCapabilities() {
    let manifest = SourcePackageManifest(packageIdentifier: "source.demo", sourceReference: "local", requiredCapabilities: [], toolchainRequirements: ["swiftc"], steps: [.compile(sourceFiles: ["main.swift"], output: "Demo")], artifact: .init(relativePath: "Demo.deb", kind: .deb))
    let plan = BuildPlanner().plan(manifest: manifest, environment: .fixtureBuild(capabilities: [.sourceBuild]))
    #expect(plan.unmetCapabilities == [.compiler])
    #expect(!plan.isExecutable)
}

private extension PrismEnvironment {
    static func fixtureBuild(capabilities: Set<EnvironmentCapability>) -> PrismEnvironment { .init(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: capabilities) }
}
