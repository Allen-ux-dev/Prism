import Foundation
import PrismDaemonCore
import PrismEnvironment
import PrismTransactions

let probe = SystemEnvironmentProbe().snapshot()
let resolver = EnvironmentResolver(providers: [StandardRootlessEnvironmentProvider(), RootfulEnvironmentProvider()])
do {
    let discoveredEnvironment = try resolver.resolve(probe).environment
    let runner = PosixSpawnPackageToolRunner()
    let packageBackend = JailbreakPackageExecutionBackend(environment: discoveredEnvironment, runner: runner)

    // Discover an already-authorized runtime service through a versioned typed bridge.
    // No runtime product name is required; absence simply leaves app/injection providers unavailable.
    let runtimeBridgeCoordinator = RuntimeServiceBridgeCoordinator()
    _ = await runtimeBridgeCoordinator.reconnect()

    let makeRuntimeComposition: @Sendable () async -> PrismDaemonRuntimeComposition = {
        let executionProviders = await ApplicationRuntimeProviderResolver().resolveProviderSet()
        let providerCapabilities = ExecutionProviderCapabilities(
            applicationProvider: executionProviders.application,
            injectionProvider: executionProviders.injection
        )
        let environment = discoveredEnvironment.addingCapabilities(providerCapabilities.capabilities)
        let backend = ComposableExecutionBackend(
            packageBackend: packageBackend,
            applicationProvider: executionProviders.application,
            injectionProvider: executionProviders.injection
        )
        return PrismDaemonRuntimeComposition(environment: environment, backend: backend)
    }

    let initialComposition = await makeRuntimeComposition()
    let journal = AtomicJSONTransactionJournalStore(
        directory: discoveredEnvironment.prismDataDirectory.appendingPathComponent("transactions", isDirectory: true)
    )
    let sources = APTSourceFileSynchronizer(environment: discoveredEnvironment, runner: runner)
    let service = PrismDaemonService(
        environment: initialComposition.environment,
        backend: initialComposition.backend,
        journalStore: journal,
        sourceSynchronizer: sources,
        allowedClientIdentifiers: ["dev.allenux.prism"],
        runtimeBridgeCoordinator: runtimeBridgeCoordinator,
        runtimeCompositionRecomposer: makeRuntimeComposition
    )
    let server = UnixSocketDaemonServer(path: "/var/run/prismd.sock", service: service)
    try server.run()
} catch {
    print("prismd failed to start: \(error)")
    exit(1)
}
