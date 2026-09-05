import Foundation
import PrismDomain
import PrismRepositories

public struct RepositoryProviderRegistry: Sendable {
    public let providers: [any RepositoryProvider]
    public init(providers: [any RepositoryProvider]) { self.providers = providers }
}

public struct ResolvedRepositoryProvider: Sendable {
    public let provider: any RepositoryProvider
    public let probe: RepositoryProbeResult

    public init(provider: any RepositoryProvider, probe: RepositoryProbeResult) {
        self.provider = provider
        self.probe = probe
    }
}

public actor RepositoryProviderResolver {
    private let registry: RepositoryProviderRegistry
    private let probeTimeout: TimeInterval
    private let refreshTimeout: TimeInterval

    public init(
        providers: [any RepositoryProvider],
        probeTimeout: TimeInterval = 3,
        refreshTimeout: TimeInterval = 15
    ) {
        self.registry = .init(providers: providers)
        self.probeTimeout = max(0.001, probeTimeout)
        self.refreshTimeout = max(0.001, refreshTimeout)
    }

    public init(
        registry: RepositoryProviderRegistry,
        probeTimeout: TimeInterval = 3,
        refreshTimeout: TimeInterval = 15
    ) {
        self.registry = registry
        self.probeTimeout = max(0.001, probeTimeout)
        self.refreshTimeout = max(0.001, refreshTimeout)
    }

    public func resolve(
        source: RepositorySource,
        operationContext: ProviderOperationContext = .init()
    ) async throws -> ResolvedRepositoryProvider? {
        try await operationContext.checkingCancellation()

        let providers = registry.providers
        let timeout = probeTimeout
        let results = await withTaskGroup(of: (any RepositoryProvider, RepositoryProbeResult)?.self) { group in
            for provider in providers {
                guard let probing = provider as? any RepositoryProviderProbing else { continue }
                group.addTask {
                    let probe = await Self.boundedProbe(
                        provider: provider,
                        probing: probing,
                        source: source,
                        parentContext: operationContext,
                        timeout: timeout
                    )
                    return probe.map { (provider, $0) }
                }
            }

            var collected: [(any RepositoryProvider, RepositoryProbeResult)] = []
            for await value in group {
                if let value, value.1.isSupported { collected.append(value) }
            }
            return collected
        }

        try await operationContext.checkingCancellation()
        guard let winner = results.sorted(by: Self.ranksBefore).first else { return nil }
        return .init(provider: winner.0, probe: winner.1)
    }

    public func refresh(
        source: RepositorySource,
        operationContext: ProviderOperationContext = .init()
    ) async throws -> PrismRepositorySnapshot {
        try await operationContext.checkingCancellation()
        guard let resolved = try await resolve(source: source, operationContext: operationContext) else {
            throw RepositoryProviderError.noCompatibleProvider(source.identifier)
        }
        return try await Self.boundedRefresh(
            provider: resolved.provider,
            source: source,
            parentContext: operationContext,
            timeout: refreshTimeout
        )
    }

    private nonisolated static func ranksBefore(
        _ lhs: (any RepositoryProvider, RepositoryProbeResult),
        _ rhs: (any RepositoryProvider, RepositoryProbeResult)
    ) -> Bool {
        if lhs.1.confidence != rhs.1.confidence { return lhs.1.confidence > rhs.1.confidence }
        let leftCompatibility = compatibilityRank(lhs.1.compatibility)
        let rightCompatibility = compatibilityRank(rhs.1.compatibility)
        if leftCompatibility != rightCompatibility { return leftCompatibility > rightCompatibility }
        if lhs.0.descriptor.priority != rhs.0.descriptor.priority { return lhs.0.descriptor.priority > rhs.0.descriptor.priority }
        return lhs.0.descriptor.identifier < rhs.0.descriptor.identifier
    }

    private nonisolated static func compatibilityRank(_ level: CompatibilityLevel) -> Int {
        switch level {
        case .compatible: return 5
        case .partiallyCompatible: return 4
        case .degraded: return 3
        case .unknown: return 2
        case .unsupported: return 0
        }
    }

    private nonisolated static func boundedProbe(
        provider: any RepositoryProvider,
        probing: any RepositoryProviderProbing,
        source: RepositorySource,
        parentContext: ProviderOperationContext,
        timeout: TimeInterval
    ) async -> RepositoryProbeResult? {
        let token = ProviderCancellationToken()
        let deadline = minDeadline(parentContext.deadline, Date().addingTimeInterval(timeout))
        let child = ProviderOperationContext(operationID: parentContext.operationID, deadline: deadline, cancellationToken: token)

        return await withTaskGroup(of: RepositoryProbeResult?.self) { group in
            group.addTask {
                if (try? await parentContext.checkingCancellation()) == nil {
                    await token.cancel()
                    return nil
                }
                return await probing.probe(source: source, operationContext: child)
            }
            group.addTask {
                let delay = max(0, deadline.timeIntervalSinceNow)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return nil }
                await token.cancel()
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private nonisolated static func boundedRefresh(
        provider: any RepositoryProvider,
        source: RepositorySource,
        parentContext: ProviderOperationContext,
        timeout: TimeInterval
    ) async throws -> PrismRepositorySnapshot {
        let token = ProviderCancellationToken()
        let deadline = minDeadline(parentContext.deadline, Date().addingTimeInterval(timeout))
        let child = ProviderOperationContext(operationID: parentContext.operationID, deadline: deadline, cancellationToken: token)

        return try await withThrowingTaskGroup(of: PrismRepositorySnapshot.self) { group in
            group.addTask {
                try await parentContext.checkingCancellation()
                return try await provider.refresh(.init(source: source), operationContext: child)
            }
            group.addTask {
                let delay = max(0, deadline.timeIntervalSinceNow)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await token.cancel()
                throw RepositoryProviderError.operationTimedOut(provider.descriptor.identifier)
            }
            guard let first = try await group.next() else {
                throw RepositoryProviderError.noCompatibleProvider(source.identifier)
            }
            group.cancelAll()
            return first
        }
    }

    private nonisolated static func minDeadline(_ lhs: Date?, _ rhs: Date) -> Date {
        guard let lhs else { return rhs }
        return min(lhs, rhs)
    }
}
