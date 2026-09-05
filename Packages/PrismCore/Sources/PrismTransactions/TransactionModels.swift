import Foundation
import PrismDomain
import PrismResolution

public enum TransactionPhase: String, Codable, Sendable, Hashable {
    case created, preparing, resolving, ready, executing, reconciling, completed, failed, interrupted, cancelled, needsRecovery, rollingBack, rolledBack, needsReview
}

public struct PackageInstallOperation: Codable, Sendable, Hashable {
    public let packageIdentifier: String
    public let version: PackageVersion
    public init(packageIdentifier: String, version: PackageVersion) { self.packageIdentifier = packageIdentifier; self.version = version }
    public init(packageIdentifier: String, version: DebianVersion) { self.init(packageIdentifier: packageIdentifier, version: PackageVersion(version)) }
}

public struct AppArtifactReference: Codable, Sendable, Hashable {
    public let stagingIdentifier: String
    public let sha256: String?

    public init(stagingIdentifier: String, sha256: String? = nil) {
        self.stagingIdentifier = stagingIdentifier
        self.sha256 = sha256
    }
}

public struct AppInstallOperation: Codable, Sendable, Hashable {
    public let bundleIdentifier: String
    public let displayName: String
    public let version: String?
    public let artifact: AppArtifactReference?

    public init(
        bundleIdentifier: String,
        displayName: String,
        version: String? = nil,
        artifact: AppArtifactReference? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.version = version
        self.artifact = artifact
    }
}

public struct InjectionOperation: Codable, Sendable, Hashable {
    public let targetBundleIdentifier: String
    public let artifact: InjectionArtifact
    public init(targetBundleIdentifier: String, artifact: InjectionArtifact) { self.targetBundleIdentifier = targetBundleIdentifier; self.artifact = artifact }
}

public enum TransactionOperation: Codable, Sendable, Hashable {
    case installPackage(PackageInstallOperation)
    case upgradePackage(PackageInstallOperation)
    case removePackage(String)
    case purgePackage(String)
    case installApp(AppInstallOperation)
    case replaceApp(AppInstallOperation)
    case removeApp(String)
    case registerApp(String)
    case refreshApp(String)
    case applyInjection(InjectionOperation)
    case removeInjection(targetBundleIdentifier: String, artifactIdentifier: String)

    public var stableID: String {
        switch self {
        case .installPackage(let op): return "pkg-install:\(op.packageIdentifier):\(op.version.rawValue)"
        case .upgradePackage(let op): return "pkg-upgrade:\(op.packageIdentifier):\(op.version.rawValue)"
        case .removePackage(let id): return "pkg-remove:\(id)"
        case .purgePackage(let id): return "pkg-purge:\(id)"
        case .installApp(let op): return "app-install:\(op.bundleIdentifier)"
        case .replaceApp(let op): return "app-replace:\(op.bundleIdentifier)"
        case .removeApp(let id): return "app-remove:\(id)"
        case .registerApp(let id): return "app-register:\(id)"
        case .refreshApp(let id): return "app-refresh:\(id)"
        case .applyInjection(let op): return "inject:\(op.targetBundleIdentifier):\(op.artifact.identifier)"
        case .removeInjection(let target, let artifact): return "inject-remove:\(target):\(artifact)"
        }
    }
}

public struct PrismTransaction: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let operations: [TransactionOperation]
    public var phase: TransactionPhase
    public var completedOperationIDs: Set<String>
    public let createdAt: Date
    public var updatedAt: Date
    public var failureMessage: String?

    public init(id: UUID = UUID(), operations: [TransactionOperation], phase: TransactionPhase = .created,
                completedOperationIDs: Set<String> = [], createdAt: Date = Date(), updatedAt: Date = Date(), failureMessage: String? = nil) {
        self.id = id; self.operations = operations; self.phase = phase; self.completedOperationIDs = completedOperationIDs
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.failureMessage = failureMessage
    }

    public static func from(removalPlan: PackageRemovalPlan) -> PrismTransaction {
        let operations = removalPlan.packagesToRemove.map { package in
            switch removalPlan.mode {
            case .remove: return TransactionOperation.removePackage(package.identifier)
            case .purge: return TransactionOperation.purgePackage(package.identifier)
            }
        }
        return PrismTransaction(operations: operations)
    }

    public static func from(installPlan: InstallPlan) -> PrismTransaction {
        let installs = installPlan.installs.map { TransactionOperation.installPackage(.init(packageIdentifier: $0.identifier, version: $0.version)) }
        let upgrades = installPlan.upgrades.map { TransactionOperation.upgradePackage(.init(packageIdentifier: $0.package.identifier, version: $0.package.version)) }
        let removes = installPlan.removals.map { TransactionOperation.removePackage($0.identifier) }
        return PrismTransaction(operations: installs + upgrades + removes)
    }
}

public enum TransactionStateError: Error, Equatable { case invalidTransition(from: TransactionPhase, to: TransactionPhase) }

public struct TransactionStateMachine: Sendable {
    public init() {}
    public func transition(_ transaction: PrismTransaction, to next: TransactionPhase) throws -> PrismTransaction {
        let allowed: [TransactionPhase: Set<TransactionPhase>] = [
            .created: [.preparing, .cancelled],
            .preparing: [.resolving, .failed, .interrupted, .cancelled],
            .resolving: [.ready, .failed, .interrupted, .needsReview, .cancelled],
            .ready: [.executing, .interrupted, .cancelled],
            .executing: [.reconciling, .failed, .interrupted, .needsRecovery],
            .reconciling: [.completed, .failed, .interrupted, .needsRecovery, .needsReview],
            .interrupted: [.reconciling, .needsRecovery, .needsReview, .rollingBack, .failed],
            .needsRecovery: [.reconciling, .rollingBack, .needsReview, .failed],
            .rollingBack: [.rolledBack, .failed, .needsReview],
            .needsReview: [.rollingBack, .cancelled],
            .completed: [], .failed: [], .cancelled: [], .rolledBack: []
        ]
        guard allowed[transaction.phase, default: []].contains(next) else { throw TransactionStateError.invalidTransition(from: transaction.phase, to: next) }
        var copy = transaction; copy.phase = next; copy.updatedAt = Date(); return copy
    }
}
