import Foundation

public enum PrismLogLevel: String, Codable, CaseIterable, Sendable, Hashable {
    case debug, info, warning, error

    fileprivate var rank: Int {
        switch self { case .debug: return 0; case .info: return 1; case .warning: return 2; case .error: return 3 }
    }
}

public enum PrismLogCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case ui, runtime, source, package, transaction, application, simulation, commerce, recovery
}

public struct PrismLogEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let level: PrismLogLevel
    public let category: PrismLogCategory
    public let message: String
    public let metadata: [String: String]

    public init(id: UUID = UUID(), timestamp: Date = Date(), level: PrismLogLevel, category: PrismLogCategory, message: String, metadata: [String: String] = [:]) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = Self.redacted(metadata)
    }

    private static func redacted(_ metadata: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: metadata.map { key, value in
            let lower = key.lowercased()
            let sensitive = ["token", "password", "secret", "authorization", "cookie", "credential"].contains { lower.contains($0) }
            return (key, sensitive ? "<redacted>" : value)
        })
    }
}

public actor PrismLogStore {
    private let capacity: Int
    private var storage: [PrismLogEntry] = []

    public init(capacity: Int = 300) { self.capacity = max(1, capacity) }

    public func append(level: PrismLogLevel, category: PrismLogCategory, message: String, metadata: [String: String] = [:]) {
        storage.append(.init(level: level, category: category, message: message, metadata: metadata))
        if storage.count > capacity { storage.removeFirst(storage.count - capacity) }
    }

    public func entries(category: PrismLogCategory? = nil, minimumLevel: PrismLogLevel? = nil) -> [PrismLogEntry] {
        storage.filter { entry in
            (category == nil || entry.category == category) && (minimumLevel == nil || entry.level.rank >= minimumLevel!.rank)
        }
    }

    public func clear() { storage.removeAll(keepingCapacity: true) }

    public func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        return storage.map { entry in
            let metadata = entry.metadata.keys.sorted().map { "\($0)=\(entry.metadata[$0]!)" }.joined(separator: " ")
            return "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue.uppercased())] [\(entry.category.rawValue)] \(entry.message)\(metadata.isEmpty ? "" : " | \(metadata)")"
        }.joined(separator: "\n")
    }
}
