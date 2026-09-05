public enum CompatibilityLevel: String, Codable, Sendable, Equatable, Hashable {
    case compatible
    case partiallyCompatible
    case degraded
    case unsupported
    case unknown
}

public struct PrismCompatibilityProfile: Codable, Sendable, Equatable, Hashable {
    public let runtimeCompatibility: CompatibilityLevel
    public let osCompatibility: CompatibilityLevel
    public let architectureCompatibility: CompatibilityLevel
    public let packageFormatCompatibility: CompatibilityLevel
    public let providerCompatibility: CompatibilityLevel
    public let requiredCapabilityRequirements: [CapabilityRequirement]
    public let optionalCapabilityRequirements: [CapabilityRequirement]

    public init(
        runtimeCompatibility: CompatibilityLevel,
        osCompatibility: CompatibilityLevel,
        architectureCompatibility: CompatibilityLevel,
        packageFormatCompatibility: CompatibilityLevel,
        providerCompatibility: CompatibilityLevel,
        requiredCapabilityRequirements: [CapabilityRequirement] = [],
        optionalCapabilityRequirements: [CapabilityRequirement] = []
    ) {
        self.runtimeCompatibility = runtimeCompatibility
        self.osCompatibility = osCompatibility
        self.architectureCompatibility = architectureCompatibility
        self.packageFormatCompatibility = packageFormatCompatibility
        self.providerCompatibility = providerCompatibility
        self.requiredCapabilityRequirements = requiredCapabilityRequirements
        self.optionalCapabilityRequirements = optionalCapabilityRequirements
    }

    /// V1 source compatibility. New code should use typed capability requirements.
    public init(
        runtimeCompatibility: CompatibilityLevel,
        osCompatibility: CompatibilityLevel,
        architectureCompatibility: CompatibilityLevel,
        packageFormatCompatibility: CompatibilityLevel,
        providerCompatibility: CompatibilityLevel,
        requiredCapabilities: Set<String>,
        optionalCapabilities: Set<String>
    ) {
        self.init(
            runtimeCompatibility: runtimeCompatibility,
            osCompatibility: osCompatibility,
            architectureCompatibility: architectureCompatibility,
            packageFormatCompatibility: packageFormatCompatibility,
            providerCompatibility: providerCompatibility,
            requiredCapabilityRequirements: requiredCapabilities.sorted().map {
                .init(identifier: .legacyEnvironment($0), required: true)
            },
            optionalCapabilityRequirements: optionalCapabilities.sorted().map {
                .init(identifier: .legacyEnvironment($0), required: false)
            }
        )
    }

    public var requiredCapabilities: Set<String> {
        Set(requiredCapabilityRequirements.map { legacyName(for: $0.identifier) })
    }

    public var optionalCapabilities: Set<String> {
        Set(optionalCapabilityRequirements.map { legacyName(for: $0.identifier) })
    }

    private func legacyName(for identifier: CapabilityIdentifier) -> String {
        let prefix = "dev.prism.capability.environment."
        if identifier.rawValue.hasPrefix(prefix) {
            return String(identifier.rawValue.dropFirst(prefix.count))
        }
        return identifier.rawValue
    }

    public var overallLevel: CompatibilityLevel {
        let levels = [runtimeCompatibility, osCompatibility, architectureCompatibility, packageFormatCompatibility, providerCompatibility]
        if levels.contains(.unsupported) { return .unsupported }
        if levels.contains(.degraded) { return .degraded }
        if levels.contains(.partiallyCompatible) { return .partiallyCompatible }
        if levels.contains(.unknown) { return .unknown }
        return .compatible
    }
}
