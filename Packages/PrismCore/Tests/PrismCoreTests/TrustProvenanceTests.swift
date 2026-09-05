import Foundation
import Testing
@testable import PrismDomain
@testable import PrismResolution
@testable import PrismTransactions

@Test func packageProvenanceRecordsProviderRepositoryAndTrust() {
    let provenance = PackageProvenance(
        packageID: "dev.example",
        version: "1.0",
        formatIdentifier: "dev.relaxin.package",
        repositoryID: "modern",
        providerID: "relaxin",
        providerVersion: "4",
        trustStatus: .verified,
        metadataRevision: "r7"
    )
    #expect(provenance.providerID == "relaxin")
    #expect(provenance.trustStatus == .verified)
}

@Test func repositoryTrustMapsLegacyStateIntoNormalizedStatus() {
    let repository = PrismRepository(
        identity: "repo",
        baseURL: URL(string: "https://example.invalid")!,
        providerIdentifier: "provider",
        trustState: .trusted
    )
    #expect(repository.trustStatus == .trusted)
}

@Test func transactionJournalCarriesProviderProtocolAndPackageProvenance() {
    let tx = PrismTransaction(operations: [])
    let provenance = PackageProvenance(
        packageID: "dev.example", version: "1", formatIdentifier: "dev.relaxin.package",
        repositoryID: "repo", providerID: "provider", providerVersion: "2", trustStatus: .trusted
    )
    let journal = TransactionJournal(
        transaction: tx,
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init(),
        providerIdentifier: "provider",
        providerVersion: "2",
        providerProtocolVersion: "1",
        packageProvenance: [provenance]
    )
    #expect(journal.providerProtocolVersion == "1")
    #expect(journal.packageProvenance?.first?.packageID == "dev.example")
}
