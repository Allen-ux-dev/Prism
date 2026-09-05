import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum PosixRunnerError: Error, Equatable { case pipeFailed(Int32), spawnFailed(Int32), waitFailed(Int32) }

public struct PosixSpawnPackageToolRunner: PackageToolRunning, Sendable {
    public init() {}
    public func run(executable: URL, arguments: [String]) async throws -> ToolExecutionResult {
        try await Task.detached(priority: .utility) { try Self.runSync(executable: executable, arguments: arguments) }.value
    }

    private static func runSync(executable: URL, arguments: [String]) throws -> ToolExecutionResult {
        var outputPipe: [Int32] = [0, 0]
        guard pipe(&outputPipe) == 0 else { throw PosixRunnerError.pipeFailed(errno) }
        defer { _ = close(outputPipe[0]); _ = close(outputPipe[1]) }

#if canImport(Darwin)
        var actions: posix_spawn_file_actions_t?
#else
        var actions = posix_spawn_file_actions_t()
#endif
        let actionsResult = posix_spawn_file_actions_init(&actions)
        guard actionsResult == 0 else { throw PosixRunnerError.spawnFailed(actionsResult) }
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, outputPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, outputPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&actions, outputPipe[0])

        let argvStrings = [executable.path] + arguments
        let cStrings = argvStrings.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }
        var argv = cStrings + [nil]
        let environmentStrings = ProcessInfo.processInfo.environment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
        let environmentCStrings = environmentStrings.map { strdup($0) }
        defer { environmentCStrings.forEach { free($0) } }
        var envp = environmentCStrings + [nil]
        var pid: pid_t = 0
        let spawnResult = executable.path.withCString { pathPtr in
            argv.withUnsafeMutableBufferPointer { argvBuffer in
                envp.withUnsafeMutableBufferPointer { envBuffer in
                    posix_spawn(&pid, pathPtr, &actions, nil, argvBuffer.baseAddress!, envBuffer.baseAddress!)
                }
            }
        }
        guard spawnResult == 0 else { throw PosixRunnerError.spawnFailed(spawnResult) }
        _ = close(outputPipe[1]); outputPipe[1] = -1

        var output = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(outputPipe[0], &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 { if errno == EINTR { continue }; break }
            output.append(buffer, count: count)
        }
        var status: Int32 = 0
        guard waitpid(pid, &status, 0) >= 0 else { throw PosixRunnerError.waitFailed(errno) }
        // POSIX wait status layout is stable across Darwin/Linux for the cases
        // Prism needs here. Avoid C macro imports that are brittle under Swift 6.
        let terminatingSignal = status & 0x7f
        let exitCode: Int32 = terminatingSignal == 0
            ? ((status >> 8) & 0xff)
            : 128 + terminatingSignal
        return ToolExecutionResult(exitCode: exitCode, stdout: String(data: output, encoding: .utf8) ?? "", stderr: "")
    }
}
