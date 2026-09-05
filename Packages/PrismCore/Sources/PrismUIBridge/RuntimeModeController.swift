import Foundation
import PrismDomain

public struct RuntimeComponentIdentifier: RawRepresentable, Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public static let packageService = Self(rawValue: "package-service")
    public static let legacyCompatibility = Self(rawValue: "legacy-compatibility")
    public static let sourceBuild = Self(rawValue: "source-build")
    public static let appInjection = Self(rawValue: "app-injection")
    public static let diagnostics = Self(rawValue: "diagnostics")
}

public enum RuntimeComponentState: String, Codable, Hashable, Sendable {
    case idle
    case activating
    case active
    case degraded
}

public actor RuntimeModeController {
    public private(set) var mode: PrismOperatingMode
    private var states: [RuntimeComponentIdentifier: RuntimeComponentState]

    public init(mode: PrismOperatingMode = .modern) {
        self.mode = mode
        self.states = [:]
    }

    public func setMode(_ mode: PrismOperatingMode) {
        self.mode = mode
        if mode == .modern {
            states[.legacyCompatibility] = .idle
        }
    }

    public func activate(_ component: RuntimeComponentIdentifier) {
        states[component] = .active
    }

    public func markDegraded(_ component: RuntimeComponentIdentifier) {
        states[component] = .degraded
    }

    public func returnToIdle(_ component: RuntimeComponentIdentifier) {
        states[component] = .idle
    }

    public func state(of component: RuntimeComponentIdentifier) -> RuntimeComponentState {
        states[component] ?? .idle
    }

    public func isActive(_ component: RuntimeComponentIdentifier) -> Bool {
        let state = states[component] ?? .idle
        return state == .active || state == .degraded
    }
}
