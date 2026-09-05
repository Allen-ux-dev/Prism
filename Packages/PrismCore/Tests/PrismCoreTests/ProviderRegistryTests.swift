import Foundation
import Testing
@testable import PrismDomain
@testable import PrismRepositories

private struct FixtureProvider: PrismProvider {
    let descriptor: PrismProviderDescriptor
}

@Test func providerRegistryPrefersHealthyModernProviderDeterministically() async throws {
    let registry = ProviderRegistry()
    await registry.register(FixtureProvider(descriptor: .init(identifier: "legacy", kind: .packageService, version: "1", priority: 100, operatingModes: [.legacy], health: .healthy)))
    await registry.register(FixtureProvider(descriptor: .init(identifier: "modern-low", kind: .packageService, version: "1", priority: 10, operatingModes: [.modern], health: .healthy)))
    await registry.register(FixtureProvider(descriptor: .init(identifier: "modern-high", kind: .packageService, version: "1", priority: 50, operatingModes: [.modern], health: .healthy)))

    let selected = try await registry.select(kind: .packageService, context: .init(mode: .modern, runtimeIdentity: "dev.relaxin.runtime"))
    #expect(selected.identifier == "modern-high")
}

@Test func providerRegistryHonorsExplicitOverrideButNeverSelectsUnhealthyProvider() async throws {
    let registry = ProviderRegistry()
    await registry.register(FixtureProvider(descriptor: .init(identifier: "modern", kind: .repository, version: "1", priority: 50, operatingModes: [.modern], health: .healthy)))
    await registry.register(FixtureProvider(descriptor: .init(identifier: "broken", kind: .repository, version: "1", priority: 999, operatingModes: [.modern], health: .unavailable("offline"))))

    let selected = try await registry.select(kind: .repository, context: .init(mode: .modern, explicitProviderIdentifier: "modern"))
    #expect(selected.identifier == "modern")
    await #expect(throws: ProviderRegistryError.self) {
        _ = try await registry.select(kind: .repository, context: .init(mode: .modern, explicitProviderIdentifier: "broken"))
    }
}

@Test func openRepositoryProviderKeepsAPTFileNamesInsideAPTImplementation() async throws {
    let loader = FixtureRepositoryLoader(responses: [
        "https://repo.example/Release": Data("Origin: Example\n".utf8),
        "https://repo.example/Packages": Data("Package: demo\nVersion: 1.0\nArchitecture: iphoneos-arm64\nDescription: Demo\n\n".utf8)
    ])
    let provider = APTRepositoryProvider(loader: loader)
    let source = RepositorySource(identifier: "example", url: URL(string: "https://repo.example/")!, kind: "apt")
    let snapshot = try await provider.refresh(.init(source: source))
    #expect(snapshot.packages.map(\.identifier) == ["demo"])
    #expect((await provider.health(repositoryID: "example")).isUsable)
}

private struct FixtureRepositoryLoader: RepositoryResourceLoading {
    let responses: [String: Data]
    func data(from url: URL) async throws -> Data {
        guard let data = responses[url.absoluteString] else { throw RepositoryProviderError.resourceUnavailable(url.absoluteString) }
        return data
    }
}
