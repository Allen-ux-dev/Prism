import Foundation

public struct PrismProtocolVersion: Codable, Sendable, Equatable, Hashable {
    public let current: Int
    public let minimumCompatible: Int

    public init(current: Int, minimumCompatible: Int) {
        precondition(current > 0)
        precondition(minimumCompatible > 0 && minimumCompatible <= current)
        self.current = current
        self.minimumCompatible = minimumCompatible
    }

    public var supportedRange: ClosedRange<Int> { minimumCompatible...current }
}

public enum PrismContractVersions {
    public static let runtimeIntegration = PrismProtocolVersion(current: 2, minimumCompatible: 1)
    public static let packageService = PrismProtocolVersion(current: 1, minimumCompatible: 1)
    public static let repositoryProvider = PrismProtocolVersion(current: 2, minimumCompatible: 1)

    public static let transactionJournalSchema = 3
    public static let environmentSchema = 1
    public static let capabilitySchema = 2
    public static let providerStateSchema = 1
}

public enum RuntimeProtocolNegotiationError: Error, Equatable, Sendable {
    case incompatible(runtime: ClosedRange<Int>, prism: ClosedRange<Int>)
}

public enum RuntimeProtocolNegotiator {
    public static func negotiate(runtime: ClosedRange<Int>, prism: ClosedRange<Int>) throws -> Int {
        let lower = max(runtime.lowerBound, prism.lowerBound)
        let upper = min(runtime.upperBound, prism.upperBound)
        guard lower <= upper else {
            throw RuntimeProtocolNegotiationError.incompatible(runtime: runtime, prism: prism)
        }
        return upper
    }
}

public struct RuntimeHandshake: Codable, Sendable, Equatable {
    public let protocolVersion: Int
    public let minimumCompatibleVersion: Int
    public let runtimeIdentity: String
    public let runtimeVersion: String
    public let prismVersion: String
    public let packageServiceVersion: Int
    public let capabilityStates: [CapabilityIdentifier: CapabilityState]
    public let optionalFeatures: Set<String>

    /// V1 compatibility view. Unknown V2 capability identifiers intentionally do not appear here.
    public var capabilities: [RuntimeIntegrationCapability: CapabilityAvailability] {
        LegacyCapabilityAdapter.legacyMap(capabilityStates)
    }

    public init(
        protocolVersion: Int,
        minimumCompatibleVersion: Int,
        runtimeIdentity: String,
        runtimeVersion: String,
        prismVersion: String,
        packageServiceVersion: Int,
        capabilityStates: [CapabilityIdentifier: CapabilityState],
        optionalFeatures: Set<String> = []
    ) {
        self.protocolVersion = protocolVersion
        self.minimumCompatibleVersion = minimumCompatibleVersion
        self.runtimeIdentity = runtimeIdentity
        self.runtimeVersion = runtimeVersion
        self.prismVersion = prismVersion
        self.packageServiceVersion = packageServiceVersion
        self.capabilityStates = capabilityStates
        self.optionalFeatures = optionalFeatures
    }

    /// V1 source-compatibility initializer.
    public init(
        protocolVersion: Int,
        minimumCompatibleVersion: Int,
        runtimeIdentity: String,
        runtimeVersion: String,
        prismVersion: String,
        packageServiceVersion: Int,
        capabilities: [RuntimeIntegrationCapability: CapabilityAvailability],
        optionalFeatures: Set<String> = []
    ) {
        self.init(
            protocolVersion: protocolVersion,
            minimumCompatibleVersion: minimumCompatibleVersion,
            runtimeIdentity: runtimeIdentity,
            runtimeVersion: runtimeVersion,
            prismVersion: prismVersion,
            packageServiceVersion: packageServiceVersion,
            capabilityStates: LegacyCapabilityAdapter.convert(capabilities),
            optionalFeatures: optionalFeatures
        )
    }

    private enum CodingKeys: String, CodingKey {
        case protocolVersion, minimumCompatibleVersion, runtimeIdentity, runtimeVersion
        case prismVersion, packageServiceVersion, capabilities, capabilityStates, optionalFeatures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try container.decode(Int.self, forKey: .protocolVersion)
        minimumCompatibleVersion = try container.decode(Int.self, forKey: .minimumCompatibleVersion)
        runtimeIdentity = try container.decode(String.self, forKey: .runtimeIdentity)
        runtimeVersion = try container.decode(String.self, forKey: .runtimeVersion)
        prismVersion = try container.decode(String.self, forKey: .prismVersion)
        packageServiceVersion = try container.decode(Int.self, forKey: .packageServiceVersion)
        optionalFeatures = try container.decodeIfPresent(Set<String>.self, forKey: .optionalFeatures) ?? []

        if let rawStates = try container.decodeIfPresent([String: CapabilityState].self, forKey: .capabilityStates) {
            capabilityStates = Dictionary(uniqueKeysWithValues: rawStates.map { rawKey, state in
                let identifier = CapabilityIdentifier(rawValue: rawKey)
                let normalized = CapabilityState(
                    identifier: identifier,
                    availability: state.availability,
                    version: state.version,
                    metadata: state.metadata
                )
                return (identifier, normalized)
            })
        } else {
            let rawCapabilities = try container.decodeIfPresent([String: CapabilityAvailability].self, forKey: .capabilities) ?? [:]
            capabilityStates = Dictionary(uniqueKeysWithValues: rawCapabilities.map { rawKey, availability in
                let legacyIdentifier: CapabilityIdentifier
                if let legacy = RuntimeIntegrationCapability(rawValue: rawKey) {
                    legacyIdentifier = LegacyCapabilityAdapter.convert(legacy)
                } else {
                    // Preserve unknown V1-style string keys instead of dropping them.
                    legacyIdentifier = CapabilityIdentifier(rawValue: rawKey)
                }
                return (legacyIdentifier, CapabilityState(identifier: legacyIdentifier, availability: availability))
            })
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(minimumCompatibleVersion, forKey: .minimumCompatibleVersion)
        try container.encode(runtimeIdentity, forKey: .runtimeIdentity)
        try container.encode(runtimeVersion, forKey: .runtimeVersion)
        try container.encode(prismVersion, forKey: .prismVersion)
        try container.encode(packageServiceVersion, forKey: .packageServiceVersion)
        let rawStates = Dictionary(uniqueKeysWithValues: capabilityStates.map { ($0.key.rawValue, $0.value) })
        try container.encode(rawStates, forKey: .capabilityStates)
        // V1 runtimes can still inspect known capabilities when they decode a compatible envelope.
        let legacy = LegacyCapabilityAdapter.legacyMap(capabilityStates)
        let rawLegacy = Dictionary(uniqueKeysWithValues: legacy.map { ($0.key.rawValue, $0.value) })
        try container.encode(rawLegacy, forKey: .capabilities)
        try container.encode(optionalFeatures, forKey: .optionalFeatures)
    }

    public var supportedRuntimeRange: ClosedRange<Int> {
        minimumCompatibleVersion...protocolVersion
    }
}
