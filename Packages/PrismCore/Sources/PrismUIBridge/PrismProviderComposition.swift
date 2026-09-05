import PrismTransactions

/// Concrete-provider composition root. Application/UI code never sees daemon/socket details.
public enum PrismProviderComposition {
    public static func runtimeAwareResolver(
        clientIdentifier: String,
        runtimeProviders: [any PackageServiceProtocol] = [],
        discovery: any RuntimePackageServiceDiscovering = RuntimePackageServiceRegistry.shared,
        preference: ProviderPreference = .modernFirst
    ) -> PrismRuntimeCompositionResolver {
        PrismRuntimeCompositionResolver(
            providers: runtimeProviders + [
                PrismDaemonProvider(socketPath: "/var/run/prismd.sock", clientIdentifier: clientIdentifier)
            ],
            discovery: discovery,
            preference: preference
        )
    }

    public static func runtimeBridgeController(clientIdentifier: String) -> RuntimeBridgeController {
        RuntimeBridgeController(socketPath: "/var/run/prismd.sock", clientIdentifier: clientIdentifier)
    }

    public static func applicationManagementController(clientIdentifier: String) -> ApplicationManagementController {
        ApplicationManagementController(socketPath: "/var/run/prismd.sock", clientIdentifier: clientIdentifier)
    }

    /// Runtime hosts call this after creating a typed runtime transport/provider.
    /// Prism App code remains product-neutral and discovers the provider on the next composition pass.
    public static func registerRuntimePackageService(_ service: any PackageServiceProtocol) async {
        await RuntimePackageServiceRegistry.shared.register(service)
    }

    public static func unregisterRuntimePackageService(providerID: String) async {
        await RuntimePackageServiceRegistry.shared.unregister(providerID: providerID)
    }

    /// V1 compatibility adapter. New application composition must use `runtimeAwareResolver`.
    public static func compatibilityFactory(clientIdentifier: String) -> PackageServiceSessionFactory {
        PackageServiceBootstrap.sessionFactory(providers: [
            PrismDaemonProvider(socketPath: "/var/run/prismd.sock", clientIdentifier: clientIdentifier)
        ])
    }
}
