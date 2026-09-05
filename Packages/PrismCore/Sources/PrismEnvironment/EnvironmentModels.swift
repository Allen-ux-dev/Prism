import Foundation
import PrismDomain

public enum RootStyle: String, Codable, Sendable, Hashable {
    case rootless
    case rootful
    case custom
}

public enum EnvironmentCapability: String, Codable, Sendable, Hashable, CaseIterable {
    // Modern package-service capabilities.
    case packageInstall
    case packageRemove
    case packageUpgrade
    case dependencyResolution
    case repositoryRefresh
    case transactionRollback
    case transactionReconcile
    case safeAbort
    case serviceRestart
    case userspaceRestart
    case runtimeHookSupport
    case legacyDebCompatibility
    case sourceBuild
    case appInstall
    case appRegistration
    case appReplace
    case appRemoval
    case appRefresh
    case appInjection

    // Compatibility/provider-internal capabilities retained for V1 migration.
    case backgroundService
    case apt
    case dpkg
    case compiler
    case systemHookRuntime
    case tweakRuntime
    case repositoryManagement
    case ipaInstall
    case dylibInjection
    case frameworkInjection
    case bundleInjection
    case trollStoreStyleInstall
}

public enum CapabilityStatus: Codable, Sendable, Hashable, Equatable {
    case available
    case unavailable
    case degraded(String)
    case unknown(String?)

    public var isUsable: Bool {
        switch self {
        case .available, .degraded: return true
        case .unavailable, .unknown: return false
        }
    }

    public var reason: String? {
        switch self {
        case .degraded(let reason): return reason
        case .unknown(let reason): return reason
        case .available, .unavailable: return nil
        }
    }
}

public struct PackageDatabaseInfo: Codable, Sendable, Hashable {
    public let kind: String
    public let path: URL?

    public init(kind: String, path: URL? = nil) {
        self.kind = kind
        self.path = path
    }
}

public struct EnvironmentToolPaths: Codable, Sendable, Hashable {
    public let aptGet: URL?
    public let dpkg: URL?
    public let dpkgQuery: URL?
    public let prismSourcesList: URL?

    public init(aptGet: URL? = nil, dpkg: URL? = nil, dpkgQuery: URL? = nil, prismSourcesList: URL? = nil) {
        self.aptGet = aptGet
        self.dpkg = dpkg
        self.dpkgQuery = dpkgQuery
        self.prismSourcesList = prismSourcesList
    }
}

public struct LegacyEnvironmentDetails: Codable, Sendable, Hashable {
    public let bootstrapIdentifier: String?
    public let rootStyle: RootStyle?
    public let rootPrefix: URL?
    public let packageDatabase: PackageDatabaseInfo?
    public let toolPaths: EnvironmentToolPaths

    public init(
        bootstrapIdentifier: String? = nil,
        rootStyle: RootStyle? = nil,
        rootPrefix: URL? = nil,
        packageDatabase: PackageDatabaseInfo? = nil,
        toolPaths: EnvironmentToolPaths = .init()
    ) {
        self.bootstrapIdentifier = bootstrapIdentifier
        self.rootStyle = rootStyle
        self.rootPrefix = rootPrefix
        self.packageDatabase = packageDatabase
        self.toolPaths = toolPaths
    }
}

public struct PrismEnvironment: Codable, Sendable, Hashable {
    public let runtimeIdentity: String
    public let runtimeDisplayName: String?
    public let runtimeVersion: String?
    public let runtimeOperatingMode: RuntimeOperatingMode?
    public let architecture: String
    public let osVersion: String?
    public let osBuild: String?
    public let capabilityStates: [CapabilityIdentifier: CapabilityState]
    public let storageNamespace: URL?
    public let packageStore: String?
    public let compatibilityLayers: [String]
    public let legacy: LegacyEnvironmentDetails?

    /// Future-first initializer. Unknown capability identifiers are preserved without Core changes.
    public init(
        runtimeIdentity: String,
        runtimeDisplayName: String? = nil,
        runtimeVersion: String? = nil,
        runtimeOperatingMode: RuntimeOperatingMode? = nil,
        architecture: String,
        osVersion: String? = nil,
        osBuild: String? = nil,
        capabilityStates: [CapabilityIdentifier: CapabilityState],
        storageNamespace: URL? = nil,
        packageStore: String? = nil,
        compatibilityLayers: [String] = [],
        legacy: LegacyEnvironmentDetails? = nil
    ) {
        self.runtimeIdentity = runtimeIdentity
        self.runtimeDisplayName = runtimeDisplayName
        self.runtimeVersion = runtimeVersion
        self.runtimeOperatingMode = runtimeOperatingMode
        self.architecture = architecture
        self.osVersion = osVersion
        self.osBuild = osBuild
        self.capabilityStates = capabilityStates
        self.storageNamespace = storageNamespace
        self.packageStore = packageStore
        self.compatibilityLayers = compatibilityLayers
        self.legacy = legacy
    }

    /// V1 source-compatibility initializer. Known enum capabilities are adapted into open identifiers.
    public init(
        runtimeIdentity: String,
        runtimeDisplayName: String? = nil,
        runtimeVersion: String? = nil,
        runtimeOperatingMode: RuntimeOperatingMode? = nil,
        architecture: String,
        osVersion: String? = nil,
        osBuild: String? = nil,
        capabilityReport: [EnvironmentCapability: CapabilityStatus],
        storageNamespace: URL? = nil,
        packageStore: String? = nil,
        compatibilityLayers: [String] = [],
        legacy: LegacyEnvironmentDetails? = nil
    ) {
        self.init(
            runtimeIdentity: runtimeIdentity,
            runtimeDisplayName: runtimeDisplayName,
            runtimeVersion: runtimeVersion,
            runtimeOperatingMode: runtimeOperatingMode,
            architecture: architecture,
            osVersion: osVersion,
            osBuild: osBuild,
            capabilityStates: LegacyEnvironmentCapabilityAdapter.convert(capabilityReport),
            storageNamespace: storageNamespace,
            packageStore: packageStore,
            compatibilityLayers: compatibilityLayers,
            legacy: legacy
        )
    }

    // V1 compatibility initializer. Legacy assumptions are captured inside `legacy`.
    public init(
        providerIdentifier: String,
        bootstrapIdentifier: String?,
        rootStyle: RootStyle,
        rootPrefix: URL,
        architecture: String,
        capabilities: Set<EnvironmentCapability>,
        packageDatabase: PackageDatabaseInfo? = nil,
        toolPaths: EnvironmentToolPaths = .init(),
        prismDataDirectory: URL? = nil
    ) {
        var report = Dictionary(uniqueKeysWithValues: capabilities.map { ($0, CapabilityStatus.available) })
        if capabilities.contains(.packageInstall) {
            report[.packageRemove] = report[.packageRemove] ?? .available
            report[.packageUpgrade] = report[.packageUpgrade] ?? .available
            report[.dependencyResolution] = report[.dependencyResolution] ?? .available
            report[.transactionReconcile] = report[.transactionReconcile] ?? .available
            report[.safeAbort] = report[.safeAbort] ?? .available
        }
        if capabilities.contains(.repositoryManagement) {
            report[.repositoryRefresh] = report[.repositoryRefresh] ?? .available
        }
        if capabilities.contains(.apt) || capabilities.contains(.dpkg) {
            report[.legacyDebCompatibility] = .available
        }
        if capabilities.contains(.ipaInstall) { report[.appInstall] = .available }

        let legacy = LegacyEnvironmentDetails(
            bootstrapIdentifier: bootstrapIdentifier,
            rootStyle: rootStyle,
            rootPrefix: rootPrefix,
            packageDatabase: packageDatabase,
            toolPaths: toolPaths
        )
        self.init(
            runtimeIdentity: providerIdentifier,
            runtimeVersion: nil,
            architecture: architecture,
            capabilityReport: report,
            storageNamespace: prismDataDirectory ?? rootPrefix.appendingPathComponent("var/lib/prism", isDirectory: true),
            packageStore: packageDatabase?.kind,
            compatibilityLayers: ["legacy-bootstrap"],
            legacy: legacy
        )
    }

    /// Legacy view for V1 providers and UI adapters. Unknown future identifiers remain in `capabilityStates`.
    public var capabilityReport: [EnvironmentCapability: CapabilityStatus] {
        LegacyEnvironmentCapabilityAdapter.legacyMap(capabilityStates)
    }

    public func status(of capability: EnvironmentCapability) -> CapabilityStatus {
        capabilityReport[capability] ?? .unknown(nil)
    }

    public func state(of identifier: CapabilityIdentifier) -> CapabilityState? {
        capabilityStates[identifier]
    }

    public var capabilities: Set<EnvironmentCapability> {
        Set(capabilityReport.compactMap { key, value in value.isUsable ? key : nil })
    }

    // V1 compatibility accessors. New Core/Application code should use modern fields.
    public var providerIdentifier: String { runtimeIdentity }
    public var bootstrapIdentifier: String? { legacy?.bootstrapIdentifier }
    public var rootStyle: RootStyle { legacy?.rootStyle ?? .custom }
    public var rootPrefix: URL { legacy?.rootPrefix ?? storageNamespace ?? URL(fileURLWithPath: "/") }
    public var packageDatabase: PackageDatabaseInfo? { legacy?.packageDatabase }
    public var toolPaths: EnvironmentToolPaths { legacy?.toolPaths ?? .init() }
    public var prismDataDirectory: URL { storageNamespace ?? rootPrefix.appendingPathComponent("var/lib/prism", isDirectory: true) }

    private enum CodingKeys: String, CodingKey {
        case runtimeIdentity, runtimeDisplayName, runtimeVersion, runtimeOperatingMode, architecture, osVersion, osBuild
        case capabilityStates, capabilityReport, storageNamespace, packageStore, compatibilityLayers, legacy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runtimeIdentity = try container.decode(String.self, forKey: .runtimeIdentity)
        runtimeDisplayName = try container.decodeIfPresent(String.self, forKey: .runtimeDisplayName)
        runtimeVersion = try container.decodeIfPresent(String.self, forKey: .runtimeVersion)
        runtimeOperatingMode = try container.decodeIfPresent(RuntimeOperatingMode.self, forKey: .runtimeOperatingMode)
        architecture = try container.decode(String.self, forKey: .architecture)
        osVersion = try container.decodeIfPresent(String.self, forKey: .osVersion)
        osBuild = try container.decodeIfPresent(String.self, forKey: .osBuild)
        storageNamespace = try container.decodeIfPresent(URL.self, forKey: .storageNamespace)
        packageStore = try container.decodeIfPresent(String.self, forKey: .packageStore)
        compatibilityLayers = try container.decodeIfPresent([String].self, forKey: .compatibilityLayers) ?? []
        legacy = try container.decodeIfPresent(LegacyEnvironmentDetails.self, forKey: .legacy)

        if let raw = try container.decodeIfPresent([String: CapabilityState].self, forKey: .capabilityStates) {
            capabilityStates = Dictionary(uniqueKeysWithValues: raw.map { rawID, state in
                let identifier = CapabilityIdentifier(rawValue: rawID)
                return (identifier, CapabilityState(
                    identifier: identifier,
                    availability: state.availability,
                    version: state.version,
                    metadata: state.metadata
                ))
            })
        } else {
            let legacyReport = try container.decodeIfPresent([EnvironmentCapability: CapabilityStatus].self, forKey: .capabilityReport) ?? [:]
            capabilityStates = LegacyEnvironmentCapabilityAdapter.convert(legacyReport)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runtimeIdentity, forKey: .runtimeIdentity)
        try container.encodeIfPresent(runtimeDisplayName, forKey: .runtimeDisplayName)
        try container.encodeIfPresent(runtimeVersion, forKey: .runtimeVersion)
        try container.encodeIfPresent(runtimeOperatingMode, forKey: .runtimeOperatingMode)
        try container.encode(architecture, forKey: .architecture)
        try container.encodeIfPresent(osVersion, forKey: .osVersion)
        try container.encodeIfPresent(osBuild, forKey: .osBuild)
        try container.encodeIfPresent(storageNamespace, forKey: .storageNamespace)
        try container.encodeIfPresent(packageStore, forKey: .packageStore)
        try container.encode(compatibilityLayers, forKey: .compatibilityLayers)
        try container.encodeIfPresent(legacy, forKey: .legacy)
        let rawStates = Dictionary(uniqueKeysWithValues: capabilityStates.map { ($0.key.rawValue, $0.value) })
        try container.encode(rawStates, forKey: .capabilityStates)
        try container.encode(capabilityReport, forKey: .capabilityReport)
    }
}

public struct EnvironmentProbeSnapshot: Codable, Sendable, Equatable {
    public let providerHints: Set<String>
    public let existingPaths: Set<String>
    public let executableNames: Set<String>
    public let architecture: String
    public let bootstrapIdentifier: String?
    public let packageDatabasePath: String?
    public let runtimeVersion: String?
    public let osVersion: String?
    public let osBuild: String?

    public init(
        providerHints: Set<String> = [],
        existingPaths: Set<String> = [],
        executableNames: Set<String> = [],
        architecture: String,
        bootstrapIdentifier: String? = nil,
        packageDatabasePath: String? = nil,
        runtimeVersion: String? = nil,
        osVersion: String? = nil,
        osBuild: String? = nil
    ) {
        self.providerHints = providerHints
        self.existingPaths = existingPaths
        self.executableNames = executableNames
        self.architecture = architecture
        self.bootstrapIdentifier = bootstrapIdentifier
        self.packageDatabasePath = packageDatabasePath
        self.runtimeVersion = runtimeVersion
        self.osVersion = osVersion
        self.osBuild = osBuild
    }
}

public extension PrismEnvironment {
    func addingCapabilities(_ additional: Set<EnvironmentCapability>) -> PrismEnvironment {
        var states = capabilityStates
        for capability in additional {
            let identifier = LegacyEnvironmentCapabilityAdapter.convert(capability)
            states[identifier] = CapabilityState(identifier: identifier, availability: .available)
        }
        return PrismEnvironment(
            runtimeIdentity: runtimeIdentity,
            runtimeDisplayName: runtimeDisplayName,
            runtimeVersion: runtimeVersion,
            runtimeOperatingMode: runtimeOperatingMode,
            architecture: architecture,
            osVersion: osVersion,
            osBuild: osBuild,
            capabilityStates: states,
            storageNamespace: storageNamespace,
            packageStore: packageStore,
            compatibilityLayers: compatibilityLayers,
            legacy: legacy
        )
    }
}
