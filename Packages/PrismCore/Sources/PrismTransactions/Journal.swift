import Foundation
import PrismDomain
import PrismResolution

public struct TransactionJournal: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var transaction: PrismTransaction
    public let stateBeforePackages: PackageStateSnapshot
    public let stateBeforeApplications: ApplicationStateSnapshot
    public var lastKnownPackages: PackageStateSnapshot?
    public var lastKnownApplications: ApplicationStateSnapshot?
    public let providerIdentifier: String?
    public let providerVersion: String?
    public let providerProtocolVersion: String?
    public let packageProvenance: [PackageProvenance]?
    public let providerRecoveryToken: String?

    public init(
        schemaVersion: Int = PrismContractVersions.transactionJournalSchema,
        transaction: PrismTransaction,
        stateBeforePackages: PackageStateSnapshot,
        stateBeforeApplications: ApplicationStateSnapshot,
        lastKnownPackages: PackageStateSnapshot? = nil,
        lastKnownApplications: ApplicationStateSnapshot? = nil,
        providerIdentifier: String? = nil,
        providerVersion: String? = nil,
        providerProtocolVersion: String? = nil,
        packageProvenance: [PackageProvenance]? = nil,
        providerRecoveryToken: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.transaction = transaction
        self.stateBeforePackages = stateBeforePackages
        self.stateBeforeApplications = stateBeforeApplications
        self.lastKnownPackages = lastKnownPackages
        self.lastKnownApplications = lastKnownApplications
        self.providerIdentifier = providerIdentifier
        self.providerVersion = providerVersion
        self.providerProtocolVersion = providerProtocolVersion
        self.packageProvenance = packageProvenance
        self.providerRecoveryToken = providerRecoveryToken
    }
}

public protocol TransactionJournalStore: Sendable {
    func save(_ journal: TransactionJournal) async throws
    func load(id: UUID) async throws -> TransactionJournal?
    func loadAll() async throws -> [TransactionJournal]
    func loadUnfinished() async throws -> [TransactionJournal]
}

public actor InMemoryTransactionJournalStore: TransactionJournalStore {
    private var journals: [UUID: TransactionJournal] = [:]
    public init() {}
    public func save(_ journal: TransactionJournal) async throws { journals[journal.transaction.id] = journal }
    public func load(id: UUID) async throws -> TransactionJournal? { journals[id] }
    public func loadAll() async throws -> [TransactionJournal] {
        journals.values.sorted { $0.transaction.createdAt < $1.transaction.createdAt }
    }
    public func loadUnfinished() async throws -> [TransactionJournal] {
        try await loadAll().filter { ![TransactionPhase.completed, .failed, .cancelled, .rolledBack].contains($0.transaction.phase) }
    }
}

public enum JournalStoreError: Error, Equatable { case corruptJournal(String); case migrationNeedsReview(String) }

public actor AtomicJSONTransactionJournalStore: TransactionJournalStore {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    public init(directory: URL) { self.directory = directory }
    public func save(_ journal: TransactionJournal) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let finalURL = directory.appendingPathComponent(journal.transaction.id.uuidString).appendingPathExtension("json")
        let tempURL = directory.appendingPathComponent(journal.transaction.id.uuidString).appendingPathExtension("tmp")
        try encoder.encode(journal).write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: finalURL.path) { try FileManager.default.removeItem(at: finalURL) }
        try FileManager.default.moveItem(at: tempURL, to: finalURL)
    }
    public func load(id: UUID) async throws -> TransactionJournal? {
        let url = directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let migration = TransactionJournalMigrator().attemptMigration(data: data)
        if let journal = migration.value {
            if journal.schemaVersion == PrismContractVersions.transactionJournalSchema {
                try? encoder.encode(journal).write(to: url, options: .atomic)
            }
            return journal
        }
        let review = directory.appendingPathComponent(id.uuidString + ".needs-review.json")
        try? data.write(to: review, options: .atomic)
        throw JournalStoreError.migrationNeedsReview(id.uuidString)
    }
    public func loadAll() async throws -> [TransactionJournal] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        var result: [TransactionJournal] = []
        for url in urls where url.pathExtension == "json" && !url.lastPathComponent.contains(".corrupt.") {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            do {
                if let journal = try await load(id: id) { result.append(journal) }
            } catch JournalStoreError.corruptJournal {
                continue
            } catch JournalStoreError.migrationNeedsReview {
                continue
            }
        }
        return result.sorted { $0.transaction.createdAt < $1.transaction.createdAt }
    }
    public func loadUnfinished() async throws -> [TransactionJournal] {
        try await loadAll().filter { ![TransactionPhase.completed, .failed, .cancelled, .rolledBack].contains($0.transaction.phase) }
    }
}

public struct TransactionReconciler: Sendable {
    public init() {}
    public func reconcile(
        _ journal: TransactionJournal,
        backend: any PackageExecutionBackend,
        activeProviderIdentifier: String? = nil
    ) async throws -> TransactionJournal {
        if let expected = journal.providerIdentifier,
           let activeProviderIdentifier,
           expected != activeProviderIdentifier {
            var review = journal
            review.transaction.phase = .needsReview
            review.transaction.failureMessage = "Transaction belongs to provider \(expected); active provider is \(activeProviderIdentifier)."
            review.transaction.updatedAt = Date()
            return review
        }
        let packages = try await backend.inspectPackageState()
        let apps = try await backend.inspectApplicationState()
        var result = journal
        for operation in result.transaction.operations where !result.transaction.completedOperationIDs.contains(operation.stableID) {
            if operationIsSatisfied(operation, packages: packages, apps: apps) { result.transaction.completedOperationIDs.insert(operation.stableID) }
        }
        result.lastKnownPackages = packages; result.lastKnownApplications = apps
        if result.transaction.completedOperationIDs.count == result.transaction.operations.count {
            result.transaction.phase = .completed
        } else if [.executing, .reconciling, .interrupted].contains(result.transaction.phase) {
            result.transaction.phase = .needsRecovery
        }
        result.transaction.updatedAt = Date()
        return result
    }

    private func operationIsSatisfied(_ operation: TransactionOperation, packages: PackageStateSnapshot, apps: ApplicationStateSnapshot) -> Bool {
        switch operation {
        case .installPackage(let op), .upgradePackage(let op): return packages.installedVersions[op.packageIdentifier].map { $0 >= op.version } ?? false
        case .removePackage(let id), .purgePackage(let id): return packages.installedVersions[id] == nil
        case .installApp(let op), .replaceApp(let op):
            guard let installed = apps.installedApps[op.bundleIdentifier] else { return false }
            return op.version.map { installed.version == $0 } ?? true
        case .removeApp(let id):
            return apps.installedApps[id] == nil
                && !apps.registeredBundleIdentifiers.contains(id)
                && !apps.activeInjections.contains(where: { $0.bundleIdentifier == id })
        case .registerApp(let id), .refreshApp(let id): return apps.registeredBundleIdentifiers.contains(id)
        case .applyInjection(let op): return apps.activeInjections.contains(.init(bundleIdentifier: op.targetBundleIdentifier, artifactIdentifier: op.artifact.identifier))
        case .removeInjection(let target, let artifact): return !apps.activeInjections.contains(.init(bundleIdentifier: target, artifactIdentifier: artifact))
        }
    }
}
