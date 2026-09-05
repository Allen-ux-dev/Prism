import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions

public struct ToolExecutionResult: Sendable, Equatable { public let exitCode: Int32; public let stdout: String; public let stderr: String; public init(exitCode: Int32, stdout: String = "", stderr: String = "") { self.exitCode = exitCode; self.stdout = stdout; self.stderr = stderr } }
public protocol PackageToolRunning: Sendable { func run(executable: URL, arguments: [String]) async throws -> ToolExecutionResult }
public enum PackageBackendError: Error, Equatable { case missingCapability(String), unsupportedOperation, toolFailure(String) }

public actor JailbreakPackageExecutionBackend: PackageExecutionBackend {
    private let environment: PrismEnvironment
    private let tools: EnvironmentToolPaths
    private let runner: any PackageToolRunning
    public init(environment: PrismEnvironment, tools: EnvironmentToolPaths? = nil, runner: any PackageToolRunning) { self.environment = environment; self.tools = tools ?? environment.toolPaths; self.runner = runner }

    public func inspectPackageState() async throws -> PackageStateSnapshot {
        guard environment.capabilities.contains(.dpkg), let query = tools.dpkgQuery else { throw PackageBackendError.missingCapability("dpkg") }
        let result = try await runner.run(executable: query, arguments: ["-W", "-f=${Package}\\t${Version}\\n"])
        guard result.exitCode == 0 else { throw PackageBackendError.toolFailure(result.stderr) }
        var versions: [String: PackageVersion] = [:]
        for line in result.stdout.split(separator: "\n") { let parts = line.split(separator: "\t", maxSplits: 1).map(String.init); if parts.count == 2 { versions[parts[0]] = .debian(parts[1]) } }
        return PackageStateSnapshot(installedVersions: versions)
    }
    public func inspectApplicationState() async throws -> ApplicationStateSnapshot { .init() }
    public func execute(_ operation: TransactionOperation) async throws -> BackendOperationResult {
        guard environment.capabilities.contains(.apt), let apt = tools.aptGet else { throw PackageBackendError.missingCapability("apt") }
        let args: [String]
        switch operation {
        case .installPackage(let op), .upgradePackage(let op): args = ["-y", "install", "\(op.packageIdentifier)=\(op.version.rawValue)"]
        case .removePackage(let id): args = ["-y", "remove", id]
        case .purgePackage(let id): args = ["-y", "purge", id]
        default: throw PackageBackendError.unsupportedOperation
        }
        let result = try await runner.run(executable: apt, arguments: args)
        guard result.exitCode == 0 else { throw PackageBackendError.toolFailure(result.stderr) }
        return .init(operationID: operation.stableID, message: result.stdout)
    }
}
