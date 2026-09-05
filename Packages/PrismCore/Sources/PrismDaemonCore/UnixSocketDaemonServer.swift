import Foundation
import PrismPrivilegedProtocol
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum UnixSocketServerError: Error, Equatable { case pathTooLong, socketFailed(Int32), bindFailed(Int32), listenFailed(Int32) }

public final class UnixSocketDaemonServer: @unchecked Sendable {
    private let path: String
    private let service: PrismDaemonService
    private let codec = LengthPrefixedJSONCodec()
    public init(path: String, service: PrismDaemonService) { self.path = path; self.service = service }

    public func run() throws -> Never {
        let type: Int32
        #if os(Linux)
        type = Int32(SOCK_STREAM.rawValue)
        #else
        type = SOCK_STREAM
        #endif
        let serverFD = socket(AF_UNIX, type, 0)
        guard serverFD >= 0 else { throw UnixSocketServerError.socketFailed(errno) }
        unlink(path)
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count <= capacity else { _ = close(serverFD); throw UnixSocketServerError.pathTooLong }
        withUnsafeMutablePointer(to: &address.sun_path) { ptr in ptr.withMemoryRebound(to: UInt8.self, capacity: capacity) { buf in for i in 0..<bytes.count { buf[i] = bytes[i] } } }
        let bindResult = withUnsafePointer(to: &address) { ptr in ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(serverFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        guard bindResult == 0 else { let e=errno; _=close(serverFD); throw UnixSocketServerError.bindFailed(e) }
        guard listen(serverFD, 8) == 0 else { let e=errno; _=close(serverFD); throw UnixSocketServerError.listenFailed(e) }
        while true {
            let clientFD = accept(serverFD, nil, nil)
            if clientFD < 0 { if errno == EINTR { continue }; continue }
            let sessionID = UUID()
            Task.detached { [service, codec] in
                defer { _ = close(clientFD) }
                while true {
                    guard let frame = Self.readFrame(fd: clientFD) else { break }
                    let response: PrivilegedResponse
                    do { let request = try codec.decode(PrivilegedRequest.self, from: frame); response = await service.handle(request, sessionID: sessionID) }
                    catch { response = .rejected("Invalid request frame") }
                    guard let encoded = try? codec.encode(response), Self.writeAll(fd: clientFD, data: encoded) else { break }
                }
            }
        }
    }

    private static func readFrame(fd: Int32) -> Data? {
        guard let header = readExactly(fd: fd, count: 4) else { return nil }
        let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard length <= 1_048_576, let payload = readExactly(fd: fd, count: Int(length)) else { return nil }
        var frame=header; frame.append(payload); return frame
    }
    private static func readExactly(fd: Int32, count: Int) -> Data? {
        var data=Data(count: count), received=0
        let ok = data.withUnsafeMutableBytes { raw -> Bool in
            guard let base=raw.baseAddress else { return false }
            while received<count { let n=read(fd,base.advanced(by:received),count-received); if n<=0 { return false }; received += n }
            return true
        }
        return ok ? data : nil
    }
    private static func writeAll(fd: Int32, data: Data) -> Bool {
        data.withUnsafeBytes { raw in
            guard let base=raw.baseAddress else { return false }; var sent=0
            while sent<raw.count { let n=write(fd,base.advanced(by:sent),raw.count-sent); if n<=0 { return false }; sent += n }
            return true
        }
    }
}
