import Foundation
import PrismDomain

/// V1 environment capability adapter. The enum remains decodable for legacy runtimes,
/// while new contracts store arbitrary `CapabilityIdentifier` values.
public enum LegacyEnvironmentCapabilityAdapter {
    public static func convert(_ legacy: EnvironmentCapability) -> CapabilityIdentifier {
        switch legacy {
        case .appInstall, .ipaInstall: return .appInstall
        case .appRegistration: return .appRegistration
        case .appReplace: return .appReplace
        case .appRemoval: return .appRemoval
        case .appRefresh: return .appRefresh
        case .appInjection: return .appInjection
        case .dylibInjection: return .dylibInjection
        case .frameworkInjection: return .frameworkInjection
        case .bundleInjection: return .bundleInjection
        default: return .legacyEnvironment(legacy.rawValue)
        }
    }

    public static func legacyCapability(for identifier: CapabilityIdentifier) -> EnvironmentCapability? {
        switch identifier {
        case .appInstall: return .appInstall
        case .appRegistration: return .appRegistration
        case .appReplace: return .appReplace
        case .appRemoval: return .appRemoval
        case .appRefresh: return .appRefresh
        case .appInjection: return .appInjection
        case .dylibInjection: return .dylibInjection
        case .frameworkInjection: return .frameworkInjection
        case .bundleInjection: return .bundleInjection
        default:
            let prefix = "dev.prism.capability.environment."
            guard identifier.rawValue.hasPrefix(prefix) else { return nil }
            return EnvironmentCapability(rawValue: String(identifier.rawValue.dropFirst(prefix.count)))
        }
    }

    public static func convert(
        _ report: [EnvironmentCapability: CapabilityStatus]
    ) -> [CapabilityIdentifier: CapabilityState] {
        var result: [CapabilityIdentifier: CapabilityState] = [:]
        for (capability, status) in report.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let identifier = convert(capability)
            let candidate = CapabilityState(
                identifier: identifier,
                availability: availability(status),
                metadata: status.reason.map { ["reason": $0] } ?? [:]
            )
            if let existing = result[identifier] {
                result[identifier] = preferred(existing, candidate)
            } else {
                result[identifier] = candidate
            }
        }
        return result
    }

    public static func legacyMap(
        _ states: [CapabilityIdentifier: CapabilityState]
    ) -> [EnvironmentCapability: CapabilityStatus] {
        Dictionary(uniqueKeysWithValues: states.compactMap { identifier, state in
            guard let capability = legacyCapability(for: identifier) else { return nil }
            let reason = state.metadata["reason"]
            let status: CapabilityStatus
            switch state.availability {
            case .available: status = .available
            case .degraded: status = .degraded(reason ?? "degraded")
            case .unavailable: status = .unavailable
            case .unknown: status = .unknown(reason)
            }
            return (capability, status)
        })
    }


    private static func preferred(_ lhs: CapabilityState, _ rhs: CapabilityState) -> CapabilityState {
        let lhsRank = availabilityRank(lhs.availability)
        let rhsRank = availabilityRank(rhs.availability)
        if lhsRank != rhsRank { return lhsRank > rhsRank ? lhs : rhs }
        let lhsReason = lhs.metadata["reason"] ?? ""
        let rhsReason = rhs.metadata["reason"] ?? ""
        return lhsReason <= rhsReason ? lhs : rhs
    }

    private static func availabilityRank(_ availability: CapabilityAvailability) -> Int {
        switch availability {
        case .available: return 3
        case .degraded: return 2
        case .unavailable: return 1
        case .unknown: return 0
        }
    }

    private static func availability(_ status: CapabilityStatus) -> CapabilityAvailability {
        switch status {
        case .available: return .available
        case .degraded: return .degraded
        case .unavailable: return .unavailable
        case .unknown: return .unknown
        }
    }
}
