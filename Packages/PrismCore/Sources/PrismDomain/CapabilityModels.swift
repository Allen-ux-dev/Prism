import Foundation

public struct CapabilityIdentifier: RawRepresentable, Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public static let packageService = Self(rawValue: "dev.prism.capability.package-service")
    public static let backgroundExecution = Self(rawValue: "dev.prism.capability.background-execution")
    public static let privilegedService = Self(rawValue: "dev.prism.capability.privileged-service")
    public static let serviceRegistration = Self(rawValue: "dev.prism.capability.service-registration")
    public static let lifecycleRecovery = Self(rawValue: "dev.prism.capability.lifecycle-recovery")
    public static let packageStoreAccess = Self(rawValue: "dev.prism.capability.package-store-access")
    public static let repositoryNetworking = Self(rawValue: "dev.prism.capability.repository-networking")
    public static let appInstall = Self(rawValue: "dev.prism.capability.app-install")
    public static let appRegistration = Self(rawValue: "dev.prism.capability.app-registration")
    public static let appReplace = Self(rawValue: "dev.prism.capability.app-replace")
    public static let appRemoval = Self(rawValue: "dev.prism.capability.app-removal")
    public static let appRefresh = Self(rawValue: "dev.prism.capability.app-refresh")
    public static let appInjection = Self(rawValue: "dev.prism.capability.app-injection")
    public static let dylibInjection = Self(rawValue: "dev.prism.capability.dylib-injection")
    public static let frameworkInjection = Self(rawValue: "dev.prism.capability.framework-injection")
    public static let bundleInjection = Self(rawValue: "dev.prism.capability.bundle-injection")
    public static let userspaceRestart = Self(rawValue: "dev.prism.capability.userspace-restart")
    public static let runtimeDiagnostics = Self(rawValue: "dev.prism.capability.runtime-diagnostics")

    /// Namespaces legacy package-service capabilities without making them part of the frozen runtime enum.
    public static func legacyEnvironment(_ rawValue: String) -> Self {
        Self(rawValue: "dev.prism.capability.environment.\(rawValue)")
    }
}

public struct CapabilityState: Codable, Hashable, Sendable {
    public let identifier: CapabilityIdentifier
    public let availability: CapabilityAvailability
    public let version: Int?
    public let metadata: [String: String]

    public init(
        identifier: CapabilityIdentifier,
        availability: CapabilityAvailability,
        version: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.availability = availability
        self.version = version
        self.metadata = metadata
    }
}

public struct CapabilityRequirement: Codable, Hashable, Sendable {
    public let identifier: CapabilityIdentifier
    public let minimumVersion: Int?
    public let required: Bool

    public init(identifier: CapabilityIdentifier, minimumVersion: Int? = nil, required: Bool = true) {
        self.identifier = identifier
        self.minimumVersion = minimumVersion
        self.required = required
    }
}

public struct CapabilityRequirementEvaluation: Codable, Hashable, Sendable {
    public let missingRequired: [CapabilityIdentifier]
    public let missingOptional: [CapabilityIdentifier]

    public init(missingRequired: [CapabilityIdentifier], missingOptional: [CapabilityIdentifier]) {
        self.missingRequired = missingRequired.sorted()
        self.missingOptional = missingOptional.sorted()
    }

    public var isCompatible: Bool { missingRequired.isEmpty }
}

public enum CapabilityRequirementEvaluator {
    public static func evaluate(
        _ requirements: [CapabilityRequirement],
        against states: [CapabilityIdentifier: CapabilityState]
    ) -> CapabilityRequirementEvaluation {
        var required: [CapabilityIdentifier] = []
        var optional: [CapabilityIdentifier] = []

        for requirement in requirements {
            let state = states[requirement.identifier]
            let usable: Bool
            if let state {
                let availabilityUsable = state.availability == .available || state.availability == .degraded
                let versionUsable: Bool
                if let minimum = requirement.minimumVersion {
                    versionUsable = (state.version ?? -1) >= minimum
                } else {
                    versionUsable = true
                }
                usable = availabilityUsable && versionUsable
            } else {
                usable = false
            }

            guard !usable else { continue }
            if requirement.required { required.append(requirement.identifier) }
            else { optional.append(requirement.identifier) }
        }

        return .init(missingRequired: required, missingOptional: optional)
    }
}

public enum LegacyCapabilityAdapter {
    public static func convert(_ legacy: RuntimeIntegrationCapability) -> CapabilityIdentifier {
        switch legacy {
        case .packageService: return .packageService
        case .backgroundExecution: return .backgroundExecution
        case .serviceRegistration: return .serviceRegistration
        case .lifecycleRecovery: return .lifecycleRecovery
        case .packageStoreAccess: return .packageStoreAccess
        case .repositoryNetworking: return .repositoryNetworking
        case .userspaceRestart: return .userspaceRestart
        case .appRegistration: return .appRegistration
        case .runtimeDiagnostics: return .runtimeDiagnostics
        }
    }

    public static func convert(
        _ legacy: [RuntimeIntegrationCapability: CapabilityAvailability]
    ) -> [CapabilityIdentifier: CapabilityState] {
        Dictionary(uniqueKeysWithValues: legacy.map { capability, availability in
            let identifier = convert(capability)
            return (identifier, CapabilityState(identifier: identifier, availability: availability))
        })
    }

    public static func legacyCapability(for identifier: CapabilityIdentifier) -> RuntimeIntegrationCapability? {
        RuntimeIntegrationCapability.allCases.first { convert($0) == identifier }
    }

    public static func legacyMap(
        _ states: [CapabilityIdentifier: CapabilityState]
    ) -> [RuntimeIntegrationCapability: CapabilityAvailability] {
        Dictionary(uniqueKeysWithValues: states.compactMap { identifier, state in
            guard let capability = legacyCapability(for: identifier) else { return nil }
            return (capability, state.availability)
        })
    }
}

public extension CapabilityRequirement {
    static let managedRuntimeLifecycle: [CapabilityRequirement] = [
        .init(identifier: .packageService),
        .init(identifier: .backgroundExecution),
        .init(identifier: .serviceRegistration),
        .init(identifier: .lifecycleRecovery)
    ]
}
