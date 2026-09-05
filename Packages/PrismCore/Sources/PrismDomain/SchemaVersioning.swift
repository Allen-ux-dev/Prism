import Foundation

public struct VersionedPersistentEnvelope<Value: Codable & Sendable>: Codable, Sendable {
    public let schemaVersion: Int
    public let payload: Value

    public init(schemaVersion: Int, payload: Value) {
        self.schemaVersion = schemaVersion
        self.payload = payload
    }
}

public struct MigrationDiagnostic: Codable, Sendable, Equatable, Hashable {
    public let code: String
    public let message: String
    public let sourceVersion: Int?
    public let targetVersion: Int

    public init(code: String, message: String, sourceVersion: Int?, targetVersion: Int) {
        self.code = code
        self.message = message
        self.sourceVersion = sourceVersion
        self.targetVersion = targetVersion
    }
}

public enum MigrationResult<Value: Sendable>: Sendable {
    case migrated(value: Value, fromVersion: Int, toVersion: Int)
    case needsReview(originalData: Data, diagnostic: MigrationDiagnostic)

    public var value: Value? {
        if case .migrated(let value, _, _) = self { return value }
        return nil
    }

    public var requiresReview: Bool {
        if case .needsReview = self { return true }
        return false
    }

    public var originalData: Data? {
        if case .needsReview(let data, _) = self { return data }
        return nil
    }

    public var diagnostic: MigrationDiagnostic? {
        if case .needsReview(_, let diagnostic) = self { return diagnostic }
        return nil
    }
}

public protocol PrismSchemaMigrator: Sendable {
    associatedtype Value: Sendable
    var currentVersion: Int { get }
    func migrate(data: Data, from sourceVersion: Int, to targetVersion: Int) throws -> Value
}
