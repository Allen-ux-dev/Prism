import Foundation
import PrismDomain
import PrismEnvironment

public struct RuntimeNormalPresentation: Sendable, Hashable {
    public let runtime: String
    public let packageService: String
    public let compatibility: String
    public let background: String

    public init(runtime: String, packageService: String, compatibility: String, background: String) {
        self.runtime = runtime
        self.packageService = packageService
        self.compatibility = compatibility
        self.background = background
    }
}

public struct RuntimeFeatureAvailability: Sendable, Hashable {
    public let packageManagement: Bool
    public let appInstallation: Bool
    public let appInjection: Bool

    public init(packageManagement: Bool, appInstallation: Bool, appInjection: Bool) {
        self.packageManagement = packageManagement
        self.appInstallation = appInstallation
        self.appInjection = appInjection
    }
}

public struct RuntimeIsolationPolicy: Sendable {
    public init() {}

    public func runtimePresentation(
        environment: PrismEnvironment,
        mode: RuntimeOperatingMode,
        backgroundActive: Bool
    ) -> RuntimeNormalPresentation {
        let runtime = environment.runtimeDisplayName?.isEmpty == false
            ? environment.runtimeDisplayName!
            : (environment.runtimeIdentity.isEmpty ? "Runtime unavailable" : environment.runtimeIdentity)
        let packageStatus = environment.status(of: .packageInstall)
        let packageService: String
        switch packageStatus {
        case .available: packageService = "Ready"
        case .degraded: packageService = "Degraded"
        case .unavailable: packageService = "Unavailable"
        case .unknown: packageService = "Checking"
        }
        return RuntimeNormalPresentation(
            runtime: runtime,
            packageService: packageService,
            compatibility: compatibilityLabel(mode),
            background: backgroundActive ? "Active" : "Idle"
        )
    }

    /// V1 source-compatibility overload. Provider selection mode is not a presentation contract anymore.
    public func normalPresentation(
        environment: PrismEnvironment,
        mode: PrismOperatingMode,
        backgroundActive: Bool
    ) -> RuntimeNormalPresentation {
        let runtimeMode: RuntimeOperatingMode
        switch mode {
        case .modern: runtimeMode = .modern
        case .hybrid: runtimeMode = .hybrid
        case .legacy: runtimeMode = .legacy
        }
        return runtimePresentation(environment: environment, mode: runtimeMode, backgroundActive: backgroundActive)
    }

    public func compatibilityLabel(_ mode: RuntimeOperatingMode) -> String {
        switch mode {
        case .modern: return "Modern"
        case .hybrid: return "Hybrid"
        case .legacy: return "Legacy compatibility"
        case .readOnly: return "Read-only"
        case .degraded: return "Degraded"
        case .unknown: return "Unknown"
        }
    }

    public func featureAvailability(providerHealth: [ProviderKind: ProviderHealth]) -> RuntimeFeatureAvailability {
        func usable(_ kind: ProviderKind) -> Bool { providerHealth[kind]?.isUsable ?? false }
        return RuntimeFeatureAvailability(
            packageManagement: usable(.packageService),
            appInstallation: usable(.appInstallation),
            appInjection: usable(.appInjection)
        )
    }

    public func coalescedWarnings(_ warnings: [String]) -> [String] {
        var seen: Set<String> = []
        return warnings.compactMap { warning in
            let normalized = warning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }

    public func redactedAdvancedValue(_ value: String) -> String {
        guard value.contains("/") else { return value }
        let last = URL(fileURLWithPath: value).lastPathComponent
        return last.isEmpty ? "<provider-private-path>" : "…/\(last)"
    }
}
