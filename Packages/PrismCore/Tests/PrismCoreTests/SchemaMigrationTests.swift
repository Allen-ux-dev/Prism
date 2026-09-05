import Foundation
import Testing
@testable import PrismDomain

private struct FixtureState: Codable, Sendable, Equatable {
    let name: String
}

@Test func versionedEnvelopeCarriesSchemaVersion() throws {
    let envelope = VersionedPersistentEnvelope(schemaVersion: 3, payload: FixtureState(name: "ready"))
    let data = try JSONEncoder().encode(envelope)
    let decoded = try JSONDecoder().decode(VersionedPersistentEnvelope<FixtureState>.self, from: data)
    #expect(decoded.schemaVersion == 3)
    #expect(decoded.payload.name == "ready")
}

@Test func migrationNeedsReviewPreservesOriginalBytes() {
    let original = Data("{not-json".utf8)
    let result: MigrationResult<FixtureState> = .needsReview(
        originalData: original,
        diagnostic: .init(code: "corrupt", message: "Cannot decode", sourceVersion: nil, targetVersion: 1)
    )
    #expect(result.requiresReview)
    #expect(result.originalData == original)
}
