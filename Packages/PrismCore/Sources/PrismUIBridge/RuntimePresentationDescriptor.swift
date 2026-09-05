import PrismDomain
import PrismEnvironment

public struct RuntimePresentationDescriptor: Sendable, Hashable {
    public let displayName: String
    public let runtimeIdentity: String
    public let runtimeVersion: String?
    public let operatingMode: RuntimeOperatingMode
    public let compatibilityLevel: CompatibilityLevel

    public init(
        displayName: String,
        runtimeIdentity: String,
        runtimeVersion: String?,
        operatingMode: RuntimeOperatingMode,
        compatibilityLevel: CompatibilityLevel
    ) {
        self.displayName = displayName
        self.runtimeIdentity = runtimeIdentity
        self.runtimeVersion = runtimeVersion
        self.operatingMode = operatingMode
        self.compatibilityLevel = compatibilityLevel
    }

    public static func derive(
        environment: PrismEnvironment,
        serviceDescriptor: PrismProviderDescriptor?,
        serviceHealth: ProviderHealth?
    ) -> Self {
        let identity = environment.runtimeIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName: String
        if let supplied = environment.runtimeDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !supplied.isEmpty {
            displayName = supplied
        } else if !identity.isEmpty && identity != "unknown" {
            displayName = identity
        } else {
            displayName = "Runtime unavailable"
        }

        let operatingMode: RuntimeOperatingMode
        let compatibility: CompatibilityLevel

        if serviceDescriptor == nil {
            operatingMode = .readOnly
            compatibility = .partiallyCompatible
        } else if let serviceHealth {
            switch serviceHealth {
            case .unavailable:
                operatingMode = .degraded
                compatibility = .degraded
            case .unknown:
                operatingMode = .unknown
                compatibility = .unknown
            case .degraded:
                operatingMode = .degraded
                compatibility = .degraded
            case .healthy:
                (operatingMode, compatibility) = healthyMode(environment: environment, descriptor: serviceDescriptor!)
            }
        } else {
            (operatingMode, compatibility) = healthyMode(environment: environment, descriptor: serviceDescriptor!)
        }

        return .init(
            displayName: displayName,
            runtimeIdentity: identity,
            runtimeVersion: environment.runtimeVersion,
            operatingMode: operatingMode,
            compatibilityLevel: compatibility
        )
    }

    private static func healthyMode(
        environment: PrismEnvironment,
        descriptor: PrismProviderDescriptor
    ) -> (RuntimeOperatingMode, CompatibilityLevel) {
        if let declared = environment.runtimeOperatingMode {
            switch declared {
            case .readOnly: return (.readOnly, .partiallyCompatible)
            case .degraded: return (.degraded, .degraded)
            case .unknown: return (.unknown, .unknown)
            case .modern, .hybrid, .legacy: return (declared, .compatible)
            }
        }
        let modes = descriptor.operatingModes
        if modes.contains(.modern) {
            if environment.legacy != nil && modes.contains(.hybrid) {
                return (.hybrid, .compatible)
            }
            return (.modern, .compatible)
        }
        if modes.contains(.legacy) {
            return (.legacy, .compatible)
        }
        if modes.contains(.hybrid) {
            return (.hybrid, .compatible)
        }
        return (.unknown, .unknown)
    }
}
