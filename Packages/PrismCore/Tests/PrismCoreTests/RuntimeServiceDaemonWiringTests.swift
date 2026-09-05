import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismTransactions
@testable import PrismPrivilegedProtocol
@testable import PrismDaemonCore

private actor DaemonRuntimeState {
    var background: RuntimeBackgroundSessionState = .disabled
    func handle(_ request: RuntimeServiceRequest, hello: RuntimeServiceHello) -> RuntimeServiceResponse {
        switch request {
        case .handshake: return .hello(hello)
        case .queryBackgroundSession: return .backgroundSession(background)
        case .setBackgroundSessionEnabled(let enabled):
            background = enabled ? .active : .disabled
            return .backgroundSession(background)
        case .inspectInstalledApps: return .installedApps([:])
        case .inspectRegisteredBundleIdentifiers: return .registeredBundleIdentifiers([])
        case .inspectActiveInjections: return .activeInjections([])
        default: return .operation(.init(operationID: "ok"))
        }
    }
}

private struct DaemonEndpointSource: RuntimeServiceEndpointSource {
    func endpoints() async -> [RuntimeServiceEndpoint] { [.init(identifier: "test", socketPath: "memory")] }
}

private func daemonCoordinator() -> RuntimeServiceBridgeCoordinator {
    let state = DaemonRuntimeState()
    let capabilities: [CapabilityIdentifier: CapabilityState] = Dictionary(uniqueKeysWithValues: [
        CapabilityIdentifier.appInstall, .appRegistration, .backgroundExecution, .privilegedService
    ].map { ($0, .init(identifier: $0, availability: .available)) })
    let hello = RuntimeServiceHello(
        runtimeIdentity: "runtime.daemon.test",
        displayName: "Daemon Runtime",
        serviceVersion: "1",
        selectedProtocolVersion: 1,
        providerKind: .native,
        capabilityStates: capabilities,
        health: .healthy
    )
    return RuntimeServiceBridgeCoordinator(
        registry: RuntimeApplicationServiceRegistry(),
        endpointSource: DaemonEndpointSource(),
        transportFactory: { _ in InMemoryRuntimeServiceTransport { request in await state.handle(request, hello: hello) } }
    )
}

@Test func daemonWithoutRuntimeCoordinatorReportsOfflineBridgeStatus() async {
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [])
    let service = PrismDaemonService(environment: env, backend: MockPackageExecutionBackend(), journalStore: InMemoryTransactionJournalStore(), allowedClientIdentifiers: ["dev.allenux.prism"])
    let session = UUID()
    _ = await service.handle(.handshake(.init(clientIdentifier: "dev.allenux.prism")), sessionID: session)
    #expect(await service.handle(.queryRuntimeBridgeStatus, sessionID: session) == .runtimeBridgeStatus(.init(connectionState: .offline)))
    #expect(await service.handle(.setRuntimeBackgroundEnabled(true), sessionID: session) == .rejected("Runtime bridge unavailable"))
}

@Test func daemonRuntimeBridgeReconnectAndBackgroundControlAreTyped() async {
    let coordinator = daemonCoordinator()
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [])
    let service = PrismDaemonService(
        environment: env,
        backend: MockPackageExecutionBackend(),
        journalStore: InMemoryTransactionJournalStore(),
        allowedClientIdentifiers: ["dev.allenux.prism"],
        runtimeBridgeCoordinator: coordinator
    )
    let session = UUID()
    _ = await service.handle(.handshake(.init(clientIdentifier: "dev.allenux.prism")), sessionID: session)
    guard case .runtimeBridgeStatus(let connected) = await service.handle(.reconnectRuntimeBridge, sessionID: session) else {
        Issue.record("Expected runtime bridge status")
        return
    }
    #expect(connected.connectionState == .connected)
    guard case .runtimeBridgeStatus(let enabled) = await service.handle(.setRuntimeBackgroundEnabled(true), sessionID: session) else {
        Issue.record("Expected background status")
        return
    }
    #expect(enabled.backgroundState == .active)
}

@Test func daemonReconnectRecomposesBackendAndEnvironmentForNextTransaction() async {
    let coordinator = daemonCoordinator()
    let initial = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [])
    let recomposed = initial.addingCapabilities([.appInstall, .appRegistration])
    let service = PrismDaemonService(
        environment: initial,
        backend: MockPackageExecutionBackend(),
        journalStore: InMemoryTransactionJournalStore(),
        allowedClientIdentifiers: ["dev.allenux.prism"],
        runtimeBridgeCoordinator: coordinator,
        runtimeCompositionRecomposer: {
            PrismDaemonRuntimeComposition(environment: recomposed, backend: MockPackageExecutionBackend())
        }
    )
    let session = UUID()
    _ = await service.handle(.handshake(.init(clientIdentifier: "dev.allenux.prism")), sessionID: session)
    _ = await service.handle(.reconnectRuntimeBridge, sessionID: session)
    guard case .environment(let environment) = await service.handle(.queryEnvironment, sessionID: session) else {
        Issue.record("Expected environment")
        return
    }
    #expect(environment.capabilities.contains(.appInstall))
    #expect(environment.capabilities.contains(.appRegistration))
}
