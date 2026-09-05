import Foundation
import Testing
@testable import PrismEnvironment
@testable import PrismPrivilegedProtocol
@testable import PrismDaemonCore

private actor SourceSyncRunner: PackageToolRunning {
    var arguments:[[String]]=[]
    func run(executable: URL, arguments: [String]) async throws -> ToolExecutionResult { self.arguments.append(arguments); return .init(exitCode: 0) }
    func calls() -> [[String]] { arguments }
}

@Test func sourceSynchronizerWritesOnlyConfiguredPrismListAndRefreshesAPT() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let list = dir.appendingPathComponent("prism.list")
    let env = PrismEnvironment(providerIdentifier:"fixture", bootstrapIdentifier:nil, rootStyle:.rootless, rootPrefix:dir, architecture:"arm64", capabilities:[.repositoryManagement,.apt], toolPaths:.init(aptGet:dir.appendingPathComponent("apt-get"), prismSourcesList:list), prismDataDirectory:dir.appendingPathComponent("prism-data"))
    let runner=SourceSyncRunner(); let sync=APTSourceFileSynchronizer(environment:env, runner:runner)
    try await sync.sync([.init(baseURL: URL(string:"https://repo.example/")!)])
    #expect(try String(contentsOf:list, encoding:.utf8) == "deb https://repo.example/ ./\n")
    #expect(await runner.calls() == [["update"]])
    try? FileManager.default.removeItem(at:dir)
}
