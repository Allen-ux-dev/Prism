import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismResolution
@testable import PrismTransactions
@testable import PrismPrivilegedProtocol
@testable import PrismDaemonCore

@Test func daemonRejectsRequestBeforeHandshake() async {
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [])
    let service = PrismDaemonService(environment: env, backend: MockPackageExecutionBackend(), journalStore: InMemoryTransactionJournalStore(), allowedClientIdentifiers: ["dev.allenux.prism"])
    let response = await service.handle(.queryCapabilities, sessionID: UUID())
    #expect(response == .rejected("Handshake required"))
}

@Test func authenticatedSessionCanQueryEnvironment() async {
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [.backgroundService])
    let service = PrismDaemonService(environment: env, backend: MockPackageExecutionBackend(), journalStore: InMemoryTransactionJournalStore(), allowedClientIdentifiers: ["dev.allenux.prism"])
    let session = UUID()
    #expect(await service.handle(.handshake(.init(clientIdentifier: "dev.allenux.prism")), sessionID: session) == .hello(.init(serviceVersion: "0.4.1")))
    #expect(await service.handle(.queryEnvironment, sessionID: session) == .environment(env))
}

@Test func frameCodecRoundTripsTypedRequest() throws {
    let codec = LengthPrefixedJSONCodec(maximumPayloadBytes: 1024)
    let frame = try codec.encode(PrivilegedRequest.queryCapabilities)
    #expect(try codec.decode(PrivilegedRequest.self, from: frame) == .queryCapabilities)
}

@Test func sessionConnectIsIdempotentWhileAlreadyConnected() async throws {
    let counter = HandshakeCounter()
    let transport = InMemoryPrivilegedTransport { request in
        switch request {
        case .handshake:
            let value = await counter.increment()
            if value > 1 { return .rejected("Handshake already completed") }
            return .hello(.init(serviceVersion: "0.4.1"))
        default:
            return .accepted
        }
    }
    let manager = PrivilegedSessionManager(transport: transport, clientIdentifier: "dev.allenux.prism")
    let first = try await manager.connect()
    let second = try await manager.connect()
    #expect(first == second)
    #expect(await counter.value == 1)
}

private actor HandshakeCounter {
    private var count = 0
    func increment() -> Int { count += 1; return count }
    var value: Int { count }
}

@Test func daemonRestoresAndReconcilesPersistedTransactionsBeforeReturningQueue() async throws {
    let package = PrismPackage(identifier: "persisted.demo", version: DebianVersion("1.0"), architecture: "arm64", distribution: .deb)
    var transaction = PrismTransaction(operations: [.installPackage(.init(packageIdentifier: package.identifier, version: package.version))])
    transaction.phase = .executing

    let backend = MockPackageExecutionBackend(packageState: .init(installedVersions: [package.identifier: package.version]))
    let store = InMemoryTransactionJournalStore()
    try await store.save(TransactionJournal(
        transaction: transaction,
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init()
    ))
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [])
    let service = PrismDaemonService(environment: env, backend: backend, journalStore: store, allowedClientIdentifiers: ["dev.allenux.prism"])
    let session = UUID()
    _ = await service.handle(.handshake(.init(clientIdentifier: "dev.allenux.prism")), sessionID: session)

    let response = await service.handle(.queryTransactions, sessionID: session)
    guard case .transactions(let transactions) = response else {
        Issue.record("Expected restored transactions")
        return
    }
    #expect(transactions.count == 1)
    guard let restored = transactions.first else { return }
    #expect(restored.id == transaction.id)
    #expect(restored.phase == .completed)
    #expect(restored.completedOperationIDs.contains(transaction.operations[0].stableID))
    #expect(await backend.executionCount(for: transaction.operations[0].stableID) == 0)
}

@Test func daemonRestoresCompletedTransactionHistoryAfterRestart() async throws {
    let operation = TransactionOperation.installPackage(.init(packageIdentifier: "history.demo", version: DebianVersion("1.0")))
    var transaction = PrismTransaction(operations: [operation])
    transaction.phase = .completed
    transaction.completedOperationIDs.insert(operation.stableID)
    let store = InMemoryTransactionJournalStore()
    try await store.save(TransactionJournal(
        transaction: transaction,
        stateBeforePackages: .init(installedVersions: [:]),
        stateBeforeApplications: .init()
    ))
    let env = PrismEnvironment(providerIdentifier: "fixture", bootstrapIdentifier: nil, rootStyle: .rootless, rootPrefix: URL(fileURLWithPath: "/fixture"), architecture: "arm64", capabilities: [])
    let service = PrismDaemonService(environment: env, backend: MockPackageExecutionBackend(), journalStore: store, allowedClientIdentifiers: ["dev.allenux.prism"])
    let session = UUID()
    _ = await service.handle(.handshake(.init(clientIdentifier: "dev.allenux.prism")), sessionID: session)
    let response = await service.handle(.queryTransactions, sessionID: session)
    guard case .transactions(let transactions) = response else { Issue.record("Expected transaction history"); return }
    #expect(transactions.map(\.id).contains(transaction.id))
}
