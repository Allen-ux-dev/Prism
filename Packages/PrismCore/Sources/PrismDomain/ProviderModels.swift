import Foundation

public struct ProviderKind: RawRepresentable, Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public static let repository = Self(rawValue: "repository")
    public static let packageService = Self(rawValue: "package-service")
    public static let environment = Self(rawValue: "environment")
    public static let versionScheme = Self(rawValue: "version-scheme")
    public static let packageFormat = Self(rawValue: "package-format")
    public static let appInstallation = Self(rawValue: "app-installation")
    public static let appInjection = Self(rawValue: "app-injection")
}

public enum PrismOperatingMode: String, Codable, Hashable, Sendable, CaseIterable {
    case modern
    case hybrid
    case legacy
}

public enum ProviderHealth: Codable, Hashable, Sendable, Equatable {
    case healthy
    case degraded(String)
    case unavailable(String)
    case unknown(String?)

    public var isUsable: Bool {
        switch self {
        case .healthy, .degraded: return true
        case .unavailable, .unknown: return false
        }
    }

    public var reason: String? {
        switch self {
        case .degraded(let reason), .unavailable(let reason): return reason
        case .unknown(let reason): return reason
        case .healthy: return nil
        }
    }
}

public enum ProviderRecoveryStrategy: String, Codable, Hashable, Sendable {
    case reconcile
    case rollback
    case safeAbort
}

public struct ProviderIdentity: Codable, Hashable, Sendable {
    public let providerID: String
    public let providerKind: ProviderKind
    public let providerVersion: String
    public let protocolVersion: String?

    public init(providerID: String, providerKind: ProviderKind, providerVersion: String, protocolVersion: String? = nil) {
        self.providerID = providerID
        self.providerKind = providerKind
        self.providerVersion = providerVersion
        self.protocolVersion = protocolVersion
    }
}

public struct ProviderRuntimeState: Codable, Hashable, Sendable {
    public var health: ProviderHealth
    public var capabilityReport: [String: ProviderHealth]
    public var supportedFormats: Set<PackageFormatIdentifier>
    public var supportedVersionSchemes: Set<String>
    public var recoveryStrategies: Set<ProviderRecoveryStrategy>
    public var lastHealthChange: Date
    public var diagnosticSummary: String?

    public init(
        health: ProviderHealth,
        capabilityReport: [String: ProviderHealth] = [:],
        supportedFormats: Set<PackageFormatIdentifier> = [],
        supportedVersionSchemes: Set<String> = [],
        recoveryStrategies: Set<ProviderRecoveryStrategy> = [],
        lastHealthChange: Date = Date(),
        diagnosticSummary: String? = nil
    ) {
        self.health = health
        self.capabilityReport = capabilityReport
        self.supportedFormats = supportedFormats
        self.supportedVersionSchemes = supportedVersionSchemes
        self.recoveryStrategies = recoveryStrategies
        self.lastHealthChange = lastHealthChange
        self.diagnosticSummary = diagnosticSummary
    }
}

public struct ProviderDiagnosticsSnapshot: Codable, Hashable, Sendable {
    public let identity: ProviderIdentity
    public let runtimeState: ProviderRuntimeState
    public let metadata: [String: String]

    public init(identity: ProviderIdentity, runtimeState: ProviderRuntimeState, metadata: [String: String] = [:]) {
        self.identity = identity
        self.runtimeState = runtimeState
        self.metadata = metadata
    }
}

public struct PrismProviderDescriptor: Codable, Hashable, Sendable {
    public let identifier: String
    public let kind: ProviderKind
    public let version: String
    public let protocolVersion: String?
    public let priority: Int
    public let operatingModes: Set<PrismOperatingMode>
    public let supportedRequirements: Set<String>
    public let supportedFormats: Set<PackageFormatIdentifier>
    public let supportedVersionSchemes: Set<String>
    public let runtimeIdentities: Set<String>
    public let recoveryStrategies: Set<ProviderRecoveryStrategy>
    public let health: ProviderHealth
    public let diagnosticsMetadata: [String: String]

    public init(
        identifier: String,
        kind: ProviderKind,
        version: String,
        protocolVersion: String? = nil,
        priority: Int = 0,
        operatingModes: Set<PrismOperatingMode> = [.modern, .hybrid, .legacy],
        supportedRequirements: Set<String> = [],
        supportedFormats: Set<PackageFormatIdentifier> = [],
        supportedVersionSchemes: Set<String> = [],
        runtimeIdentities: Set<String> = [],
        recoveryStrategies: Set<ProviderRecoveryStrategy> = [],
        health: ProviderHealth = .unknown(nil),
        diagnosticsMetadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.kind = kind
        self.version = version
        self.protocolVersion = protocolVersion
        self.priority = priority
        self.operatingModes = operatingModes
        self.supportedRequirements = supportedRequirements
        self.supportedFormats = supportedFormats
        self.supportedVersionSchemes = supportedVersionSchemes
        self.runtimeIdentities = runtimeIdentities
        self.recoveryStrategies = recoveryStrategies
        self.health = health
        self.diagnosticsMetadata = diagnosticsMetadata
    }

    public var identity: ProviderIdentity {
        .init(providerID: identifier, providerKind: kind, providerVersion: version, protocolVersion: protocolVersion)
    }

    public func initialRuntimeState(now: Date = Date()) -> ProviderRuntimeState {
        .init(
            health: health,
            capabilityReport: Dictionary(uniqueKeysWithValues: supportedRequirements.map { ($0, health) }),
            supportedFormats: supportedFormats,
            supportedVersionSchemes: supportedVersionSchemes,
            recoveryStrategies: recoveryStrategies,
            lastHealthChange: now,
            diagnosticSummary: health.reason
        )
    }
}

public protocol PrismProvider: Sendable {
    var descriptor: PrismProviderDescriptor { get }
}

public protocol PrismRuntimeStateReporting: PrismProvider {
    func providerRuntimeState() async -> ProviderRuntimeState
}

public struct ProviderSelectionContext: Codable, Hashable, Sendable {
    public let mode: PrismOperatingMode
    public let runtimeIdentity: String?
    public let requiredRequirements: Set<String>
    public let requiredFormats: Set<PackageFormatIdentifier>
    public let explicitProviderIdentifier: String?

    public init(
        mode: PrismOperatingMode,
        runtimeIdentity: String? = nil,
        requiredRequirements: Set<String> = [],
        requiredFormats: Set<PackageFormatIdentifier> = [],
        explicitProviderIdentifier: String? = nil
    ) {
        self.mode = mode
        self.runtimeIdentity = runtimeIdentity
        self.requiredRequirements = requiredRequirements
        self.requiredFormats = requiredFormats
        self.explicitProviderIdentifier = explicitProviderIdentifier
    }
}

public struct ProviderOperationRequirements: Codable, Hashable, Sendable {
    public let capabilities: Set<String>
    public let packageFormats: Set<PackageFormatIdentifier>
    public let runtimeIdentity: String?
    public let isWrite: Bool

    public init(
        capabilities: Set<String>,
        packageFormats: Set<PackageFormatIdentifier> = [],
        runtimeIdentity: String? = nil,
        isWrite: Bool
    ) {
        self.capabilities = capabilities
        self.packageFormats = packageFormats
        self.runtimeIdentity = runtimeIdentity
        self.isWrite = isWrite
    }

    public static func install(packages: [PrismPackage], runtimeIdentity: String? = nil) -> Self {
        var capabilities: Set<String> = ["packageInstall"]
        for package in packages {
            capabilities.formUnion(package.requirements.map(\.identifier))
        }
        return .init(
            capabilities: capabilities,
            packageFormats: Set(packages.map(\.distribution)),
            runtimeIdentity: runtimeIdentity,
            isWrite: true
        )
    }

    public func selectionContext(mode: PrismOperatingMode, explicitProviderIdentifier: String? = nil) -> ProviderSelectionContext {
        .init(
            mode: mode,
            runtimeIdentity: runtimeIdentity,
            requiredRequirements: capabilities,
            requiredFormats: packageFormats,
            explicitProviderIdentifier: explicitProviderIdentifier
        )
    }
}
