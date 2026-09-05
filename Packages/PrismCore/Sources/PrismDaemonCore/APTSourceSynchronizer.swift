import Foundation
import PrismEnvironment
import PrismPrivilegedProtocol

public enum SourceSyncError: Error, Equatable { case unavailable, unsupportedScheme, writeFailed }

public actor APTSourceFileSynchronizer: SourceSynchronizing {
    private let environment: PrismEnvironment
    private let runner: any PackageToolRunning
    public init(environment: PrismEnvironment, runner: any PackageToolRunning) { self.environment = environment; self.runner = runner }
    public func sync(_ sources: [RepositorySourceDescriptor]) async throws {
        guard environment.capabilities.contains(.repositoryManagement), environment.capabilities.contains(.apt),
              let listURL = environment.toolPaths.prismSourcesList, let aptGet = environment.toolPaths.aptGet else { throw SourceSyncError.unavailable }
        let lines = try sources.map { source -> String in
            guard let scheme = source.baseURL.scheme?.lowercased(), scheme == "https" || scheme == "http" else { throw SourceSyncError.unsupportedScheme }
            return "deb \(source.baseURL.absoluteString) ./"
        }
        do {
            try FileManager.default.createDirectory(at: listURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")).data(using: .utf8)!.write(to: listURL, options: .atomic)
        } catch { throw SourceSyncError.writeFailed }
        let result = try await runner.run(executable: aptGet, arguments: ["update"])
        guard result.exitCode == 0 else { throw PackageBackendError.toolFailure(result.stdout) }
    }
}
