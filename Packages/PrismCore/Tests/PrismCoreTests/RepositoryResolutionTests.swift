import Foundation
import Testing
import PrismDomain
import PrismRepositories
import PrismUIBridge

private struct ProbeMemoryLoader: RepositoryResourceLoading {
    let payloads: [String: Data]
    func data(from url: URL) async throws -> Data {
        guard let data = payloads[url.absoluteString] else {
            throw RepositoryProviderError.resourceUnavailable(url.absoluteString)
        }
        return data
    }
}

private actor ProbeFixtureRepositoryProvider: RepositoryProvider, RepositoryProviderProbing {
    nonisolated let descriptor: PrismProviderDescriptor
    private let acceptedSourceIDs: Set<String>
    private let confidence: Double
    private let compatibility: CompatibilityLevel
    private let snapshot: PrismRepositorySnapshot?
    private let probeDelayNanos: UInt64
    private let refreshError: RepositoryProviderError?

    init(
        identifier: String,
        priority: Int = 0,
        acceptedSourceIDs: Set<String>,
        confidence: Double,
        compatibility: CompatibilityLevel = .compatible,
        snapshot: PrismRepositorySnapshot? = nil,
        probeDelayNanos: UInt64 = 0,
        refreshError: RepositoryProviderError? = nil
    ) {
        self.descriptor = .init(
            identifier: identifier,
            kind: .repository,
            version: "1",
            priority: priority,
            operatingModes: [.modern, .hybrid, .legacy],
            health: .healthy
        )
        self.acceptedSourceIDs = acceptedSourceIDs
        self.confidence = confidence
        self.compatibility = compatibility
        self.snapshot = snapshot
        self.probeDelayNanos = probeDelayNanos
        self.refreshError = refreshError
    }

    func probe(source: RepositorySource, operationContext: ProviderOperationContext) async -> RepositoryProbeResult {
        if probeDelayNanos > 0 {
            try? await Task.sleep(nanoseconds: probeDelayNanos)
        }
        guard acceptedSourceIDs.contains(source.identifier) else {
            return .unsupported(providerID: descriptor.identifier)
        }
        return .init(
            providerID: descriptor.identifier,
            confidence: confidence,
            compatibility: compatibility,
            detectedFormat: "fixture",
            metadata: ["fixture": "true"]
        )
    }

    func refresh(_ context: RepositoryRefreshContext) async throws -> PrismRepositorySnapshot {
        if let refreshError { throw refreshError }
        guard let snapshot else { throw RepositoryProviderError.repositoryNotLoaded(context.source.identifier) }
        return snapshot
    }
    func catalog(repositoryID: String) async -> [PrismPackage] { snapshot?.packages ?? [] }
    func package(_ identifier: String, repositoryID: String) async -> PrismPackage? { snapshot?.packages.first { $0.identifier == identifier } }
    func metadata(repositoryID: String) async -> [String: String] { snapshot?.repository.metadata ?? [:] }
    func health(repositoryID: String) async -> ProviderHealth { .healthy }
}

private func repositorySnapshot(id: String, packageID: String) -> PrismRepositorySnapshot {
    let base = URL(string: id)!
    let package = PrismPackage(identifier: packageID, name: packageID, version: .native("1"), repositoryID: id)
    let repository = PrismRepository(
        identity: id,
        baseURL: base,
        providerIdentifier: "fixture",
        packages: [package],
        refreshState: .ready,
        trustState: .trusted
    )
    return .init(repository: repository, packages: [package])
}

@Test func aptSourceSelectsAPTProvider() async throws {
    let base = URL(string: "https://apt.example/")!
    let loader = ProbeMemoryLoader(payloads: [
        base.appendingPathComponent("Release").absoluteString: Data("Origin: Example\nLabel: Example\n".utf8),
        base.appendingPathComponent("Packages").absoluteString: Data("Package: com.example.one\nVersion: 1.0\nArchitecture: iphoneos-arm64\nName: One\n\n".utf8)
    ])
    let apt = APTRepositoryProvider(loader: loader)
    let resolver = RepositoryProviderResolver(providers: [apt], probeTimeout: 0.2, refreshTimeout: 0.2)
    let source = RepositorySource(identifier: base.absoluteString, url: base, kind: "auto")

    let resolved = try await resolver.resolve(source: source)
    #expect(resolved?.provider.descriptor.identifier == "org.prism.repository.apt")
    #expect(resolved?.probe.detectedFormat == "apt")
}

@Test func modernSourceSelectsModernProvider() async throws {
    let base = URL(string: "https://future.example/")!
    let snapshot = repositorySnapshot(id: base.absoluteString, packageID: "future.package")
    let modern = RelaxinModernRepositoryProvider(snapshots: [base.absoluteString: snapshot])
    let apt = APTRepositoryProvider(loader: ProbeMemoryLoader(payloads: [:]))
    let resolver = RepositoryProviderResolver(providers: [apt, modern], probeTimeout: 0.1, refreshTimeout: 0.1)
    let source = RepositorySource(identifier: base.absoluteString, url: base, kind: "auto")

    let resolved = try await resolver.resolve(source: source)
    #expect(resolved?.provider.descriptor.identifier == "dev.relaxin.repository.modern")
}

@Test func unknownSourceReturnsUnsupported() async throws {
    let base = URL(string: "https://unknown.example/")!
    let resolver = RepositoryProviderResolver(
        providers: [APTRepositoryProvider(loader: ProbeMemoryLoader(payloads: [:]))],
        probeTimeout: 0.05,
        refreshTimeout: 0.05
    )
    let source = RepositorySource(identifier: base.absoluteString, url: base, kind: "auto")
    let resolved = try await resolver.resolve(source: source)
    #expect(resolved == nil)
}

@Test func multipleProvidersUseProbeConfidenceThenPolicyPriority() async throws {
    let base = URL(string: "https://ranking.example/")!
    let sourceID = base.absoluteString
    let lowConfidenceHighPriority = ProbeFixtureRepositoryProvider(
        identifier: "high-priority",
        priority: 100,
        acceptedSourceIDs: [sourceID],
        confidence: 0.6,
        snapshot: repositorySnapshot(id: sourceID, packageID: "a")
    )
    let highConfidenceLowPriority = ProbeFixtureRepositoryProvider(
        identifier: "high-confidence",
        priority: 10,
        acceptedSourceIDs: [sourceID],
        confidence: 0.9,
        snapshot: repositorySnapshot(id: sourceID, packageID: "b")
    )
    let resolver = RepositoryProviderResolver(
        providers: [lowConfidenceHighPriority, highConfidenceLowPriority],
        probeTimeout: 0.1,
        refreshTimeout: 0.1
    )

    let resolved = try await resolver.resolve(source: .init(identifier: sourceID, url: base, kind: "auto"))
    #expect(resolved?.provider.descriptor.identifier == "high-confidence")
}

@Test func providerProbeFailureIsIsolatedAcrossCatalogSources() async {
    let bad = URL(string: "https://bad.example/")!
    let good = URL(string: "https://good.example/")!
    let badProvider = ProbeFixtureRepositoryProvider(
        identifier: "bad-provider",
        acceptedSourceIDs: [bad.absoluteString],
        confidence: 1,
        refreshError: .resourceUnavailable("fixture failure")
    )
    let goodSnapshot = repositorySnapshot(id: good.absoluteString, packageID: "good.package")
    let goodProvider = ProbeFixtureRepositoryProvider(
        identifier: "good-provider",
        acceptedSourceIDs: [good.absoluteString],
        confidence: 1,
        snapshot: goodSnapshot
    )
    let resolver = RepositoryProviderResolver(
        providers: [badProvider, goodProvider],
        probeTimeout: 0.1,
        refreshTimeout: 0.1
    )
    let client = RepositoryCatalogClient(resolver: resolver)

    let result = await client.load(sourceURLs: [bad, good])
    #expect(result.sourceCounts[bad.absoluteString] == 0)
    #expect(result.sourceCounts[good.absoluteString] == 1)
    #expect(result.packages.contains { $0.identifier == "good.package" })
    #expect(result.warnings.contains { $0.contains("bad.example") })
}

@Test func repositoryProviderTimeoutDoesNotBlockHealthyProvider() async throws {
    let base = URL(string: "https://timeout.example/")!
    let sourceID = base.absoluteString
    let slow = ProbeFixtureRepositoryProvider(
        identifier: "slow",
        priority: 1000,
        acceptedSourceIDs: [sourceID],
        confidence: 1,
        snapshot: repositorySnapshot(id: sourceID, packageID: "slow"),
        probeDelayNanos: 1_000_000_000
    )
    let fast = ProbeFixtureRepositoryProvider(
        identifier: "fast",
        priority: 1,
        acceptedSourceIDs: [sourceID],
        confidence: 0.8,
        snapshot: repositorySnapshot(id: sourceID, packageID: "fast")
    )
    let resolver = RepositoryProviderResolver(providers: [slow, fast], probeTimeout: 0.03, refreshTimeout: 0.1)
    let start = Date()
    let resolved = try await resolver.resolve(source: .init(identifier: sourceID, url: base, kind: "auto"))
    let elapsed = Date().timeIntervalSince(start)

    #expect(resolved?.provider.descriptor.identifier == "fast")
    #expect(elapsed < 0.5)
}

@Test func repositoryResolutionHonorsExplicitCancellation() async {
    let base = URL(string: "https://cancel.example/")!
    let provider = ProbeFixtureRepositoryProvider(
        identifier: "provider",
        acceptedSourceIDs: [base.absoluteString],
        confidence: 1,
        snapshot: repositorySnapshot(id: base.absoluteString, packageID: "one")
    )
    let resolver = RepositoryProviderResolver(providers: [provider])
    let token = ProviderCancellationToken()
    await token.cancel()
    let context = ProviderOperationContext(cancellationToken: token)

    await #expect(throws: RepositoryProviderError.operationCancelled) {
        _ = try await resolver.resolve(
            source: .init(identifier: base.absoluteString, url: base, kind: "auto"),
            operationContext: context
        )
    }
}
