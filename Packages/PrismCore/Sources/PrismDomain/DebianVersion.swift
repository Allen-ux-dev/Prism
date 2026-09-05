import Foundation

public struct DebianVersion: RawRepresentable, Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static func < (lhs: DebianVersion, rhs: DebianVersion) -> Bool {
        compare(lhs.rawValue, rhs.rawValue) < 0
    }

    private static func compare(_ lhs: String, _ rhs: String) -> Int {
        let left = split(lhs)
        let right = split(rhs)

        if left.epoch != right.epoch {
            return left.epoch < right.epoch ? -1 : 1
        }

        let upstream = comparePart(left.upstream, right.upstream)
        if upstream != 0 { return upstream }

        return comparePart(left.revision, right.revision)
    }

    private static func split(_ value: String) -> (epoch: Int, upstream: String, revision: String) {
        var epoch = 0
        var remainder = value

        if let colon = remainder.firstIndex(of: ":") {
            let candidate = String(remainder[..<colon])
            if let parsed = Int(candidate), parsed >= 0 {
                epoch = parsed
                remainder = String(remainder[remainder.index(after: colon)...])
            }
        }

        if let hyphen = remainder.lastIndex(of: "-") {
            let upstream = String(remainder[..<hyphen])
            let revisionStart = remainder.index(after: hyphen)
            let revision = String(remainder[revisionStart...])
            return (epoch, upstream, revision.isEmpty ? "0" : revision)
        }

        return (epoch, remainder, "0")
    }

    // Mirrors dpkg's verrevcmp ordering for ASCII package-version segments.
    private static func comparePart(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        var i = 0
        var j = 0

        while i < a.count || j < b.count {
            while (i < a.count && !isDigit(a[i])) || (j < b.count && !isDigit(b[j])) {
                let leftOrder = order(i < a.count ? a[i] : nil)
                let rightOrder = order(j < b.count ? b[j] : nil)
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder ? -1 : 1
                }
                if i < a.count { i += 1 }
                if j < b.count { j += 1 }
            }

            while i < a.count && a[i] == 48 { i += 1 }
            while j < b.count && b[j] == 48 { j += 1 }

            let leftStart = i
            let rightStart = j
            while i < a.count && isDigit(a[i]) { i += 1 }
            while j < b.count && isDigit(b[j]) { j += 1 }

            let leftLength = i - leftStart
            let rightLength = j - rightStart
            if leftLength != rightLength {
                return leftLength < rightLength ? -1 : 1
            }

            if leftLength > 0 {
                for offset in 0..<leftLength {
                    let l = a[leftStart + offset]
                    let r = b[rightStart + offset]
                    if l != r { return l < r ? -1 : 1 }
                }
            }
        }

        return 0
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= 48 && byte <= 57
    }

    private static func isLetter(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
    }

    private static func order(_ byte: UInt8?) -> Int {
        guard let byte else { return 0 }
        if byte == 126 { return -1 } // '~' sorts before everything, even end-of-string.
        if isLetter(byte) { return Int(byte) }
        return Int(byte) + 256
    }
}
