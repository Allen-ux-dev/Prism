import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public protocol RuntimeServiceTransport: Sendable {
    func send(_ request: RuntimeServiceRequest) async throws -> RuntimeServiceResponse
    func reset() async
}

public actor InMemoryRuntimeServiceTransport: RuntimeServiceTransport {
    public typealias Handler = @Sendable (RuntimeServiceRequest) async throws -> RuntimeServiceResponse
    private let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func send(_ request: RuntimeServiceRequest) async throws -> RuntimeServiceResponse {
        try await handler(request)
    }

    public func reset() async {}
}

public enum UnixSocketRuntimeServiceTransportError: Error, Equatable {
    case pathTooLong
    case connectFailed(Int32)
    case disconnected
    case ioFailed(Int32)
}

public actor UnixSocketRuntimeServiceTransport: RuntimeServiceTransport {
    private let path: String
    private let codec = LengthPrefixedJSONCodec()
    private var fd: Int32 = -1

    public init(path: String) {
        self.path = path
    }

    deinit {
        if fd >= 0 { _ = close(fd) }
    }

    public func send(_ request: RuntimeServiceRequest) async throws -> RuntimeServiceResponse {
        if fd < 0 { try connectSocket() }
        do {
            let frame = try codec.encode(request)
            try writeAll(frame)
            let header = try readExactly(4)
            let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length <= 1_048_576 else { throw FrameCodecError.payloadTooLarge }
            let payload = try readExactly(Int(length))
            var full = header
            full.append(payload)
            return try codec.decode(RuntimeServiceResponse.self, from: full)
        } catch {
            closeSocket()
            throw error
        }
    }

    public func reset() async {
        closeSocket()
    }

    private func connectSocket() throws {
        let type: Int32
        #if os(Linux)
        type = Int32(SOCK_STREAM.rawValue)
        #else
        type = SOCK_STREAM
        #endif
        let socketFD = socket(AF_UNIX, type, 0)
        guard socketFD >= 0 else { throw UnixSocketRuntimeServiceTransportError.connectFailed(errno) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count <= capacity else {
            _ = close(socketFD)
            throw UnixSocketRuntimeServiceTransportError.pathTooLong
        }
        withUnsafeMutablePointer(to: &address.sun_path) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: capacity) { buffer in
                for index in 0..<bytes.count { buffer[index] = bytes[index] }
            }
        }
        let result = withUnsafePointer(to: &address) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            let code = errno
            _ = close(socketFD)
            throw UnixSocketRuntimeServiceTransportError.connectFailed(code)
        }
        fd = socketFD
    }

    private func writeAll(_ data: Data) throws {
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var sent = 0
            while sent < raw.count {
                let count = write(fd, base.advanced(by: sent), raw.count - sent)
                if count <= 0 { throw UnixSocketRuntimeServiceTransportError.ioFailed(errno) }
                sent += count
            }
        }
    }

    private func readExactly(_ count: Int) throws -> Data {
        var data = Data(count: count)
        var received = 0
        try data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            while received < count {
                let n = read(fd, base.advanced(by: received), count - received)
                if n == 0 { throw UnixSocketRuntimeServiceTransportError.disconnected }
                if n < 0 { throw UnixSocketRuntimeServiceTransportError.ioFailed(errno) }
                received += n
            }
        }
        return data
    }

    private func closeSocket() {
        if fd >= 0 {
            _ = close(fd)
            fd = -1
        }
    }
}
