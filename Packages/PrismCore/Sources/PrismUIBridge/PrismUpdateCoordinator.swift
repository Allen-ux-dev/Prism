import Foundation
import PrismDomain
import PrismTransactions

public protocol PrismUpdateRuntimeAdapter: Sendable {
    func stage(_ candidate: PrismUpdateCandidate) async throws
    func snapshotCurrentInstallation(for target: PrismUpdateTarget) async throws -> PrismUpdateSnapshot
    func activate(_ candidate: PrismUpdateCandidate) async throws
    func verifyHandshake(for candidate: PrismUpdateCandidate) async throws
    func healthCheck(for candidate: PrismUpdateCandidate) async throws -> Bool
    func restore(_ snapshot: PrismUpdateSnapshot, for target: PrismUpdateTarget) async throws
}

public actor PrismUpdateCoordinator {
    public typealias JournalSource = @Sendable () async throws -> [TransactionJournal]
    public typealias OwnershipSource = @Sendable () async throws -> PrismInstallationOwnership

    private let runtime: any PrismUpdateRuntimeAdapter
    private let journalSource: JournalSource
    private let ownershipSource: OwnershipSource
    public private(set) var state: PrismUpdateState = .idle

    public init(
        runtime: any PrismUpdateRuntimeAdapter,
        journalSource: @escaping JournalSource,
        ownershipSource: @escaping OwnershipSource = { .standalone }
    ) {
        self.runtime = runtime
        self.journalSource = journalSource
        self.ownershipSource = ownershipSource
    }

    @discardableResult
    public func requestActivation(_ candidate: PrismUpdateCandidate) async -> PrismUpdateState {
        do {
            if case .prism = candidate.target {
                let ownership = try await ownershipSource()
                switch ownership {
                case .runtimeManaged(let runtimeID):
                    state = .failed(reason: "Prism update lifecycle is owned by \(runtimeID)")
                    return state
                case .external(let identifier):
                    state = .failed(reason: "Prism update lifecycle is owned by \(identifier)")
                    return state
                case .standalone, .legacyMigrated:
                    break
                }
            }
            let journals = try await journalSource()
            if !isSafePoint(candidate.target, journals: journals) {
                state = .waitingForSafePoint
                return state
            }

            state = .validating
            try await runtime.stage(candidate)
            state = .staged
            let snapshot = try await runtime.snapshotCurrentInstallation(for: candidate.target)

            do {
                state = .activating
                try await runtime.activate(candidate)
                state = .verifying
                try await runtime.verifyHandshake(for: candidate)
                guard try await runtime.healthCheck(for: candidate) else {
                    throw UpdateCoordinatorError.healthCheckFailed
                }
                state = .committed
                return state
            } catch {
                state = .rollingBack
                do {
                    try await runtime.restore(snapshot, for: candidate.target)
                    state = .rolledBack
                    return state
                } catch {
                    state = .failed(reason: "Rollback failed: \(String(describing: error))")
                    return state
                }
            }
        } catch {
            state = .failed(reason: String(describing: error))
            return state
        }
    }

    private func isSafePoint(_ target: PrismUpdateTarget, journals: [TransactionJournal]) -> Bool {
        let active = journals.filter { !Self.terminalPhases.contains($0.transaction.phase) }
        switch target {
        case .prism:
            return active.isEmpty
        case .provider(let identity):
            return !active.contains { $0.providerIdentifier == identity.providerID }
        }
    }

    private static let terminalPhases: Set<TransactionPhase> = [.completed, .failed, .cancelled, .rolledBack]
}

public enum UpdateCoordinatorError: Error, Equatable, Sendable {
    case healthCheckFailed
}
