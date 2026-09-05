import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismDaemonCore

private actor FakeRunner: PackageToolRunning {
    var calls: [(String, [String])] = []
    func run(executable: URL, arguments: [String]) async throws -> ToolExecutionResult {
        calls.append((executable.path, arguments))
        if executable.lastPathComponent == "dpkg-query" { return .init(exitCode: 0, stdout: "demo\t1.2\n") }
        return .init(exitCode: 0, stdout: "ok")
    }
    func snapshot() -> [(String,[String])] { calls }
}

@Test func packageBackendUsesEnvironmentSelectedTools() async throws {
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [.apt, .dpkg])
    let runner = FakeRunner()
    let backend = JailbreakPackageExecutionBackend(environment: env, tools: .init(aptGet: URL(fileURLWithPath: "/fixture/usr/bin/apt-get"), dpkg: URL(fileURLWithPath: "/fixture/usr/bin/dpkg"), dpkgQuery: URL(fileURLWithPath: "/fixture/usr/bin/dpkg-query")), runner: runner)
    #expect(try await backend.inspectPackageState().installedVersions["demo"] == .debian("1.2"))
    _ = try await backend.execute(.installPackage(.init(packageIdentifier: "demo", version: DebianVersion("1.2"))))
    let calls = await runner.snapshot()
    #expect(calls[0].0.hasSuffix("dpkg-query"))
    #expect(calls[1].1 == ["-y", "install", "demo=1.2"])
}

@Test func packageBackendUsesPurgeForCompleteRemoval() async throws {
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [.apt, .dpkg, .packageRemove])
    let runner = FakeRunner()
    let backend = JailbreakPackageExecutionBackend(environment: env, tools: .init(aptGet: URL(fileURLWithPath: "/fixture/usr/bin/apt-get"), dpkg: URL(fileURLWithPath: "/fixture/usr/bin/dpkg"), dpkgQuery: URL(fileURLWithPath: "/fixture/usr/bin/dpkg-query")), runner: runner)
    _ = try await backend.execute(.purgePackage("plugin.target"))
    let calls = await runner.snapshot()
    #expect(calls.last?.1 == ["-y", "purge", "plugin.target"])
}
