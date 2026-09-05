import PrismDomain
import PrismTransactions

public enum PackageServiceBootstrap {
    public static func sessionFactory(providers: [any PackageServiceProtocol]) -> PackageServiceSessionFactory {
        PackageServiceSessionFactory(registry: ProviderRegistry(), services: providers)
    }
}
