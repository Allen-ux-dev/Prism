import Foundation

public struct PackageFormatIdentifier: RawRepresentable, Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public static let debianDeb = Self(rawValue: "org.debian.deb")
    public static let prismSource = Self(rawValue: "dev.prism.source")
    public static let prismNative = Self(rawValue: "dev.prism.native")
    public static let relaxinPackage = Self(rawValue: "dev.relaxin.package")

    // V1 compatibility spellings. These are constants, not a closed enum.
    public static let deb = debianDeb
    public static let source = prismSource
    public static let native = prismNative
}

public typealias PackageDistribution = PackageFormatIdentifier
