import Foundation

public struct RootfulEnvironmentProvider: EnvironmentProvider, Sendable {
    public let identifier = "rootful"

    public init() {}

    public func probe(_ probe: EnvironmentProbeSnapshot) -> PrismEnvironment? {
        guard probe.providerHints.contains("rootful") else { return nil }

        var capabilities: Set<EnvironmentCapability> = [
            .backgroundService,
            .packageInstall,
            .repositoryManagement,
            .tweakRuntime
        ]
        if probe.executableNames.contains("apt") { capabilities.insert(.apt) }
        if probe.executableNames.contains("dpkg") { capabilities.insert(.dpkg) }
        if probe.executableNames.contains("swiftc") || probe.executableNames.contains("clang") {
            capabilities.formUnion([.sourceBuild, .compiler])
        }

        let database = probe.packageDatabasePath.map {
            PackageDatabaseInfo(kind: "dpkg", path: URL(fileURLWithPath: $0))
        }

        let prefix = URL(fileURLWithPath: "/")
        let tools = EnvironmentToolPaths(
            aptGet: capabilities.contains(.apt) ? prefix.appendingPathComponent("usr/bin/apt-get") : nil,
            dpkg: capabilities.contains(.dpkg) ? prefix.appendingPathComponent("usr/bin/dpkg") : nil,
            dpkgQuery: capabilities.contains(.dpkg) ? prefix.appendingPathComponent("usr/bin/dpkg-query") : nil,
            prismSourcesList: prefix.appendingPathComponent("etc/apt/sources.list.d/prism.list")
        )

        return PrismEnvironment(
            providerIdentifier: identifier,
            bootstrapIdentifier: probe.bootstrapIdentifier,
            rootStyle: .rootful,
            rootPrefix: prefix,
            architecture: probe.architecture,
            capabilities: capabilities,
            packageDatabase: database,
            toolPaths: tools
        )
    }
}
