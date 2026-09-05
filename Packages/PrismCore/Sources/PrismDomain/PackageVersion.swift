import Foundation

public struct VersionSchemeIdentifier: RawRepresentable, Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public static let debian = Self(rawValue: "org.debian.version")
    public static let semantic = Self(rawValue: "org.semver.version")
    public static let native = Self(rawValue: "org.prism.native-version")
}

public struct VersionConstraint: Codable, Hashable, Sendable {
    public let relation: VersionRelation
    public let version: PackageVersion
    public init(relation: VersionRelation, version: PackageVersion) {
        self.relation = relation
        self.version = version
    }
}

public struct PackageVersion: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String
    public let schemeIdentifier: VersionSchemeIdentifier

    public init(rawValue: String, schemeIdentifier: VersionSchemeIdentifier) {
        self.rawValue = rawValue
        self.schemeIdentifier = schemeIdentifier
    }

    public init(_ debianVersion: DebianVersion) {
        self.init(rawValue: debianVersion.rawValue, schemeIdentifier: .debian)
    }

    public static func debian(_ rawValue: String) -> Self { .init(rawValue: rawValue, schemeIdentifier: .debian) }
    public static func semantic(_ rawValue: String) -> Self { .init(rawValue: rawValue, schemeIdentifier: .semantic) }
    public static func native(_ rawValue: String) -> Self { .init(rawValue: rawValue, schemeIdentifier: .native) }

    public var description: String { rawValue }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.schemeIdentifier == rhs.schemeIdentifier,
           let result = try? VersionSchemeRegistry.standard.compare(lhs, rhs) {
            return result == .orderedAscending
        }
        if lhs.schemeIdentifier != rhs.schemeIdentifier { return lhs.schemeIdentifier < rhs.schemeIdentifier }
        return lhs.rawValue < rhs.rawValue
    }
}

public protocol VersionScheme: Sendable {
    var identifier: VersionSchemeIdentifier { get }
    func normalize(_ rawValue: String) throws -> String
    func compare(_ lhs: String, _ rhs: String) throws -> ComparisonResult
    func satisfies(_ version: String, constraint: VersionConstraint) throws -> Bool
}

public enum VersionSchemeError: Error, Equatable, Sendable {
    case invalidVersion(String)
    case mismatchedScheme(expected: VersionSchemeIdentifier, actual: VersionSchemeIdentifier)
}

public struct DebianVersionScheme: VersionScheme {
    public let identifier: VersionSchemeIdentifier = .debian
    public init() {}
    public func normalize(_ rawValue: String) throws -> String { DebianVersion(rawValue).rawValue }
    public func compare(_ lhs: String, _ rhs: String) throws -> ComparisonResult {
        let a = DebianVersion(lhs), b = DebianVersion(rhs)
        if a == b { return .orderedSame }
        return a < b ? .orderedAscending : .orderedDescending
    }
    public func satisfies(_ version: String, constraint: VersionConstraint) throws -> Bool {
        guard constraint.version.schemeIdentifier == identifier else {
            throw VersionSchemeError.mismatchedScheme(expected: identifier, actual: constraint.version.schemeIdentifier)
        }
        return evaluate(try compare(version, constraint.version.rawValue), relation: constraint.relation)
    }
}

public struct SemanticVersionScheme: VersionScheme {
    public let identifier: VersionSchemeIdentifier = .semantic
    public init() {}

    public func normalize(_ rawValue: String) throws -> String {
        let parsed = try SemanticVersion(rawValue)
        return parsed.normalized
    }

    public func compare(_ lhs: String, _ rhs: String) throws -> ComparisonResult {
        let a = try SemanticVersion(lhs), b = try SemanticVersion(rhs)
        if a == b { return .orderedSame }
        return a < b ? .orderedAscending : .orderedDescending
    }

    public func satisfies(_ version: String, constraint: VersionConstraint) throws -> Bool {
        guard constraint.version.schemeIdentifier == identifier else {
            throw VersionSchemeError.mismatchedScheme(expected: identifier, actual: constraint.version.schemeIdentifier)
        }
        return evaluate(try compare(version, constraint.version.rawValue), relation: constraint.relation)
    }

    private struct SemanticVersion: Comparable, Equatable {
        let major: Int
        let minor: Int
        let patch: Int
        let prerelease: [String]
        let normalized: String

        init(_ raw: String) throws {
            let withoutBuild = raw.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let parts = withoutBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            let core = parts[0].split(separator: ".", omittingEmptySubsequences: false)
            guard (1...3).contains(core.count),
                  let major = Int(core[0]), major >= 0 else { throw VersionSchemeError.invalidVersion(raw) }
            let minor = core.count > 1 ? Int(core[1]) : 0
            let patch = core.count > 2 ? Int(core[2]) : 0
            guard let minor, let patch, minor >= 0, patch >= 0 else { throw VersionSchemeError.invalidVersion(raw) }
            self.major = major; self.minor = minor; self.patch = patch
            self.prerelease = parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : []
            self.normalized = "\(major).\(minor).\(patch)" + (prerelease.isEmpty ? "" : "-" + prerelease.joined(separator: "."))
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
            if lhs.prerelease.isEmpty != rhs.prerelease.isEmpty { return !lhs.prerelease.isEmpty }
            for index in 0..<max(lhs.prerelease.count, rhs.prerelease.count) {
                if index >= lhs.prerelease.count { return true }
                if index >= rhs.prerelease.count { return false }
                let l = lhs.prerelease[index], r = rhs.prerelease[index]
                if l == r { continue }
                if let li = Int(l), let ri = Int(r) { return li < ri }
                if Int(l) != nil { return true }
                if Int(r) != nil { return false }
                return l < r
            }
            return false
        }
    }
}

public struct NativeVersionScheme: VersionScheme {
    public let identifier: VersionSchemeIdentifier = .native
    public init() {}
    public func normalize(_ rawValue: String) throws -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public func compare(_ lhs: String, _ rhs: String) throws -> ComparisonResult {
        let result = lhs.compare(rhs, options: [.numeric, .caseInsensitive])
        return result
    }
    public func satisfies(_ version: String, constraint: VersionConstraint) throws -> Bool {
        guard constraint.version.schemeIdentifier == identifier else {
            throw VersionSchemeError.mismatchedScheme(expected: identifier, actual: constraint.version.schemeIdentifier)
        }
        return evaluate(try compare(version, constraint.version.rawValue), relation: constraint.relation)
    }
}

public enum VersionSchemeRegistryError: Error, Equatable, Sendable {
    case unsupportedScheme(VersionSchemeIdentifier)
    case mismatchedSchemes(VersionSchemeIdentifier, VersionSchemeIdentifier)
}

public struct VersionSchemeRegistry: Sendable {
    public static let standard = VersionSchemeRegistry()
    public init() {}

    public func scheme(for identifier: VersionSchemeIdentifier) throws -> any VersionScheme {
        switch identifier {
        case .debian: return DebianVersionScheme()
        case .semantic: return SemanticVersionScheme()
        case .native: return NativeVersionScheme()
        default: throw VersionSchemeRegistryError.unsupportedScheme(identifier)
        }
    }

    public func normalize(_ version: PackageVersion) throws -> PackageVersion {
        let scheme = try scheme(for: version.schemeIdentifier)
        return PackageVersion(rawValue: try scheme.normalize(version.rawValue), schemeIdentifier: version.schemeIdentifier)
    }

    public func compare(_ lhs: PackageVersion, _ rhs: PackageVersion) throws -> ComparisonResult {
        guard lhs.schemeIdentifier == rhs.schemeIdentifier else {
            throw VersionSchemeRegistryError.mismatchedSchemes(lhs.schemeIdentifier, rhs.schemeIdentifier)
        }
        return try scheme(for: lhs.schemeIdentifier).compare(lhs.rawValue, rhs.rawValue)
    }

    public func satisfies(_ version: PackageVersion, constraint: VersionConstraint) throws -> Bool {
        guard version.schemeIdentifier == constraint.version.schemeIdentifier else {
            throw VersionSchemeRegistryError.mismatchedSchemes(version.schemeIdentifier, constraint.version.schemeIdentifier)
        }
        return try scheme(for: version.schemeIdentifier).satisfies(version.rawValue, constraint: constraint)
    }
}

private func evaluate(_ result: ComparisonResult, relation: VersionRelation) -> Bool {
    switch relation {
    case .equal: return result == .orderedSame
    case .greaterThan: return result == .orderedDescending
    case .greaterThanOrEqual: return result != .orderedAscending
    case .lessThan: return result == .orderedAscending
    case .lessThanOrEqual: return result != .orderedDescending
    }
}
