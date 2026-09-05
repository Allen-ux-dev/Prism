import Foundation
import Testing
@testable import PrismDomain
@testable import PrismTransactions
@testable import PrismPrivilegedProtocol
@testable import PrismDaemonCore

private actor RuntimeBridgeRequestRecorder {
    var requests: [RuntimeServiceRequest] = []
    func append(_ request: RuntimeServiceRequest) { requests.append(request) }
    func snapshot() -> [RuntimeServiceRequest] { requests }
}

private func bridgeHello() -> RuntimeServiceHello {
    .init(
        runtimeIdentity: "runtime.native.test",
        displayName: "Native Runtime",
        serviceVersion: "2.0",
        selectedProtocolVersion: 1,
        providerKind: .native,
        priority: 100,
        capabilityStates: [
            .appInstall: .init(identifier: .appInstall, availability: .available),
            .appRegistration: .init(identifier: .appRegistration, availability: .available),
            .appInjection: .init(identifier: .appInjection, availability: .available)
        ],
        health: .healthy
    )
}

@Test func runtimeServiceBridgeHandshakeCreatesTypedRemoteServices() async throws {
    let transport = InMemoryRuntimeServiceTransport { request in
        if case .handshake = request { return .hello(bridgeHello()) }
        return .rejected("unexpected")
    }
    let snapshot = try await RuntimeServiceBridge(transport: transport, clientIdentifier: "dev.allenux.prism").connect()
    #expect(snapshot.hello.runtimeIdentity == "runtime.native.test")
    #expect(snapshot.applicationService?.descriptor.providerKind == .native)
    #expect(snapshot.injectionService?.descriptor.providerKind == .native)
    #expect(snapshot.applicationService?.descriptor.capabilities.contains(.appInstall) == true)
}

@Test func remoteApplicationServiceDelegatesInstallAndRegister() async throws {
    let recorder = RuntimeBridgeRequestRecorder()
    let transport = InMemoryRuntimeServiceTransport { request in
        await recorder.append(request)
        switch request {
        case .handshake: return .hello(bridgeHello())
        case .install(let operation): return .operation(.init(operationID: "remote-install:\(operation.bundleIdentifier)"))
        case .registerApp(let id): return .operation(.init(operationID: "remote-register:\(id)"))
        default: return .rejected("unexpected")
        }
    }
    let snapshot = try await RuntimeServiceBridge(transport: transport, clientIdentifier: "dev.allenux.prism").connect()
    let service = try #require(snapshot.applicationService)
    let install = try await service.install(.init(bundleIdentifier: "dev.example.app", displayName: "Example"))
    let register = try await service.register(bundleIdentifier: "dev.example.app")
    #expect(install.operationID == "remote-install:dev.example.app")
    #expect(register.operationID == "remote-register:dev.example.app")
}

@Test func remoteInjectionServiceDelegatesTypedInjection() async throws {
    let transport = InMemoryRuntimeServiceTransport { request in
        switch request {
        case .handshake: return .hello(bridgeHello())
        case .applyInjection(let operation): return .operation(.init(operationID: "remote-inject:\(operation.targetBundleIdentifier)"))
        default: return .rejected("unexpected")
        }
    }
    let snapshot = try await RuntimeServiceBridge(transport: transport, clientIdentifier: "dev.allenux.prism").connect()
    let service = try #require(snapshot.injectionService)
    let result = try await service.apply(.init(
        targetBundleIdentifier: "dev.example.app",
        artifact: .init(identifier: "plugin.demo", displayName: "Demo", kind: .bundle, supportedArchitectures: ["arm64"])
    ))
    #expect(result.operationID == "remote-inject:dev.example.app")
}

@Test func remoteServiceRejectResponseThrowsInsteadOfFabricatingSuccess() async throws {
    let transport = InMemoryRuntimeServiceTransport { request in
        if case .handshake = request { return .hello(bridgeHello()) }
        return .rejected("runtime denied")
    }
    let snapshot = try await RuntimeServiceBridge(transport: transport, clientIdentifier: "dev.allenux.prism").connect()
    let service = try #require(snapshot.applicationService)
    await #expect(throws: RuntimeServiceProtocolError.self) {
        _ = try await service.install(.init(bundleIdentifier: "dev.example.app", displayName: "Example"))
    }
}
