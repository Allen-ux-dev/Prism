import Foundation
import Testing
@testable import PrismEnvironment

@Test func rootlessProviderOwnsRootPrefix() {
    let environment = StandardRootlessEnvironmentProvider()
        .probe(.fixtureRootless)
    #expect(environment?.rootPrefix.path == "/var/jb")
    #expect(environment?.rootStyle == .rootless)
}

@Test func environmentResolverUsesProviderPriorityWithoutProductNameBranches() throws {
    let resolver = EnvironmentResolver(providers: [
        StandardRootlessEnvironmentProvider(),
        RootfulEnvironmentProvider()
    ])

    let result = try resolver.resolve(.fixtureRootless)
    #expect(result.environment.providerIdentifier == "standard-rootless")
    #expect(result.diagnostics.first?.matched == true)
}

@Test func capabilitiesAreReportedAsData() throws {
    let resolver = EnvironmentResolver(providers: [StandardRootlessEnvironmentProvider()])
    let result = try resolver.resolve(.fixtureRootless)
    #expect(result.environment.capabilities.contains(.packageInstall))
    #expect(result.environment.capabilities.contains(.backgroundService))
}

private extension EnvironmentProbeSnapshot {
    static let fixtureRootless = EnvironmentProbeSnapshot(
        providerHints: ["rootless"],
        existingPaths: ["/var/jb"],
        executableNames: ["apt", "dpkg", "prismd"],
        architecture: "arm64",
        bootstrapIdentifier: "procursus",
        packageDatabasePath: "/var/jb/var/lib/dpkg/status"
    )
}
