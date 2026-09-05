import Foundation
import CZlib

public enum RepositoryPayloadEncoding: Sendable { case plain, gzip }
public enum RepositoryPayloadError: Error, Equatable { case decompressionFailed(Int32), malformedPayload }

public struct RepositoryPayloadDecoder: Sendable {
    public init() {}
    public func decode(_ data: Data, encoding: RepositoryPayloadEncoding) throws -> Data {
        switch encoding {
        case .plain: return data
        case .gzip: return try inflate(data)
        }
    }

    private func inflate(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }
        var stream = z_stream()
        let initResult = inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initResult == Z_OK else { throw RepositoryPayloadError.decompressionFailed(initResult) }
        defer { inflateEnd(&stream) }

        return try data.withUnsafeBytes { raw -> Data in
            guard let base = raw.bindMemory(to: Bytef.self).baseAddress else { throw RepositoryPayloadError.malformedPayload }
            stream.next_in = UnsafeMutablePointer(mutating: base)
            stream.avail_in = uInt(data.count)
            var output = Data()
            let bufferSize = 32 * 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while true {
                let result: Int32 = buffer.withUnsafeMutableBytes { outRaw in
                    stream.next_out = outRaw.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferSize)
                    return CZlib.inflate(&stream, Z_NO_FLUSH)
                }
                let produced = bufferSize - Int(stream.avail_out)
                if produced > 0 { output.append(buffer, count: produced) }
                if result == Z_STREAM_END { break }
                guard result == Z_OK else { throw RepositoryPayloadError.decompressionFailed(result) }
            }
            return output
        }
    }
}
