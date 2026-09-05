import Foundation
import PrismDomain

public enum JournalMigrationError: Error, Equatable, Sendable {
    case invalidJSON
    case unsupportedFutureVersion(Int)
    case decodeFailed(String)
}

public struct TransactionJournalMigrator: PrismSchemaMigrator {
    public let currentVersion = PrismContractVersions.transactionJournalSchema

    public init() {}

    public func migrate(data: Data, from sourceVersion: Int, to targetVersion: Int) throws -> TransactionJournal {
        guard sourceVersion <= targetVersion else { throw JournalMigrationError.unsupportedFutureVersion(sourceVersion) }
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JournalMigrationError.invalidJSON
        }
        object["schemaVersion"] = targetVersion
        let migratedData = try JSONSerialization.data(withJSONObject: object)
        do {
            var journal = try JSONDecoder().decode(TransactionJournal.self, from: migratedData)
            journal.schemaVersion = targetVersion
            return journal
        } catch {
            throw JournalMigrationError.decodeFailed(String(describing: error))
        }
    }

    public func attemptMigration(data: Data) -> MigrationResult<TransactionJournal> {
        let sourceVersion: Int
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .needsReview(
                    originalData: data,
                    diagnostic: .init(code: "invalid-json", message: "Journal root is not an object", sourceVersion: nil, targetVersion: currentVersion)
                )
            }
            sourceVersion = object["schemaVersion"] as? Int ?? 1
        } catch {
            return .needsReview(
                originalData: data,
                diagnostic: .init(code: "invalid-json", message: String(describing: error), sourceVersion: nil, targetVersion: currentVersion)
            )
        }

        guard sourceVersion <= currentVersion else {
            return .needsReview(
                originalData: data,
                diagnostic: .init(code: "future-schema", message: "Journal schema \(sourceVersion) is newer than supported \(currentVersion)", sourceVersion: sourceVersion, targetVersion: currentVersion)
            )
        }

        do {
            let journal = try migrate(data: data, from: sourceVersion, to: currentVersion)
            return .migrated(value: journal, fromVersion: sourceVersion, toVersion: currentVersion)
        } catch {
            return .needsReview(
                originalData: data,
                diagnostic: .init(code: "migration-failed", message: String(describing: error), sourceVersion: sourceVersion, targetVersion: currentVersion)
            )
        }
    }
}
