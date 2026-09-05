import Foundation

public enum FrameCodecError: Error, Equatable { case payloadTooLarge, truncatedFrame, invalidPayload }

public struct LengthPrefixedJSONCodec: Sendable {
    public let maximumPayloadBytes: Int
    public init(maximumPayloadBytes: Int = 1_048_576) { self.maximumPayloadBytes = maximumPayloadBytes }
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let payload = try JSONEncoder().encode(value)
        guard payload.count <= maximumPayloadBytes else { throw FrameCodecError.payloadTooLarge }
        var length = UInt32(payload.count).bigEndian
        var data = Data(bytes: &length, count: 4); data.append(payload); return data
    }
    public func decode<T: Decodable>(_ type: T.Type, from frame: Data) throws -> T {
        guard frame.count >= 4 else { throw FrameCodecError.truncatedFrame }
        let length = frame.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard Int(length) <= maximumPayloadBytes else { throw FrameCodecError.payloadTooLarge }
        guard frame.count == 4 + Int(length) else { throw FrameCodecError.truncatedFrame }
        do { return try JSONDecoder().decode(T.self, from: frame.dropFirst(4)) } catch { throw FrameCodecError.invalidPayload }
    }
}
