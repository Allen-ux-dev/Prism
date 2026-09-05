import Foundation
import Testing
@testable import PrismPrivilegedProtocol
@testable import PrismUIBridge

@Test func runtimeBridgeControllerMapsTypedStatus() async throws {
    let transport = InMemoryPrivilegedTransport { request in
        switch request {
        case .handshake: return .hello(.init(serviceVersion: "0.4.1"))
        case .queryRuntimeBridgeStatus:
            return .runtimeBridgeStatus(.init(
                connectionState: .connected,
                runtimeDisplayName: "Runtime",
                applicationProviderIdentifier: "runtime.app",
                backgroundSupported: true,
                backgroundState: .active
            ))
        default: return .rejected("unexpected")
        }
    }
    let session = PrivilegedSessionManager(transport: transport, clientIdentifier: "dev.allenux.prism")
    let controller = RuntimeBridgeController(session: session)
    let status = try await controller.status()
    #expect(status.connectionState == .connected)
    #expect(status.backgroundSupported)
    #expect(status.backgroundState == .active)
}
