import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions

public protocol RelaxinRuntimeServiceTransport: Sendable {
    func handshake(_ request: RelaxinBridgeHandshake) async throws -> RelaxinBridgeSession
    func activate() async throws
    func deactivate() async
    func queryEnvironment() async throws -> PrismEnvironment
    func inspectPackageState() async throws -> PackageStateSnapshot
    func inspectApplicationState() async throws -> ApplicationStateSnapshot
    func queryTransactions() async throws -> [PrismTransaction]
    func execute(_ transaction: PrismTransaction) async throws -> PrismTransaction
    func reconcile(_ transactionID: UUID) async throws -> PrismTransaction
    func syncRepositorySources(_ sources: [URL]) async throws
}

public actor RelaxinRuntimeProvider: PackageServiceProtocol, PrismRuntimeStateReporting {
    public static let applicationRuntimeRequirements: Set<String> = ["appInstall", "appRegistration", "appReplace", "appRemoval", "appRefresh", "appInjection"]
    public nonisolated let descriptor = PrismProviderDescriptor(
        identifier: "dev.relaxin.service.runtime",
        kind: .packageService,
        version: "1.0",
        protocolVersion: "1",
        priority: 100,
        operatingModes: [.modern, .hybrid],
        supportedRequirements: ["packageInstall", "packageRemove", "packageUpgrade", "dependencyResolution", "repositoryRefresh", "appInstall", "appRegistration", "appReplace", "appRemoval", "appRefresh", "appInjection"],
        supportedFormats: [.relaxinPackage, .prismNative, .prismSource],
        supportedVersionSchemes: ["native", "semantic"],
        runtimeIdentities: ["dev.relaxin.runtime"],
        recoveryStrategies: [.reconcile],
        health: .healthy,
        diagnosticsMetadata: ["role": "RELAXIN-X Modern Package Service"]
    )

    private let transport: any RelaxinRuntimeServiceTransport
    private var activeSession: RelaxinBridgeSession?
    private var runtimeState: ProviderRuntimeState

    public init(transport: any RelaxinRuntimeServiceTransport) {
        self.transport = transport
        self.runtimeState = descriptor.initialRuntimeState()
    }

    public func activate() async throws {
        do {
            try await transport.activate()
            let session = try await transport.handshake(.init(
                supportedProtocolVersions: PrismContractVersions.runtimeIntegration.supportedRange.map(String.init)
            ))
            guard let runtimeProtocol = Int(session.negotiatedProtocolVersion),
                  PrismContractVersions.runtimeIntegration.supportedRange.contains(runtimeProtocol),
                  session.service.protocolVersion == session.negotiatedProtocolVersion else {
                runtimeState.health = .unavailable("Unsupported bridge protocol")
                runtimeState.lastHealthChange = Date()
                throw BridgeError.unsupportedProtocol(session.negotiatedProtocolVersion)
            }
            guard !session.runtime.runtimeIdentity.isEmpty, !session.service.serviceIdentity.isEmpty else {
                runtimeState.health = .unavailable("Invalid bridge descriptor")
                runtimeState.lastHealthChange = Date()
                throw BridgeError.invalidDescriptor("Missing runtime/service identity")
            }
            activeSession = session
            runtimeState = .init(
                health: serviceHealth(session.service.capabilityReport),
                capabilityReport: Dictionary(uniqueKeysWithValues: session.service.capabilityStates.map { ($0.key.rawValue, capabilityHealth($0.value.availability, reason: $0.value.metadata["reason"])) }),
                supportedFormats: session.service.supportedPackageFormats,
                supportedVersionSchemes: session.service.supportedVersionSchemes,
                recoveryStrategies: session.service.recoveryStrategies,
                lastHealthChange: Date(),
                diagnosticSummary: nil
            )
        } catch let error as BridgeError {
            await transport.deactivate()
            throw error
        } catch {
            runtimeState.health = .unavailable("Bridge handshake failed")
            runtimeState.lastHealthChange = Date()
            await transport.deactivate()
            throw BridgeError.handshakeFailed(String(describing: error))
        }
    }

    public func deactivate() async {
        activeSession = nil
        runtimeState.health = .unavailable("Runtime disconnected")
        runtimeState.lastHealthChange = Date()
        runtimeState.diagnosticSummary = "Runtime disconnected"
        await transport.deactivate()
    }

    public func bridgeSession() throws -> RelaxinBridgeSession {
        guard let activeSession else { throw BridgeError.sessionUnavailable }
        return activeSession
    }

    public func providerRuntimeState() async -> ProviderRuntimeState { runtimeState }

    public func queryEnvironment() async throws -> PrismEnvironment {
        let environment = try await transport.queryEnvironment()
        guard let runtime = activeSession?.runtime else { return environment }
        return PrismEnvironment(
            runtimeIdentity: runtime.runtimeIdentity,
            runtimeDisplayName: runtime.displayName ?? environment.runtimeDisplayName,
            runtimeVersion: runtime.runtimeVersion ?? environment.runtimeVersion,
            runtimeOperatingMode: runtime.operatingMode ?? environment.runtimeOperatingMode,
            architecture: environment.architecture,
            osVersion: environment.osVersion,
            osBuild: environment.osBuild,
            capabilityStates: environment.capabilityStates,
            storageNamespace: environment.storageNamespace,
            packageStore: environment.packageStore,
            compatibilityLayers: environment.compatibilityLayers,
            legacy: environment.legacy
        )
    }
    public func queryCapabilities() async throws -> [EnvironmentCapability: CapabilityStatus] {
        if let activeSession { return activeSession.service.capabilityReport }
        return try await transport.queryEnvironment().capabilityReport
    }
    public func queryCapabilityStates() async throws -> [CapabilityIdentifier: CapabilityState] {
        if let activeSession { return activeSession.service.capabilityStates }
        return try await transport.queryEnvironment().capabilityStates
    }
    public func inspectPackageState() async throws -> PackageStateSnapshot { try await transport.inspectPackageState() }
    public func inspectApplicationState() async throws -> ApplicationStateSnapshot { try await transport.inspectApplicationState() }
    public func queryTransactions() async throws -> [PrismTransaction] { try await transport.queryTransactions() }
    public func execute(_ transaction: PrismTransaction) async throws -> PrismTransaction { try await transport.execute(transaction) }
    public func reconcile(_ transactionID: UUID) async throws -> PrismTransaction { try await transport.reconcile(transactionID) }
    public func syncRepositorySources(_ sources: [URL]) async throws { try await transport.syncRepositorySources(sources) }

    private func serviceHealth(_ report: [EnvironmentCapability: CapabilityStatus]) -> ProviderHealth {
        if let packageInstall = report[.packageInstall] {
            switch packageInstall {
            case .available: break
            case .degraded(let reason): return .degraded(reason)
            case .unavailable: return .unavailable("Package service unavailable")
            case .unknown(let reason): return .unknown(reason)
            }
        }
        for status in report.values {
            if case .degraded(let reason) = status { return .degraded(reason) }
        }
        return .healthy
    }

    private func capabilityHealth(_ availability: CapabilityAvailability, reason: String?) -> ProviderHealth {
        switch availability {
        case .available: return .healthy
        case .degraded: return .degraded(reason ?? "Degraded")
        case .unavailable: return .unavailable(reason ?? "Unavailable")
        case .unknown: return .unknown(reason)
        }
    }

    private func capabilityHealth(_ status: CapabilityStatus) -> ProviderHealth {
        switch status {
        case .available: return .healthy
        case .degraded(let reason): return .degraded(reason)
        case .unavailable: return .unavailable("Unavailable")
        case .unknown(let reason): return .unknown(reason)
        }
    }
}
