import Foundation
import Testing
@testable import PrismDomain
@testable import PrismPrivilegedProtocol
@testable import PrismDaemonCore

private struct StaticRuntimeEndpointSource: RuntimeServiceEndpointSource {
    let values: [RuntimeServiceEndpoint]
    func endpoints() async -> [RuntimeServiceEndpoint] { values }
}

private actor MutableRuntimeTransportState {
    var online = true
    var backgroundState: RuntimeBackgroundSessionState = .disabled
    func setOnline(_ value: Bool) { online = value }
    func handle(_ request: RuntimeServiceRequest, hello: RuntimeServiceHello) throws -> RuntimeServiceResponse {
        guard online else { throw RuntimeServiceProtocolError.disconnected }
        switch request {
        case .handshake: return .hello(hello)
        case .queryBackgroundSession: return .backgroundSession(backgroundState)
        case .setBackgroundSessionEnabled(let enabled):
            backgroundState = enabled ? .active : .disabled
            return .backgroundSession(backgroundState)
        case .inspectInstalledApps: return .installedApps([:])
        case .inspectRegisteredBundleIdentifiers: return .registeredBundleIdentifiers([])
        case .inspectActiveInjections: return .activeInjections([])
        default: return .operation(.init(operationID: "ok"))
        }
    }
}

private func coordinatorHello(
    id: String = "runtime.native",
    kind: RuntimeServiceProviderKind = .native,
    priority: Int = 10,
    capabilities: [CapabilityIdentifier] = [.appInstall, .appRegistration, .appInjection, .backgroundExecution, .privilegedService]
) -> RuntimeServiceHello {
    let states = Dictionary(uniqueKeysWithValues: capabilities.map { id in
        (id, CapabilityState(identifier: id, availability: .available))
    })
    return .init(
        runtimeIdentity: id,
        displayName: id,
        serviceVersion: "1",
        selectedProtocolVersion: 1,
        providerKind: kind,
        priority: priority,
        capabilityStates: states,
        health: .healthy
    )
}

@Test func coordinatorRegistersRemoteApplicationAndInjectionServices() async throws {
    let registry = RuntimeApplicationServiceRegistry()
    let state = MutableRuntimeTransportState()
    let hello = coordinatorHello()
    let coordinator = RuntimeServiceBridgeCoordinator(
        registry: registry,
        endpointSource: StaticRuntimeEndpointSource(values: [.init(identifier: "primary", socketPath: "in-memory")]),
        transportFactory: { _ in InMemoryRuntimeServiceTransport { request in try await state.handle(request, hello: hello) } }
    )
    let status = await coordinator.reconnect()
    #expect(status.connectionState == .connected)
    #expect((await registry.discoverApplicationServices()).map(\.descriptor.identifier) == ["runtime.native"])
    #expect((await registry.discoverInjectionServices()).map(\.descriptor.identifier) == ["runtime.native"])
}

@Test func coordinatorDisconnectUnregistersOnlyRemoteServices() async throws {
    let registry = RuntimeApplicationServiceRegistry()
    let state = MutableRuntimeTransportState()
    let hello = coordinatorHello()
    let coordinator = RuntimeServiceBridgeCoordinator(
        registry: registry,
        endpointSource: StaticRuntimeEndpointSource(values: [.init(identifier: "primary", socketPath: "in-memory")]),
        transportFactory: { _ in InMemoryRuntimeServiceTransport { request in try await state.handle(request, hello: hello) } }
    )
    _ = await coordinator.reconnect()
    await state.setOnline(false)
    let status = await coordinator.reconnect()
    #expect(status.connectionState == .degraded)
    #expect((await registry.discoverApplicationServices()).isEmpty)
    #expect((await registry.discoverInjectionServices()).isEmpty)
}

@Test func coordinatorReconnectReregistersServiceAfterRuntimeReturns() async throws {
    let registry = RuntimeApplicationServiceRegistry()
    let state = MutableRuntimeTransportState()
    let hello = coordinatorHello()
    let coordinator = RuntimeServiceBridgeCoordinator(
        registry: registry,
        endpointSource: StaticRuntimeEndpointSource(values: [.init(identifier: "primary", socketPath: "in-memory")]),
        transportFactory: { _ in InMemoryRuntimeServiceTransport { request in try await state.handle(request, hello: hello) } }
    )
    await state.setOnline(false)
    #expect((await coordinator.reconnect()).connectionState == .degraded)
    await state.setOnline(true)
    #expect((await coordinator.reconnect()).connectionState == .connected)
    #expect((await registry.discoverApplicationServices()).count == 1)
}

@Test func backgroundSessionRequiresBothCapabilities() async throws {
    let registry = RuntimeApplicationServiceRegistry()
    let state = MutableRuntimeTransportState()
    let hello = coordinatorHello(capabilities: [.appInstall, .appRegistration, .backgroundExecution])
    let coordinator = RuntimeServiceBridgeCoordinator(
        registry: registry,
        endpointSource: StaticRuntimeEndpointSource(values: [.init(identifier: "primary", socketPath: "in-memory")]),
        transportFactory: { _ in InMemoryRuntimeServiceTransport { request in try await state.handle(request, hello: hello) } }
    )
    let status = await coordinator.reconnect()
    #expect(status.backgroundSupported == false)
    await #expect(throws: RuntimeServiceProtocolError.self) {
        _ = try await coordinator.setBackgroundEnabled(true)
    }
}

@Test func backgroundSessionCanBeEnabledAndDisabledWhenAuthorized() async throws {
    let registry = RuntimeApplicationServiceRegistry()
    let state = MutableRuntimeTransportState()
    let hello = coordinatorHello()
    let coordinator = RuntimeServiceBridgeCoordinator(
        registry: registry,
        endpointSource: StaticRuntimeEndpointSource(values: [.init(identifier: "primary", socketPath: "in-memory")]),
        transportFactory: { _ in InMemoryRuntimeServiceTransport { request in try await state.handle(request, hello: hello) } }
    )
    _ = await coordinator.reconnect()
    #expect(try await coordinator.setBackgroundEnabled(true) == .active)
    #expect(try await coordinator.setBackgroundEnabled(false) == .disabled)
}

@Test func coordinatorKeepsApplicationAndInjectionResolutionIndependent() async throws {
    let registry = RuntimeApplicationServiceRegistry()
    let state = MutableRuntimeTransportState()
    let hello = coordinatorHello(capabilities: [.appInjection])
    let coordinator = RuntimeServiceBridgeCoordinator(
        registry: registry,
        endpointSource: StaticRuntimeEndpointSource(values: [.init(identifier: "inject-only", socketPath: "in-memory")]),
        transportFactory: { _ in InMemoryRuntimeServiceTransport { request in try await state.handle(request, hello: hello) } }
    )
    _ = await coordinator.reconnect()
    #expect((await registry.discoverApplicationServices()).isEmpty)
    #expect((await registry.discoverInjectionServices()).count == 1)
}
