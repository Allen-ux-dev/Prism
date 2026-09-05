import Foundation
import PrismDomain
import PrismPrivilegedProtocol
import PrismTransactions

public enum ApplicationManagementControllerError: Error, Equatable, Sendable {
    case rejected(String)
    case unexpectedResponse
}

public struct PrismApplicationManagementSnapshot: Sendable, Hashable {
    public let apps: [PrismAppRow]
    public init(apps: [PrismAppRow]) { self.apps = apps }
}

public struct PrismApplicationActionResult: Sendable, Hashable {
    public let transaction: PrismTransactionRow
    public let apps: [PrismAppRow]
    public init(transaction: PrismTransactionRow, apps: [PrismAppRow]) {
        self.transaction = transaction
        self.apps = apps
    }
}

public actor ApplicationManagementController {
    private let session: PrivilegedSessionManager

    public init(socketPath: String, clientIdentifier: String = "dev.allenux.prism") {
        self.session = PrivilegedSessionManager(
            transport: UnixSocketPrivilegedTransport(path: socketPath),
            clientIdentifier: clientIdentifier
        )
    }

    public init(session: PrivilegedSessionManager) {
        self.session = session
    }

    public func snapshot() async throws -> PrismApplicationManagementSnapshot {
        _ = try await session.connect()
        return .init(apps: try await loadRows())
    }

    public func register(bundleIdentifier: String) async throws -> PrismApplicationActionResult {
        try await submit(.registerApp(bundleIdentifier))
    }

    public func refresh(bundleIdentifier: String) async throws -> PrismApplicationActionResult {
        try await submit(.refreshApp(bundleIdentifier))
    }

    public func remove(bundleIdentifier: String) async throws -> PrismApplicationActionResult {
        try await submit(.removeApp(bundleIdentifier))
    }

    private func submit(_ operation: TransactionOperation) async throws -> PrismApplicationActionResult {
        _ = try await session.connect()
        let transaction = PrismTransaction(operations: [operation])
        let response = try await session.request(.submitTransaction(transaction))
        let completed: PrismTransaction
        switch response {
        case .transaction(let value): completed = value
        case .rejected(let reason): throw ApplicationManagementControllerError.rejected(reason)
        default: throw ApplicationManagementControllerError.unexpectedResponse
        }
        let apps = try await loadRows()
        return .init(transaction: Self.row(completed), apps: apps)
    }

    private func loadRows() async throws -> [PrismAppRow] {
        let response = try await session.request(.queryApplicationState)
        switch response {
        case .applicationState(let state):
            return state.installedApps.values
                .sorted { lhs, rhs in
                    let compare = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                    return compare == .orderedSame ? lhs.bundleIdentifier < rhs.bundleIdentifier : compare == .orderedAscending
                }
                .map { app in
                    let injectionCount = state.activeInjections.filter { $0.bundleIdentifier == app.bundleIdentifier }.count
                    return PrismAppRow(
                        id: app.bundleIdentifier,
                        name: app.displayName,
                        version: app.version,
                        injectionCount: injectionCount,
                        architecture: app.architecture,
                        minimumOS: app.minimumOS,
                        registrationState: Self.registrationLabel(app.registrationState),
                        installationSource: Self.sourceLabel(app.installationSource)
                    )
                }
        case .rejected(let reason): throw ApplicationManagementControllerError.rejected(reason)
        default: throw ApplicationManagementControllerError.unexpectedResponse
        }
    }

    private static func row(_ transaction: PrismTransaction) -> PrismTransactionRow {
        let total = max(transaction.operations.count, 1)
        let progress = transaction.phase == .completed ? 1 : Double(transaction.completedOperationIDs.count) / Double(total)
        return PrismTransactionRow(id: transaction.id, title: transaction.operations.map(\.stableID).joined(separator: ", "), phase: transaction.phase.rawValue, progress: progress)
    }

    private static func registrationLabel(_ value: AppRegistrationState) -> String {
        switch value {
        case .registered: return "Registered"
        case .unregistered: return "Unregistered"
        case .unavailable: return "Unavailable"
        case .unknown: return "Unknown"
        }
    }

    private static func sourceLabel(_ value: AppInstallationSource) -> String {
        switch value {
        case .system: return "System"
        case .jailbreak: return "Runtime"
        case .trollStoreStyle: return "Compatibility"
        case .prism: return "Prism"
        case .unknown: return "Unknown"
        }
    }
}
