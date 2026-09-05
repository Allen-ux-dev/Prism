import Foundation

public enum DebianControlParserError: Error, Equatable {
    case invalidUTF8
    case continuationWithoutField(line: Int)
    case malformedField(line: Int)
}

public struct DebianControlParser: Sendable {
    public init() {}

    public func parse(_ data: Data) throws -> [[String: String]] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw DebianControlParserError.invalidUTF8
        }

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var paragraphs: [[String: String]] = []
        var current: [String: String] = [:]
        var lastKey: String?

        for (offset, rawLine) in normalized.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNumber = offset + 1
            let line = String(rawLine)

            if line.isEmpty {
                if !current.isEmpty {
                    paragraphs.append(current)
                    current = [:]
                    lastKey = nil
                }
                continue
            }

            if line.first == " " || line.first == "\t" {
                guard let key = lastKey else {
                    throw DebianControlParserError.continuationWithoutField(line: lineNumber)
                }
                let continuation = String(line.dropFirst())
                current[key, default: ""] += "\n" + continuation
                continue
            }

            guard let colon = line.firstIndex(of: ":") else {
                throw DebianControlParserError.malformedField(line: lineNumber)
            }

            let key = String(line[..<colon])
            let valueStart = line.index(after: colon)
            let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                throw DebianControlParserError.malformedField(line: lineNumber)
            }
            current[key] = value
            lastKey = key
        }

        if !current.isEmpty {
            paragraphs.append(current)
        }

        return paragraphs
    }
}
