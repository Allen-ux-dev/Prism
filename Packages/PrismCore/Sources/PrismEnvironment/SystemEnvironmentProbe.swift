import Foundation

public struct SystemEnvironmentProbe: Sendable {
    public init() {}
    public func snapshot() -> EnvironmentProbeSnapshot {
        let fm = FileManager.default
        let rootless = "/var/jb"
        let isRootless = fm.fileExists(atPath: rootless)
        let prefix = isRootless ? rootless : ""
        var executables: Set<String> = []
        if fm.isExecutableFile(atPath: prefix + "/usr/bin/apt-get") || fm.isExecutableFile(atPath: prefix + "/usr/bin/apt") { executables.insert("apt") }
        if fm.isExecutableFile(atPath: prefix + "/usr/bin/dpkg") { executables.insert("dpkg") }
        if fm.isExecutableFile(atPath: prefix + "/usr/bin/swiftc") || fm.isExecutableFile(atPath: prefix + "/usr/bin/clang") { executables.insert("swiftc") }
        let status = prefix + "/var/lib/dpkg/status"
        return EnvironmentProbeSnapshot(
            providerHints: [isRootless ? "rootless" : "rootful"],
            existingPaths: isRootless ? [rootless] : ["/"],
            executableNames: executables,
            architecture: Self.machineArchitecture(),
            bootstrapIdentifier: nil,
            packageDatabasePath: fm.fileExists(atPath: status) ? status : nil
        )
    }
    private static func machineArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
