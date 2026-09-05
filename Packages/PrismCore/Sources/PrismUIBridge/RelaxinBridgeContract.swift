import Foundation
import PrismDomain
import PrismEnvironment

public enum BridgeError: Error, Equatable, Sendable {
    case handshakeFailed(String)
    case unsupportedProtocol(String)
    case invalidDescriptor(String)
    case sessionUnavailable
}

public struct RelaxinBridgeHandshake: Codable, Hashable, Sendable {
    public let clientIdentity: String
    public let supportedProtocolVersions: [String]

    public init(clientIdentity: String = "dev.prism", supportedProtocolVersions: [String] = ["1"]) {
        self.clientIdentity = clientIdentity
        self.supportedProtocolVersions = supportedProtocolVersions
    }
}

public struct RuntimeDescriptor: Codable, Hashable, Sendable {
    public let runtimeIdentity: String
    public let displayName: String?
    public let runtimeVersion: String?
    public let operatingMode: RuntimeOperatingMode?
    public let architecture: String
    public let socFamily: String?
    public let osVersion: String?
    public let osBuild: String?
    public let environmentState: String
    public let compatibilityLayers: [String]
    public let runtimeCapabilityStates: [CapabilityIdentifier: CapabilityState]

    /// V1 compatibility view. Unknown capability identifiers remain preserved in `runtimeCapabilityStates`.
    public var runtimeCapabilities: [EnvironmentCapability: CapabilityStatus] {
        LegacyEnvironmentCapabilityAdapter.legacyMap(runtimeCapabilityStates)
    }

    public init(
        runtimeIdentity: String,
        displayName: String? = nil,
        runtimeVersion: String? = nil,
        operatingMode: RuntimeOperatingMode? = nil,
        architecture: String,
        socFamily: String? = nil,
        osVersion: String? = nil,
        osBuild: String? = nil,
        environmentState: String,
        compatibilityLayers: [String] = [],
        runtimeCapabilityStates: [CapabilityIdentifier: CapabilityState]
    ) {
        self.runtimeIdentity = runtimeIdentity
        self.displayName = displayName
        self.runtimeVersion = runtimeVersion
        self.operatingMode = operatingMode
        self.architecture = architecture
        self.socFamily = socFamily
        self.osVersion = osVersion
        self.osBuild = osBuild
        self.environmentState = environmentState
        self.compatibilityLayers = compatibilityLayers
        self.runtimeCapabilityStates = runtimeCapabilityStates
    }

    /// V1 source-compatibility initializer.
    public init(
        runtimeIdentity: String,
        displayName: String? = nil,
        runtimeVersion: String? = nil,
        operatingMode: RuntimeOperatingMode? = nil,
        architecture: String,
        socFamily: String? = nil,
        osVersion: String? = nil,
        osBuild: String? = nil,
        environmentState: String,
        compatibilityLayers: [String] = [],
        runtimeCapabilities: [EnvironmentCapability: CapabilityStatus]
    ) {
        self.init(
            runtimeIdentity: runtimeIdentity,
            displayName: displayName,
            runtimeVersion: runtimeVersion,
            operatingMode: operatingMode,
            architecture: architecture,
            socFamily: socFamily,
            osVersion: osVersion,
            osBuild: osBuild,
            environmentState: environmentState,
            compatibilityLayers: compatibilityLayers,
            runtimeCapabilityStates: LegacyEnvironmentCapabilityAdapter.convert(runtimeCapabilities)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case runtimeIdentity, displayName, runtimeVersion, operatingMode, architecture, socFamily
        case osVersion, osBuild, environmentState, compatibilityLayers
        case runtimeCapabilityStates, runtimeCapabilities
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runtimeIdentity = try container.decode(String.self, forKey: .runtimeIdentity)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        runtimeVersion = try container.decodeIfPresent(String.self, forKey: .runtimeVersion)
        operatingMode = try container.decodeIfPresent(RuntimeOperatingMode.self, forKey: .operatingMode)
        architecture = try container.decode(String.self, forKey: .architecture)
        socFamily = try container.decodeIfPresent(String.self, forKey: .socFamily)
        osVersion = try container.decodeIfPresent(String.self, forKey: .osVersion)
        osBuild = try container.decodeIfPresent(String.self, forKey: .osBuild)
        environmentState = try container.decode(String.self, forKey: .environmentState)
        compatibilityLayers = try container.decodeIfPresent([String].self, forKey: .compatibilityLayers) ?? []

        if let raw = try container.decodeIfPresent([String: CapabilityState].self, forKey: .runtimeCapabilityStates) {
            runtimeCapabilityStates = Dictionary(uniqueKeysWithValues: raw.map { rawID, state in
                let identifier = CapabilityIdentifier(rawValue: rawID)
                return (identifier, CapabilityState(identifier: identifier, availability: state.availability, version: state.version, metadata: state.metadata))
            })
        } else {
            let legacy = try container.decodeIfPresent([EnvironmentCapability: CapabilityStatus].self, forKey: .runtimeCapabilities) ?? [:]
            runtimeCapabilityStates = LegacyEnvironmentCapabilityAdapter.convert(legacy)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runtimeIdentity, forKey: .runtimeIdentity)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(runtimeVersion, forKey: .runtimeVersion)
        try container.encodeIfPresent(operatingMode, forKey: .operatingMode)
        try container.encode(architecture, forKey: .architecture)
        try container.encodeIfPresent(socFamily, forKey: .socFamily)
        try container.encodeIfPresent(osVersion, forKey: .osVersion)
        try container.encodeIfPresent(osBuild, forKey: .osBuild)
        try container.encode(environmentState, forKey: .environmentState)
        try container.encode(compatibilityLayers, forKey: .compatibilityLayers)
        try container.encode(Dictionary(uniqueKeysWithValues: runtimeCapabilityStates.map { ($0.key.rawValue, $0.value) }), forKey: .runtimeCapabilityStates)
        try container.encode(runtimeCapabilities, forKey: .runtimeCapabilities)
    }
}

public enum PackageServiceSessionBehavior: String, Codable, Hashable, Sendable {
    case persistent
    case ephemeral
}

public struct PackageServiceDescriptor: Codable, Hashable, Sendable {
    public let serviceIdentity: String
    public let serviceVersion: String
    public let protocolVersion: String
    public let capabilityStates: [CapabilityIdentifier: CapabilityState]
    public let supportedPackageFormats: Set<PackageFormatIdentifier>
    public let supportedVersionSchemes: Set<String>
    public let recoveryStrategies: Set<ProviderRecoveryStrategy>
    public let sessionBehavior: PackageServiceSessionBehavior

    /// V1 compatibility view.
    public var capabilityReport: [EnvironmentCapability: CapabilityStatus] {
        LegacyEnvironmentCapabilityAdapter.legacyMap(capabilityStates)
    }

    public init(
        serviceIdentity: String,
        serviceVersion: String,
        protocolVersion: String,
        capabilityStates: [CapabilityIdentifier: CapabilityState],
        supportedPackageFormats: Set<PackageFormatIdentifier>,
        supportedVersionSchemes: Set<String> = [],
        recoveryStrategies: Set<ProviderRecoveryStrategy>,
        sessionBehavior: PackageServiceSessionBehavior
    ) {
        self.serviceIdentity = serviceIdentity
        self.serviceVersion = serviceVersion
        self.protocolVersion = protocolVersion
        self.capabilityStates = capabilityStates
        self.supportedPackageFormats = supportedPackageFormats
        self.supportedVersionSchemes = supportedVersionSchemes
        self.recoveryStrategies = recoveryStrategies
        self.sessionBehavior = sessionBehavior
    }

    /// V1 source-compatibility initializer.
    public init(
        serviceIdentity: String,
        serviceVersion: String,
        protocolVersion: String,
        capabilityReport: [EnvironmentCapability: CapabilityStatus],
        supportedPackageFormats: Set<PackageFormatIdentifier>,
        supportedVersionSchemes: Set<String> = [],
        recoveryStrategies: Set<ProviderRecoveryStrategy>,
        sessionBehavior: PackageServiceSessionBehavior
    ) {
        self.init(
            serviceIdentity: serviceIdentity,
            serviceVersion: serviceVersion,
            protocolVersion: protocolVersion,
            capabilityStates: LegacyEnvironmentCapabilityAdapter.convert(capabilityReport),
            supportedPackageFormats: supportedPackageFormats,
            supportedVersionSchemes: supportedVersionSchemes,
            recoveryStrategies: recoveryStrategies,
            sessionBehavior: sessionBehavior
        )
    }

    private enum CodingKeys: String, CodingKey {
        case serviceIdentity, serviceVersion, protocolVersion, capabilityStates, capabilityReport
        case supportedPackageFormats, supportedVersionSchemes, recoveryStrategies, sessionBehavior
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serviceIdentity = try container.decode(String.self, forKey: .serviceIdentity)
        serviceVersion = try container.decode(String.self, forKey: .serviceVersion)
        protocolVersion = try container.decode(String.self, forKey: .protocolVersion)
        supportedPackageFormats = try container.decode(Set<PackageFormatIdentifier>.self, forKey: .supportedPackageFormats)
        supportedVersionSchemes = try container.decodeIfPresent(Set<String>.self, forKey: .supportedVersionSchemes) ?? []
        recoveryStrategies = try container.decode(Set<ProviderRecoveryStrategy>.self, forKey: .recoveryStrategies)
        sessionBehavior = try container.decode(PackageServiceSessionBehavior.self, forKey: .sessionBehavior)

        if let raw = try container.decodeIfPresent([String: CapabilityState].self, forKey: .capabilityStates) {
            capabilityStates = Dictionary(uniqueKeysWithValues: raw.map { rawID, state in
                let identifier = CapabilityIdentifier(rawValue: rawID)
                return (identifier, CapabilityState(identifier: identifier, availability: state.availability, version: state.version, metadata: state.metadata))
            })
        } else {
            let legacy = try container.decodeIfPresent([EnvironmentCapability: CapabilityStatus].self, forKey: .capabilityReport) ?? [:]
            capabilityStates = LegacyEnvironmentCapabilityAdapter.convert(legacy)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serviceIdentity, forKey: .serviceIdentity)
        try container.encode(serviceVersion, forKey: .serviceVersion)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(Dictionary(uniqueKeysWithValues: capabilityStates.map { ($0.key.rawValue, $0.value) }), forKey: .capabilityStates)
        try container.encode(capabilityReport, forKey: .capabilityReport)
        try container.encode(supportedPackageFormats, forKey: .supportedPackageFormats)
        try container.encode(supportedVersionSchemes, forKey: .supportedVersionSchemes)
        try container.encode(recoveryStrategies, forKey: .recoveryStrategies)
        try container.encode(sessionBehavior, forKey: .sessionBehavior)
    }
}

public struct RelaxinBridgeSession: Codable, Hashable, Sendable {
    public let negotiatedProtocolVersion: String
    public let runtime: RuntimeDescriptor
    public let service: PackageServiceDescriptor

    public init(negotiatedProtocolVersion: String, runtime: RuntimeDescriptor, service: PackageServiceDescriptor) {
        self.negotiatedProtocolVersion = negotiatedProtocolVersion
        self.runtime = runtime
        self.service = service
    }
}
