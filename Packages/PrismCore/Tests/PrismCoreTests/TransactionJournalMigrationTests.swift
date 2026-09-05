import Foundation
import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismTransactions

@Test func v1JournalWithoutSchemaVersionMigratesToCurrent() throws {
    let tx = PrismTransaction(operations: [])
    let legacy = TransactionJournal(
        transaction: tx,
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init(),
        providerIdentifier: "provider"
    )
    let encodedCurrent = try JSONEncoder().encode(legacy)
    var object = try #require(JSONSerialization.jsonObject(with: encodedCurrent) as? [String: Any])
    object.removeValue(forKey: "schemaVersion")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let result = TransactionJournalMigrator().attemptMigration(data: legacyData)
    let migrated = try #require(result.value)
    #expect(migrated.schemaVersion == PrismContractVersions.transactionJournalSchema)
    #expect(migrated.providerIdentifier == "provider")
}

@Test func futureJournalSchemaPreservesOriginalBytesAndRequiresReview() throws {
    let raw = try JSONSerialization.data(withJSONObject: ["schemaVersion": 999, "transaction": [:]])
    let result = TransactionJournalMigrator().attemptMigration(data: raw)
    #expect(result.requiresReview)
    #expect(result.originalData == raw)
}

@Test func corruptJournalMigrationPreservesOriginalBytes() {
    let raw = Data("not-json".utf8)
    let result = TransactionJournalMigrator().attemptMigration(data: raw)
    #expect(result.requiresReview)
    #expect(result.originalData == raw)
}
