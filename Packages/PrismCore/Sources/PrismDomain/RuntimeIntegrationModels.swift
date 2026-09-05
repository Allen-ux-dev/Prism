import Foundation

public enum RuntimeIntegrationCapability: String, Codable, Sendable, CaseIterable, Hashable {
    case packageService
    case backgroundExecution
    case serviceRegistration
    case lifecycleRecovery
    case packageStoreAccess
    case repositoryNetworking
    case userspaceRestart
    case appRegistration
    case runtimeDiagnostics
}


public enum RuntimeOperatingMode: String, Codable, Sendable, Equatable, Hashable {
    case modern
    case hybrid
    case legacy
    case readOnly
    case degraded
    case unknown
}

public enum CapabilityAvailability: String, Codable, Sendable, Hashable {
    case available
    case degraded
    case unavailable
    case unknown

    public var isUsable: Bool { self == .available || self == .degraded }
}

public enum PrismIntegrationState: Codable, Sendable, Equatable, Hashable {
    case notInstalled
    case installed
    case registered
    case activating
    case ready
    case degraded(reason: String)
    case repairing
    case recovering
    case disabled
    case incompatible(reason: String)
}

public enum PackageServiceLifecycleState: String, Codable, Sendable, Equatable, Hashable {
    case idle
    case activating
    case active
    case finishing
    case recovering
    case degraded
    case unavailable
}

public enum PrismInstallationOwnership: Codable, Sendable, Equatable, Hashable {
    case standalone
    case runtimeManaged(runtimeID: String)
    case legacyMigrated
    case external(identifier: String)

    public var lifecycleOwnerID: String {
        switch self {
        case .standalone, .legacyMigrated: return "dev.prism"
        case .runtimeManaged(let runtimeID): return runtimeID
        case .external(let identifier): return identifier
        }
    }

    public var isRuntimeManaged: Bool {
        if case .runtimeManaged = self { return true }
        return false
    }
}

public enum PrismInstallationState: Codable, Sendable, Equatable, Hashable {
    case notInstalled
    case installed(version: String, ownership: PrismInstallationOwnership)
    case outdated(currentVersion: String, targetVersion: String, ownership: PrismInstallationOwnership)
    case incompatible(reason: String)
}

public struct PrismInstallRequest: Codable, Sendable, Equatable, Hashable {
    public let targetVersion: String
    public init(targetVersion: String) { self.targetVersion = targetVersion }
}

public struct PrismUpgradeRequest: Codable, Sendable, Equatable, Hashable {
    public let fromVersion: String
    public let targetVersion: String
    public init(fromVersion: String, targetVersion: String) {
        self.fromVersion = fromVersion
        self.targetVersion = targetVersion
    }
}

public struct PrismInstallationReceipt: Codable, Sendable, Equatable, Hashable {
    public let installedVersion: String
    public let ownership: PrismInstallationOwnership
    public let receiptID: UUID
    public init(installedVersion: String, ownership: PrismInstallationOwnership, receiptID: UUID = UUID()) {
        self.installedVersion = installedVersion
        self.ownership = ownership
        self.receiptID = receiptID
    }
}

public struct PrismRepairResult: Codable, Sendable, Equatable, Hashable {
    public let state: PrismIntegrationState
    public let repairedComponents: [String]
    public init(state: PrismIntegrationState, repairedComponents: [String] = []) {
        self.state = state
        self.repairedComponents = repairedComponents
    }
}

public extension RuntimeIntegrationCapability {
    var identifier: CapabilityIdentifier { LegacyCapabilityAdapter.convert(self) }

    static var requiredForManagedLifecycle: [RuntimeIntegrationCapability: CapabilityAvailability] {
        [
            .packageService: .available,
            .backgroundExecution: .available,
            .serviceRegistration: .available,
            .lifecycleRecovery: .available
        ]
    }
}
