import Foundation
import PrismDomain
import PrismResolution

public struct InjectionStateKey: Codable, Sendable, Hashable {
    public let bundleIdentifier: String
    public let artifactIdentifier: String
    public init(bundleIdentifier: String, artifactIdentifier: String) { self.bundleIdentifier = bundleIdentifier; self.artifactIdentifier = artifactIdentifier }
}

public struct ApplicationStateSnapshot: Codable, Sendable, Equatable {
    public let installedApps: [String: PrismInstalledApp]
    public let registeredBundleIdentifiers: Set<String>
    public let activeInjections: Set<InjectionStateKey>
    public init(installedApps: [String: PrismInstalledApp] = [:], registeredBundleIdentifiers: Set<String> = [], activeInjections: Set<InjectionStateKey> = []) {
        self.installedApps = installedApps; self.registeredBundleIdentifiers = registeredBundleIdentifiers; self.activeInjections = activeInjections
    }
}

public struct BackendOperationResult: Codable, Sendable, Equatable {
    public let operationID: String
    public let message: String
    public init(operationID: String, message: String = "OK") { self.operationID = operationID; self.message = message }
}

public protocol PackageExecutionBackend: Sendable {
    func inspectPackageState() async throws -> PackageStateSnapshot
    func inspectApplicationState() async throws -> ApplicationStateSnapshot
    func execute(_ operation: TransactionOperation) async throws -> BackendOperationResult
}

public actor MockPackageExecutionBackend: PackageExecutionBackend {
    private var packageState: PackageStateSnapshot
    private var appState: ApplicationStateSnapshot
    private var executionCounts: [String: Int] = [:]

    public init(packageState: PackageStateSnapshot = .init(installedVersions: [:]), appState: ApplicationStateSnapshot = .init()) {
        self.packageState = packageState; self.appState = appState
    }
    public func inspectPackageState() async throws -> PackageStateSnapshot { packageState }
    public func inspectApplicationState() async throws -> ApplicationStateSnapshot { appState }
    public func executionCount(for operationID: String) -> Int { executionCounts[operationID, default: 0] }

    public func replaceState(packages: PackageStateSnapshot, applications: ApplicationStateSnapshot) {
        packageState = packages
        appState = applications
    }

    public func execute(_ operation: TransactionOperation) async throws -> BackendOperationResult {
        executionCounts[operation.stableID, default: 0] += 1
        var versions = packageState.installedVersions
        switch operation {
        case .installPackage(let op), .upgradePackage(let op): versions[op.packageIdentifier] = op.version
        case .removePackage(let id), .purgePackage(let id): versions.removeValue(forKey: id)
        case .installApp(let op), .replaceApp(let op):
            var apps = appState.installedApps
            apps[op.bundleIdentifier] = PrismInstalledApp(
                bundleIdentifier: op.bundleIdentifier,
                displayName: op.displayName,
                version: op.version ?? apps[op.bundleIdentifier]?.version ?? "1.0",
                architecture: apps[op.bundleIdentifier]?.architecture ?? "arm64",
                installationSource: .prism,
                registrationState: .unregistered
            )
            appState = ApplicationStateSnapshot(installedApps: apps, registeredBundleIdentifiers: appState.registeredBundleIdentifiers, activeInjections: appState.activeInjections)
        case .removeApp(let id):
            var apps = appState.installedApps; apps.removeValue(forKey: id)
            var regs = appState.registeredBundleIdentifiers; regs.remove(id)
            let injections = Set(appState.activeInjections.filter { $0.bundleIdentifier != id })
            appState = ApplicationStateSnapshot(installedApps: apps, registeredBundleIdentifiers: regs, activeInjections: injections)
        case .registerApp(let id), .refreshApp(let id):
            var regs = appState.registeredBundleIdentifiers; regs.insert(id)
            appState = ApplicationStateSnapshot(installedApps: appState.installedApps, registeredBundleIdentifiers: regs, activeInjections: appState.activeInjections)
        case .applyInjection(let op):
            var injections = appState.activeInjections; injections.insert(.init(bundleIdentifier: op.targetBundleIdentifier, artifactIdentifier: op.artifact.identifier))
            appState = ApplicationStateSnapshot(installedApps: appState.installedApps, registeredBundleIdentifiers: appState.registeredBundleIdentifiers, activeInjections: injections)
        case .removeInjection(let target, let artifact):
            var injections = appState.activeInjections; injections.remove(.init(bundleIdentifier: target, artifactIdentifier: artifact))
            appState = ApplicationStateSnapshot(installedApps: appState.installedApps, registeredBundleIdentifiers: appState.registeredBundleIdentifiers, activeInjections: injections)
        }
        packageState = PackageStateSnapshot(installedVersions: versions)
        return BackendOperationResult(operationID: operation.stableID)
    }
}

public actor TransactionExecutor {
    private let stateMachine = TransactionStateMachine()
    public init() {}
    public func execute(_ input: PrismTransaction, backend: any PackageExecutionBackend) async -> PrismTransaction {
        do {
            var tx = input
            if tx.phase == .created { tx = try stateMachine.transition(tx, to: .preparing) }
            if tx.phase == .preparing { tx = try stateMachine.transition(tx, to: .resolving) }
            if tx.phase == .resolving { tx = try stateMachine.transition(tx, to: .ready) }
            if tx.phase == .ready { tx = try stateMachine.transition(tx, to: .executing) }
            for operation in tx.operations where !tx.completedOperationIDs.contains(operation.stableID) {
                _ = try await backend.execute(operation)
                tx.completedOperationIDs.insert(operation.stableID); tx.updatedAt = Date()
            }
            tx = try stateMachine.transition(tx, to: .reconciling)
            return try stateMachine.transition(tx, to: .completed)
        } catch {
            var tx = input; tx.phase = .failed; tx.failureMessage = String(describing: error); tx.updatedAt = Date(); return tx
        }
    }
}
