import Foundation
import PrismDomain
import PrismEnvironment
import PrismPrivilegedProtocol
import PrismResolution
import PrismTransactions

public enum PrismServiceStatus: String, Sendable, Codable { case offline, recovering, connected }


public enum PrismNavigationDestination: String, CaseIterable, Sendable, Hashable {
    case featured, packages, sources, apps, activity, installed, updates, settings
}

public enum PrismNavigationContract {
    public static let phonePrimaryDestinations: [PrismNavigationDestination] = [
        .featured, .packages, .sources, .apps, .activity
    ]
    public static let sidebarDestinations: [PrismNavigationDestination] = [
        .featured, .packages, .sources, .apps, .installed, .updates, .activity, .settings
    ]
}

public enum PrismCapabilityPresentationState: String, Sendable, Hashable {
    case available, degraded, unavailable, unknown
}

public struct PrismCapabilityPresentation: Sendable, Hashable {
    public let state: PrismCapabilityPresentationState
    public let detail: String?

    public init(status: CapabilityStatus) {
        switch status {
        case .available:
            state = .available
            detail = nil
        case .degraded(let reason):
            state = .degraded
            detail = reason
        case .unavailable:
            state = .unavailable
            detail = nil
        case .unknown(let reason):
            state = .unknown
            detail = reason
        }
    }

    public var isUsable: Bool { state == .available || state == .degraded }
    public var label: String {
        switch state {
        case .available: return "Available"
        case .degraded: return "Degraded"
        case .unavailable: return "Unavailable"
        case .unknown: return "Checking"
        }
    }
}

public struct PrismStatusRow: Sendable, Hashable {
    public let title: String
    public let value: String
    public let detail: String?

    public init(title: String, value: String, detail: String? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
    }
}

public struct PrismEnvironmentPresentation: Sendable, Hashable {
    public let mode: RuntimeOperatingMode
    public let dailyRows: [PrismStatusRow]
    public let advancedRows: [PrismStatusRow]
    public let capabilities: [String: PrismCapabilityPresentation]

    public static func make(
        environment: PrismEnvironment,
        runtimeDescriptor: RuntimePresentationDescriptor,
        serviceStatus: PrismServiceStatus,
        serviceProvider: String,
        backgroundActive: Bool = false,
        providerDiagnostics: ProviderDiagnosticsSnapshot? = nil
    ) -> Self {
        let policy = RuntimeIsolationPolicy()
        let normal = policy.runtimePresentation(
            environment: environment,
            mode: runtimeDescriptor.operatingMode,
            backgroundActive: backgroundActive
        )

        let packageService: PrismStatusRow
        switch serviceStatus {
        case .offline:
            packageService = .init(title: "Package Service", value: "Offline")
        case .recovering:
            packageService = .init(title: "Package Service", value: "Recovering")
        case .connected:
            if let providerDiagnostics {
                switch providerDiagnostics.runtimeState.health {
                case .healthy:
                    packageService = .init(title: "Package Service", value: normal.packageService)
                case .degraded(let reason):
                    packageService = .init(title: "Package Service", value: "Degraded", detail: reason)
                case .unavailable(let reason):
                    packageService = .init(title: "Package Service", value: "Unavailable", detail: reason)
                case .unknown(let reason):
                    packageService = .init(title: "Package Service", value: "Checking", detail: reason)
                }
            } else {
                packageService = .init(title: "Package Service", value: normal.packageService)
            }
        }

        let daily = [
            PrismStatusRow(title: "Runtime", value: runtimeDescriptor.displayName),
            packageService,
            PrismStatusRow(title: "Compatibility", value: normal.compatibility),
            PrismStatusRow(title: "Background", value: normal.background)
        ]

        let isSimulation = serviceProvider.lowercased().contains("mock") || serviceProvider.lowercased().contains("simulation")
        var advanced: [PrismStatusRow] = []
        if let providerDiagnostics {
            let identity = providerDiagnostics.identity
            let runtime = providerDiagnostics.runtimeState
            advanced.append(.init(title: "Provider ID", value: isSimulation ? "Simulation · \(identity.providerID)" : identity.providerID))
            advanced.append(.init(title: "Provider Version", value: identity.providerVersion))
            if let protocolVersion = identity.protocolVersion { advanced.append(.init(title: "Protocol Version", value: protocolVersion)) }
            advanced.append(.init(title: "Provider Health", value: Self.providerHealthLabel(runtime.health), detail: runtime.health.reason))
            if !runtime.supportedFormats.isEmpty {
                advanced.append(.init(title: "Supported Formats", value: runtime.supportedFormats.map(\.rawValue).sorted().joined(separator: ", ")))
            }
            if !runtime.supportedVersionSchemes.isEmpty {
                advanced.append(.init(title: "Version Schemes", value: runtime.supportedVersionSchemes.sorted().joined(separator: ", ")))
            }
            if !runtime.recoveryStrategies.isEmpty {
                advanced.append(.init(title: "Recovery", value: runtime.recoveryStrategies.map(\.rawValue).sorted().joined(separator: ", ")))
            }
            let formatter = ISO8601DateFormatter()
            advanced.append(.init(title: "Last Health Change", value: formatter.string(from: runtime.lastHealthChange)))
            if let summary = runtime.diagnosticSummary, !summary.isEmpty {
                advanced.append(.init(title: "Diagnostic Summary", value: summary))
            }
        } else {
            advanced.append(.init(title: "Provider", value: isSimulation ? "Simulation · \(serviceProvider)" : serviceProvider))
        }
        advanced.append(.init(title: "Architecture", value: environment.architecture))
        if let version = runtimeDescriptor.runtimeVersion { advanced.append(.init(title: "Runtime Version", value: version)) }
        if let os = environment.osVersion { advanced.append(.init(title: "OS Version", value: os)) }
        if let build = environment.osBuild { advanced.append(.init(title: "OS Build", value: build)) }
        if let storage = environment.storageNamespace {
            advanced.append(.init(title: "Storage Namespace", value: policy.redactedAdvancedValue(storage.path)))
        }
        if let legacy = environment.legacy {
            if let bootstrap = legacy.bootstrapIdentifier { advanced.append(.init(title: "Legacy Bootstrap", value: bootstrap)) }
            if let root = legacy.rootPrefix { advanced.append(.init(title: "Legacy Root", value: policy.redactedAdvancedValue(root.path))) }
            if let db = legacy.packageDatabase?.path { advanced.append(.init(title: "Package Store", value: policy.redactedAdvancedValue(db.path))) }
        }

        let capabilityRows = Dictionary(uniqueKeysWithValues: environment.capabilityReport.map { key, status in
            (key.rawValue, PrismCapabilityPresentation(status: status))
        })
        return .init(mode: runtimeDescriptor.operatingMode, dailyRows: daily, advancedRows: advanced, capabilities: capabilityRows)
    }

    /// V1 presentation adapter. New application code supplies a RuntimePresentationDescriptor.
    public static func make(
        environment: PrismEnvironment,
        mode: PrismOperatingMode,
        serviceStatus: PrismServiceStatus,
        serviceProvider: String,
        backgroundActive: Bool = false,
        providerDiagnostics: ProviderDiagnosticsSnapshot? = nil
    ) -> Self {
        let runtimeMode: RuntimeOperatingMode
        switch mode {
        case .modern: runtimeMode = .modern
        case .hybrid: runtimeMode = .hybrid
        case .legacy: runtimeMode = .legacy
        }
        let descriptor = RuntimePresentationDescriptor(
            displayName: environment.runtimeDisplayName ?? (environment.runtimeIdentity.isEmpty ? "Runtime unavailable" : environment.runtimeIdentity),
            runtimeIdentity: environment.runtimeIdentity,
            runtimeVersion: environment.runtimeVersion,
            operatingMode: runtimeMode,
            compatibilityLevel: .compatible
        )
        return make(
            environment: environment,
            runtimeDescriptor: descriptor,
            serviceStatus: serviceStatus,
            serviceProvider: serviceProvider,
            backgroundActive: backgroundActive,
            providerDiagnostics: providerDiagnostics
        )
    }

    private static func providerHealthLabel(_ health: ProviderHealth) -> String {
        switch health {
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .unavailable: return "Unavailable"
        case .unknown: return "Unknown"
        }
    }
}


public struct PrismIntegrationPresentation: Sendable, Hashable {
    public let state: PrismIntegrationState
    public let lifecycle: PackageServiceLifecycleState
    public let rows: [PrismStatusRow]

    public init(state: PrismIntegrationState, lifecycle: PackageServiceLifecycleState) {
        self.state = state
        self.lifecycle = lifecycle
        self.rows = [
            PrismStatusRow(title: "Prism", value: Self.stateLabel(state), detail: Self.stateDetail(state)),
            PrismStatusRow(title: "Lifecycle", value: Self.lifecycleLabel(lifecycle))
        ]
    }

    private static func stateLabel(_ state: PrismIntegrationState) -> String {
        switch state {
        case .notInstalled: return "Not Installed"
        case .installed: return "Installed"
        case .registered: return "Registered"
        case .activating: return "Activating"
        case .ready: return "Ready"
        case .degraded: return "Degraded"
        case .repairing: return "Repairing"
        case .recovering: return "Recovering"
        case .disabled: return "Disabled"
        case .incompatible: return "Incompatible"
        }
    }

    private static func stateDetail(_ state: PrismIntegrationState) -> String? {
        switch state {
        case .degraded(let reason), .incompatible(let reason): return reason
        default: return nil
        }
    }

    private static func lifecycleLabel(_ state: PackageServiceLifecycleState) -> String {
        switch state {
        case .idle: return "Idle"
        case .activating: return "Activating"
        case .active: return "Active"
        case .finishing: return "Finishing"
        case .recovering: return "Recovering"
        case .degraded: return "Degraded"
        case .unavailable: return "Unavailable"
        }
    }
}

public struct PrismPackageRow: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let installed: Bool
    public let updateAvailable: Bool
    public let iconURL: String?
    public let repositoryID: String?
    public let sourceURL: String?
    public let commerce: PrismCommercePresentation
    public let author: String?
    public let architecture: String?
    public let category: String
    public let trustLabel: String
    public let distributionLabel: String
    public let dependencySummary: [String]
    public let conflictSummary: [String]
    public let requirementSummary: [String]
    public let updatedAt: Date?

    public init(
        id: String,
        name: String,
        version: String,
        description: String,
        installed: Bool,
        updateAvailable: Bool,
        iconURL: String? = nil,
        repositoryID: String? = nil,
        sourceURL: String? = nil,
        commerce: PrismCommercePresentation? = nil,
        author: String? = nil,
        architecture: String? = nil,
        category: String = "Other",
        trustLabel: String = "Unknown",
        distributionLabel: String = "Unknown",
        dependencySummary: [String] = [],
        conflictSummary: [String] = [],
        requirementSummary: [String] = [],
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.installed = installed
        self.updateAvailable = updateAvailable
        self.iconURL = iconURL
        self.repositoryID = repositoryID
        self.sourceURL = sourceURL
        self.commerce = commerce ?? PrismCommerceMetadataParser.presentation(packageID: id, repositoryID: repositoryID ?? sourceURL ?? "unknown", metadata: [:])
        self.author = author
        self.architecture = architecture
        self.category = category
        self.trustLabel = trustLabel
        self.distributionLabel = distributionLabel
        self.dependencySummary = dependencySummary
        self.conflictSummary = conflictSummary
        self.requirementSummary = requirementSummary
        self.updatedAt = updatedAt
    }
}

public enum PrismRepositoryScope {
    public static func filteredPackages(_ rows: [PrismPackageRow], sourceURL: String, query: String) -> [PrismPackageRow] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows.filter { row in
            guard row.sourceURL == sourceURL else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return row.name.lowercased().contains(normalizedQuery)
                || row.id.lowercased().contains(normalizedQuery)
                || row.description.lowercased().contains(normalizedQuery)
        }
    }
}

public struct PrismSourceRow: Identifiable, Sendable, Hashable {
    public let id: String
    public let url: String
    public let packageCount: Int
    public let displayName: String
    public let iconURLs: [String]
    public let commerceProviderIdentifier: String?
    public let providerIdentifier: String?
    public let refreshState: String
    public let trustLabel: String
    public let compatibilityLabel: String
    public let lastRefresh: Date?
    public let summary: String?

    public init(
        id: String,
        url: String,
        packageCount: Int,
        displayName: String? = nil,
        iconURLs: [String] = [],
        commerceProviderIdentifier: String? = nil,
        providerIdentifier: String? = nil,
        refreshState: String = "Idle",
        trustLabel: String = "Unknown",
        compatibilityLabel: String = "Unknown",
        lastRefresh: Date? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.url = url
        self.packageCount = packageCount
        self.displayName = displayName ?? URL(string: url)?.host ?? url
        self.iconURLs = iconURLs
        self.commerceProviderIdentifier = commerceProviderIdentifier
        self.providerIdentifier = providerIdentifier
        self.refreshState = refreshState
        self.trustLabel = trustLabel
        self.compatibilityLabel = compatibilityLabel
        self.lastRefresh = lastRefresh
        self.summary = summary
    }
}
public struct PrismAppRow: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let version: String
    public let injectionCount: Int
    public let architecture: String
    public let minimumOS: String?
    public let registrationState: String
    public let installationSource: String

    public init(
        id: String,
        name: String,
        version: String,
        injectionCount: Int,
        architecture: String = "Unknown",
        minimumOS: String? = nil,
        registrationState: String = "Unknown",
        installationSource: String = "Unknown"
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.injectionCount = injectionCount
        self.architecture = architecture
        self.minimumOS = minimumOS
        self.registrationState = registrationState
        self.installationSource = installationSource
    }
}
public struct PrismTransactionRow: Identifiable, Sendable, Hashable { public let id:UUID; public let title:String; public let phase:String; public let progress:Double; public init(id:UUID,title:String,phase:String,progress:Double){self.id=id;self.title=title;self.phase=phase;self.progress=progress} }
public struct PrismEnvironmentSummary: Sendable, Hashable {
    public let runtime: String
    public let runtimeVersion: String?
    public let architecture: String
    public let compatibility: String
    public let mode: RuntimeOperatingMode
    public let serviceProvider: String
    public let dailyRows: [PrismStatusRow]
    public let advancedRows: [PrismStatusRow]
    public let capabilityReport: [String: PrismCapabilityPresentation]

    public init(
        runtime: String = "Unknown",
        runtimeVersion: String? = nil,
        architecture: String = "Unknown",
        compatibility: String = "Modern",
        mode: RuntimeOperatingMode = .modern,
        serviceProvider: String = "Unavailable",
        dailyRows: [PrismStatusRow] = [],
        advancedRows: [PrismStatusRow] = [],
        capabilityReport: [String: PrismCapabilityPresentation] = [:]
    ) {
        self.runtime = runtime
        self.runtimeVersion = runtimeVersion
        self.architecture = architecture
        self.compatibility = compatibility
        self.mode = mode
        self.serviceProvider = serviceProvider
        self.dailyRows = dailyRows
        self.advancedRows = advancedRows
        self.capabilityReport = capabilityReport
    }

    public func capability(_ key: String) -> PrismCapabilityPresentation {
        capabilityReport[key] ?? .init(status: .unknown(nil))
    }
}


public struct PrismDashboardSnapshot: Sendable {
    public var serviceStatus: PrismServiceStatus
    public var serviceVersion: String?
    public var environment: PrismEnvironmentSummary
    public var integration: PrismIntegrationPresentation?
    public var packages: [PrismPackageRow]
    public var sources: [PrismSourceRow]
    public var apps: [PrismAppRow]
    public var transactions: [PrismTransactionRow]
    public var lastError: String?
    public init(serviceStatus: PrismServiceStatus = .offline, serviceVersion: String? = nil, environment: PrismEnvironmentSummary = .init(), integration: PrismIntegrationPresentation? = nil, packages:[PrismPackageRow]=[], sources:[PrismSourceRow]=[], apps:[PrismAppRow]=[], transactions:[PrismTransactionRow]=[], lastError:String?=nil) {
        self.serviceStatus=serviceStatus; self.serviceVersion=serviceVersion; self.environment=environment; self.integration=integration; self.packages=packages; self.sources=sources; self.apps=apps; self.transactions=transactions; self.lastError=lastError
    }
}

public enum PrismClientActionError: Error, Equatable, Sendable {
    case serviceNotReady
    case unknownPreparedPlan
    case planNotExecutable
    case removalVerificationFailed([String])
    case serviceRejected(String)
}

public actor PrismClientFacade {
    private var service: (any PackageServiceProtocol)?
    private var session: PackageServiceSession?
    private let sessionFactory: PackageServiceSessionFactory?
    private let compositionResolver: (any PrismRuntimeCompositionResolving)?
    private let operatingMode: PrismOperatingMode
    private let runtimeIdentity: String?
    private var cachedCatalog = PackageCatalogSnapshot(packages: [])
    private var cachedInstalled = PackageStateSnapshot(installedVersions: [:])
    private var cachedEnvironment: PrismEnvironment?

    private struct PreparedExecution: Sendable {
        let plan: InstallPlan
        let service: any PackageServiceProtocol
    }
    private struct PreparedRemovalExecution: Sendable {
        let plan: PackageRemovalPlan
        let service: any PackageServiceProtocol
    }
    private var preparedInstallPlans: [UUID: PreparedExecution] = [:]
    private var preparedRemovalPlans: [UUID: PreparedRemovalExecution] = [:]

    public init(service: any PackageServiceProtocol) {
        self.service = service
        self.session = nil
        self.sessionFactory = nil
        self.compositionResolver = nil
        self.operatingMode = .modern
        self.runtimeIdentity = nil
    }

    public init(session: PackageServiceSession) {
        self.service = session.service
        self.session = session
        self.sessionFactory = nil
        self.compositionResolver = nil
        self.operatingMode = .modern
        self.runtimeIdentity = nil
    }

    public init(factory: PackageServiceSessionFactory, mode: PrismOperatingMode, runtimeIdentity: String? = nil) {
        self.service = nil
        self.session = nil
        self.sessionFactory = factory
        self.compositionResolver = nil
        self.operatingMode = mode
        self.runtimeIdentity = runtimeIdentity
    }

    public init(compositionResolver: any PrismRuntimeCompositionResolving) {
        self.service = nil
        self.session = nil
        self.sessionFactory = nil
        self.compositionResolver = compositionResolver
        self.operatingMode = .modern
        self.runtimeIdentity = nil
    }

    public func connectAndLoad(existingSources: [PrismSourceRow] = []) async -> PrismDashboardSnapshot {
        let urls = existingSources.compactMap { URL(string: $0.url) }
        let catalog = await RepositoryCatalogClient().load(sourceURLs: urls)
        cachedCatalog = PackageCatalogSnapshot(packages: catalog.packages)
        let sourceRows = existingSources.map { row in
            PrismStoreRowMapper.sourceRow(
                existing: row,
                visual: catalog.sourceVisuals[row.url],
                packageCount: catalog.sourceCounts[row.url, default: 0]
            )
        }
        var installed: [String: PackageVersion] = [:]
        var apps: [PrismAppRow] = []
        var txRows: [PrismTransactionRow] = []
        var envSummary = PrismEnvironmentSummary()
        var helloVersion: String? = nil
        var status: PrismServiceStatus = .offline
        var serviceError: String? = nil

        do {
            let service = try await browsingService()
            try await service.activate()
            await session?.refreshProviderState()
            helloVersion = service.descriptor.version
            status = .connected
            let env = try await service.queryEnvironment()
            cachedEnvironment = env
            let state = try await service.inspectPackageState()
            cachedInstalled = state
            installed = state.installedVersions
            let appState = try await service.inspectApplicationState()
            apps = appState.installedApps.values.sorted { $0.displayName < $1.displayName }.map { app in
                let count = appState.activeInjections.filter { $0.bundleIdentifier == app.bundleIdentifier }.count
                return .init(id: app.bundleIdentifier, name: app.displayName, version: app.version, injectionCount: count)
            }
            let transactions = try await service.queryTransactions()
            txRows = transactions.map(Self.row)
            let backgroundActive = transactions.contains { ![.completed, .failed, .cancelled, .rolledBack, .needsReview].contains($0.phase) }
            let providerDiagnostics = await diagnostics(for: service)
            let runtimeDescriptor = RuntimePresentationDescriptor.derive(
                environment: env,
                serviceDescriptor: service.descriptor,
                serviceHealth: providerDiagnostics.runtimeState.health
            )
            let compatibility = RuntimeIsolationPolicy().compatibilityLabel(runtimeDescriptor.operatingMode)
            let environmentPresentation = PrismEnvironmentPresentation.make(
                environment: env,
                runtimeDescriptor: runtimeDescriptor,
                serviceStatus: status,
                serviceProvider: service.descriptor.identifier,
                backgroundActive: backgroundActive,
                providerDiagnostics: providerDiagnostics
            )
            envSummary = .init(
                runtime: env.runtimeIdentity,
                runtimeVersion: env.runtimeVersion,
                architecture: env.architecture,
                compatibility: compatibility,
                mode: runtimeDescriptor.operatingMode,
                serviceProvider: service.descriptor.identifier,
                dailyRows: environmentPresentation.dailyRows,
                advancedRows: environmentPresentation.advancedRows,
                capabilityReport: environmentPresentation.capabilities
            )
        } catch {
            status = .offline
            serviceError = String(describing: error)
        }

        var packageRows = catalog.packages.map { package -> PrismPackageRow in
            let installedVersion = installed[package.identifier]
            let sourceURL = package.repositoryID.flatMap { catalog.repositoryBaseURLsByID[$0] }
            return PrismStoreRowMapper.packageRow(
                package: package,
                installedVersion: installedVersion,
                sourceURL: sourceURL,
                sourceVisual: sourceURL.flatMap { catalog.sourceVisuals[$0] },
                iconURL: catalog.packageIconURLs[package.identifier]
            )
        }
        let catalogIDs = Set(packageRows.map(\.id))
        packageRows.append(contentsOf: installed.keys.filter { !catalogIDs.contains($0) }.sorted().map {
            .init(id: $0, name: $0, version: installed[$0]!.rawValue, description: "Installed package", installed: true, updateAvailable: false)
        })
        let warningText = catalog.warnings.isEmpty ? nil : catalog.warnings.joined(separator: "\n")
        let combinedError = [serviceError, warningText].compactMap { $0 }.joined(separator: "\n")
        return .init(serviceStatus: status, serviceVersion: helloVersion, environment: envSummary, packages: packageRows,
                     sources: sourceRows, apps: apps, transactions: txRows, lastError: combinedError.isEmpty ? nil : combinedError)
    }

    public func reconnect(existingSources: [PrismSourceRow]) async -> PrismDashboardSnapshot {
        if let compositionResolver {
            await service?.deactivate()
            service = nil
            session = nil
            await compositionResolver.invalidate()
        } else if let session {
            try? await session.reconnectIfSupported()
        }
        return await connectAndLoad(existingSources: existingSources)
    }

    public func syncSources(_ sources: [PrismSourceRow]) async throws {
        let service = try await browsingService()
        try await service.syncRepositorySources(sources.compactMap { URL(string: $0.url) })
    }

    public func prepareInstall(packageID: String) async throws -> PrismInstallPlanReview {
        guard let package = cachedCatalog.candidates(for: packageID).first else {
            throw ResolutionError.packageNotFound(packageID)
        }
        let requirements = PrismPackageActionPlanner().providerRequirements(for: [package], runtimeIdentity: runtimeIdentity)
        let selectedService = try await serviceForWrite(requirements)
        try await selectedService.activate()
        let environment = try await selectedService.queryEnvironment()
        let installed = try await selectedService.inspectPackageState()
        let prepared = try PrismPackageActionPlanner().prepare(
            packageID: packageID,
            catalog: cachedCatalog,
            installed: installed,
            environment: environment
        )
        preparedInstallPlans[prepared.review.id] = .init(plan: prepared.plan, service: selectedService)
        return prepared.review
    }

    public func confirmInstall(reviewID: UUID) async throws -> PrismTransactionRow {
        guard let prepared = preparedInstallPlans.removeValue(forKey: reviewID) else { throw PrismClientActionError.unknownPreparedPlan }
        guard prepared.plan.isExecutable else { throw PrismClientActionError.planNotExecutable }
        let transaction = PrismTransaction.from(installPlan: prepared.plan)
        let completed = try await prepared.service.execute(transaction)
        if service?.descriptor.identifier == prepared.service.descriptor.identifier {
            cachedInstalled = (try? await prepared.service.inspectPackageState()) ?? cachedInstalled
        }
        return Self.row(completed)
    }

    public func prepareRemoval(
        packageID: String,
        mode: PackageRemovalMode,
        removeUnusedDependencies: Bool = false
    ) async throws -> PrismPackageRemovalReview {
        let requirements = PrismPackageActionPlanner().removalProviderRequirements(runtimeIdentity: runtimeIdentity)
        let selectedService = try await serviceForWrite(requirements)
        try await selectedService.activate()
        let environment = try await selectedService.queryEnvironment()
        let installed = try await selectedService.inspectPackageState()
        let prepared = try PrismPackageActionPlanner().prepareRemoval(
            packageID: packageID,
            mode: mode,
            removeUnusedDependencies: removeUnusedDependencies,
            catalog: cachedCatalog,
            installed: installed,
            environment: environment
        )
        preparedRemovalPlans[prepared.review.id] = .init(plan: prepared.plan, service: selectedService)
        return prepared.review
    }

    public func confirmRemoval(reviewID: UUID) async throws -> PrismTransactionRow {
        guard let prepared = preparedRemovalPlans.removeValue(forKey: reviewID) else {
            throw PrismClientActionError.unknownPreparedPlan
        }
        guard prepared.plan.isExecutable else { throw PrismClientActionError.planNotExecutable }
        let transaction = PrismTransaction.from(removalPlan: prepared.plan)
        let completed = try await prepared.service.execute(transaction)
        let postState = try await prepared.service.inspectPackageState()
        let remaining = prepared.plan.packagesToRemove
            .map(\.identifier)
            .filter { postState.installedVersions[$0] != nil }
            .sorted()
        guard remaining.isEmpty else {
            throw PrismClientActionError.removalVerificationFailed(remaining)
        }
        if service?.descriptor.identifier == prepared.service.descriptor.identifier {
            cachedInstalled = postState
        }
        return Self.row(completed)
    }

    public func discardRemoval(reviewID: UUID) {
        preparedRemovalPlans.removeValue(forKey: reviewID)
    }

    public func discardInstall(reviewID: UUID) {
        preparedInstallPlans.removeValue(forKey: reviewID)
    }

    private func diagnostics(for service: any PackageServiceProtocol) async -> ProviderDiagnosticsSnapshot {
        if let session, session.service.descriptor.identifier == service.descriptor.identifier {
            return await session.diagnosticsSnapshot()
        }
        let runtimeState: ProviderRuntimeState
        if let reporter = service as? any PrismRuntimeStateReporting {
            runtimeState = await reporter.providerRuntimeState()
        } else {
            runtimeState = service.descriptor.initialRuntimeState()
        }
        return .init(
            identity: service.descriptor.identity,
            runtimeState: runtimeState,
            metadata: service.descriptor.diagnosticsMetadata
        )
    }

    private func browsingService() async throws -> any PackageServiceProtocol {
        if let service { return service }
        let selected: PackageServiceSession
        if let compositionResolver {
            selected = try await compositionResolver.resolve(
                requirements: .init(capabilities: [], runtimeIdentity: runtimeIdentity, isWrite: false)
            )
        } else {
            guard let sessionFactory else { throw PrismClientActionError.serviceNotReady }
            selected = try await sessionFactory.makeSession(mode: operatingMode, runtimeIdentity: runtimeIdentity)
        }
        self.session = selected
        self.service = selected.service
        return selected.service
    }

    private func serviceForWrite(_ requirements: ProviderOperationRequirements) async throws -> any PackageServiceProtocol {
        if let compositionResolver {
            let selected = try await compositionResolver.resolve(requirements: requirements)
            return selected.service
        }
        guard let sessionFactory else {
            guard let service else { throw PrismClientActionError.serviceNotReady }
            return service
        }
        let selected = try await sessionFactory.makeSession(
            mode: operatingMode,
            runtimeIdentity: requirements.runtimeIdentity,
            requiredRequirements: requirements.capabilities,
            requiredFormats: requirements.packageFormats
        )
        return selected.service
    }

    private static func row(_ tx: PrismTransaction) -> PrismTransactionRow {
        let completed = Double(tx.completedOperationIDs.count), total = Double(max(1, tx.operations.count))
        return .init(id: tx.id, title: tx.operations.first.map { $0.stableID } ?? "Transaction", phase: tx.phase.rawValue, progress: completed/total)
    }
}
