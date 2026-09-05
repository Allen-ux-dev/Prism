import Foundation
import Combine
import PrismUIBridge
import PrismResolution
import PrismDomain

enum PrismLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .system: return "Follow System"
        case .simplifiedChinese: return "Simplified Chinese"
        case .english: return "English"
        }
    }

    fileprivate var resourceName: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("zh") ? "zh-Hans" : "en"
        case .simplifiedChinese: return "zh-Hans"
        case .english: return "en"
        }
    }
}

enum PrismLocalization {
    static let defaultsKey = "PrismLanguage"

    static func selectedLanguage() -> PrismLanguage {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let language = PrismLanguage(rawValue: raw) else { return .system }
        return language
    }

    static func text(_ key: String, language: PrismLanguage? = nil) -> String {
        let language = language ?? selectedLanguage()
        guard let path = Bundle.main.path(forResource: language.resourceName, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let template = text(key)
        let localeIdentifier = selectedLanguage().resourceName == "zh-Hans" ? "zh_Hans" : "en_US"
        return String(format: template, locale: Locale(identifier: localeIdentifier), arguments: arguments)
    }
}

func L(_ key: String) -> String { PrismLocalization.text(key) }
func LF(_ key: String, _ arguments: CVarArg...) -> String {
    let template = PrismLocalization.text(key)
    let localeIdentifier = PrismLocalization.selectedLanguage().resourceName == "zh-Hans" ? "zh_Hans" : "en_US"
    return String(format: template, locale: Locale(identifier: localeIdentifier), arguments: arguments)
}

@MainActor
final class AppContainer: ObservableObject {
    @Published private(set) var snapshot = PrismDashboardSnapshot()
    @Published var isSettingsPresented = false
    @Published var isAddSourcePresented = false
    @Published var sourceDraft = ""
    @Published var packageSearch = ""
    @Published var storeCategory: PrismStoreCategory = .all
    @Published var storeSourceID: String?
    @Published var storeInstallationFilter: PrismPackageInstallationFilter = .all
    @Published var storeCommerceFilter: PrismPackageCommerceFilter = .all
    @Published var storeSort: PrismPackageSort = .name
    @Published var sourceDraftError: String?
    @Published var applicationActionError: String?
    @Published var isApplicationSubmitting = false
    @Published private(set) var logEntries: [PrismLogEntry] = []
    @Published private(set) var logExportText = ""
    @Published var commerceActionError: String?
    @Published var isCommerceSubmitting = false
    @Published var installPlanReview: PrismInstallPlanReview?
    @Published var installActionError: String?
    @Published var isInstallSubmitting = false
    @Published var removalPlanReview: PrismPackageRemovalReview?
    @Published var removalActionError: String?
    @Published var isRemovalSubmitting = false
    @Published private(set) var simulationSnapshot = PrismAppSimulationSnapshot()
    @Published var simulationError: String?
    @Published var isSimulationRunning = false
    @Published private(set) var runtimeBridgeStatus = PrismRuntimeBridgeStatus()
    @Published private(set) var runtimeBackgroundRequested: Bool
    @Published var language: PrismLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: PrismLocalization.defaultsKey) }
    }

    private let simulationCenter = PrismAppSimulationCenter()
    private let runtimeBridgeController = PrismProviderComposition.runtimeBridgeController(clientIdentifier: "dev.allenux.prism")
    private let applicationManagementController = PrismProviderComposition.applicationManagementController(clientIdentifier: "dev.allenux.prism")
    private let logStore = PrismLogStore(capacity: 300)
    private var commerceProviders: [String: any RepositoryCommerceProvider] = [:]
    private let compositionResolver = PrismProviderComposition.runtimeAwareResolver(clientIdentifier: "dev.allenux.prism")
    private lazy var client = PrismClientFacade(compositionResolver: compositionResolver)

    init() {
        language = PrismLocalization.selectedLanguage()
        runtimeBackgroundRequested = UserDefaults.standard.bool(forKey: "PrismRuntimeBackgroundEnabled")
        snapshot.sources = Self.loadSources()
    }

    var serviceStatusText: String {
        switch snapshot.serviceStatus {
        case .connected: return "Connected"
        case .recovering: return "Recovering…"
        case .offline: return "Offline"
        }
    }

    var storeQuery: PrismStoreQuery {
        PrismStoreQuery(
            searchText: packageSearch,
            category: storeCategory,
            sourceID: storeSourceID,
            installationFilter: storeInstallationFilter,
            commerceFilter: storeCommerceFilter,
            sort: storeSort
        )
    }

    var filteredPackages: [PrismPackageRow] {
        PrismStorePresentationBuilder.filteredPackages(snapshot.packages, query: storeQuery)
    }

    var storeOverview: PrismStoreOverview {
        PrismStorePresentationBuilder.overview(packages: snapshot.packages, sources: snapshot.sources, transactions: snapshot.transactions)
    }

    var activityBuckets: [PrismActivityBucket: [PrismTransactionRow]] {
        PrismStorePresentationBuilder.activityBuckets(snapshot.transactions)
    }

    var installedPackages: [PrismPackageRow] { snapshot.packages.filter(\.installed) }
    var updatePackages: [PrismPackageRow] { snapshot.packages.filter(\.updateAvailable) }

    func initialize() {
        recordLog(.info, .runtime, "Prism initialization started")
        Task {
            snapshot = await client.connectAndLoad(existingSources: snapshot.sources)
            recordLog(snapshot.serviceStatus == .connected ? .info : .warning, .runtime, "Initial package-service load finished", metadata: ["status": snapshot.serviceStatus.rawValue])
            await refreshRuntimeBridgeStatus(restoreBackgroundPreference: true)
            await refreshApplicationsFromRuntime()
        }
    }

    func reconnect() {
        snapshot.serviceStatus = .recovering
        recordLog(.info, .runtime, "Package-service reconnect requested")
        Task {
            snapshot = await client.reconnect(existingSources: snapshot.sources)
            recordLog(snapshot.serviceStatus == .connected ? .info : .warning, .runtime, "Package-service reconnect finished", metadata: ["status": snapshot.serviceStatus.rawValue])
            await refreshRuntimeBridgeStatus(restoreBackgroundPreference: true)
        }
    }

    func reconnectRuntimeBridge() {
        recordLog(.info, .runtime, "Runtime bridge reconnect requested")
        Task {
            do {
                runtimeBridgeStatus = try await runtimeBridgeController.reconnect()
                recordLog(.info, .runtime, "Runtime bridge reconnect finished", metadata: [
                    "state": runtimeBridgeStatus.connectionState.rawValue,
                    "background": runtimeBridgeStatus.backgroundState.rawValue
                ])
                if runtimeBackgroundRequested && runtimeBridgeStatus.backgroundSupported {
                    runtimeBridgeStatus = try await runtimeBridgeController.setBackgroundEnabled(true)
                    recordLog(.info, .runtime, "Runtime background preference restored", metadata: ["state": runtimeBridgeStatus.backgroundState.rawValue])
                }
                snapshot = await client.reconnect(existingSources: snapshot.sources)
                await refreshApplicationsFromRuntime()
            } catch {
                runtimeBridgeStatus = .init(connectionState: .degraded, lastError: String(describing: error))
                recordLog(.error, .runtime, "Runtime bridge reconnect failed", metadata: ["error": String(describing: error)])
            }
        }
    }

    func setRuntimeBackgroundEnabled(_ enabled: Bool) {
        if !enabled {
            runtimeBackgroundRequested = false
            UserDefaults.standard.set(false, forKey: "PrismRuntimeBackgroundEnabled")
        }
        guard !enabled || runtimeBridgeStatus.backgroundSupported else {
            recordLog(.warning, .runtime, "Runtime background enable rejected", metadata: ["reason": "capability unavailable"])
            return
        }
        recordLog(.info, .runtime, "Runtime background state requested", metadata: ["enabled": enabled ? "true" : "false"])
        Task {
            do {
                runtimeBridgeStatus = try await runtimeBridgeController.setBackgroundEnabled(enabled)
                runtimeBackgroundRequested = enabled
                UserDefaults.standard.set(enabled, forKey: "PrismRuntimeBackgroundEnabled")
                recordLog(.info, .runtime, "Runtime background state updated", metadata: ["state": runtimeBridgeStatus.backgroundState.rawValue])
            } catch {
                runtimeBridgeStatus = .init(
                    connectionState: .degraded,
                    runtimeDisplayName: runtimeBridgeStatus.runtimeDisplayName,
                    applicationProviderIdentifier: runtimeBridgeStatus.applicationProviderIdentifier,
                    injectionProviderIdentifier: runtimeBridgeStatus.injectionProviderIdentifier,
                    backgroundSupported: runtimeBridgeStatus.backgroundSupported,
                    backgroundState: .degraded,
                    lastError: String(describing: error)
                )
                recordLog(.error, .runtime, "Runtime background request failed", metadata: ["error": String(describing: error)])
            }
        }
    }

    private func refreshRuntimeBridgeStatus(restoreBackgroundPreference: Bool) async {
        do {
            runtimeBridgeStatus = try await runtimeBridgeController.status()
            recordLog(.info, .runtime, "Runtime bridge status refreshed", metadata: [
                "state": runtimeBridgeStatus.connectionState.rawValue,
                "background": runtimeBridgeStatus.backgroundState.rawValue
            ])
            if restoreBackgroundPreference && runtimeBackgroundRequested && runtimeBridgeStatus.backgroundSupported {
                runtimeBridgeStatus = try await runtimeBridgeController.setBackgroundEnabled(true)
            }
        } catch {
            runtimeBridgeStatus = .init(connectionState: .offline, lastError: String(describing: error))
            recordLog(.warning, .runtime, "Runtime bridge unavailable", metadata: ["error": String(describing: error)])
        }
    }

    func refresh() {
        recordLog(.info, .source, "Repository refresh requested", metadata: ["count": "\(snapshot.sources.count)"])
        Task {
            let refreshed = await client.connectAndLoad(existingSources: snapshot.sources)
            snapshot = refreshed
            recordLog(.info, .source, "Repository refresh finished", metadata: ["packages": "\(snapshot.packages.count)"])
        }
    }

    func addSource() {
        sourceDraftError = nil
        let text = sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme), url.host != nil else {
            sourceDraftError = L("Enter a valid HTTP or HTTPS repository URL.")
            return
        }
        guard !snapshot.sources.contains(where: { $0.url == url.absoluteString }) else {
            sourceDraftError = L("This source is already added.")
            return
        }
        snapshot.sources.append(.init(id: url.absoluteString, url: url.absoluteString, packageCount: 0))
        Self.saveSources(snapshot.sources)
        recordLog(.info, .source, "Source added", metadata: ["url": url.absoluteString])
        sourceDraft = ""
        isAddSourcePresented = false
        Task {
            try? await client.syncSources(snapshot.sources)
            snapshot = await client.connectAndLoad(existingSources: snapshot.sources)
        }
    }

    func removeSources(at offsets: IndexSet) {
        let removed = offsets.sorted(by: >).compactMap { snapshot.sources.indices.contains($0) ? snapshot.sources[$0] : nil }
        for index in offsets.sorted(by: >) where snapshot.sources.indices.contains(index) { snapshot.sources.remove(at: index) }
        Self.saveSources(snapshot.sources)
        for source in removed { recordLog(.info, .source, "Source removed", metadata: ["url": source.url]) }
        syncSourcesAfterMutation()
    }

    func removeSource(_ source: PrismSourceRow) {
        guard let index = snapshot.sources.firstIndex(where: { $0.id == source.id }) else { return }
        snapshot.sources.remove(at: index)
        Self.saveSources(snapshot.sources)
        recordLog(.info, .source, "Source removed", metadata: ["url": source.url])
        syncSourcesAfterMutation()
    }

    private func syncSourcesAfterMutation() {
        Task {
            do { try await client.syncSources(snapshot.sources) }
            catch { recordLog(.warning, .source, "Source synchronization failed", metadata: ["error": String(describing: error)]) }
            snapshot = await client.connectAndLoad(existingSources: snapshot.sources)
        }
    }


    func preparePackageInstall(_ packageID: String) {
        installActionError = nil
        recordLog(.info, .package, "Install plan requested", metadata: ["package": packageID])
        Task {
            do {
                installPlanReview = try await client.prepareInstall(packageID: packageID)
                recordLog(.info, .package, "Install plan prepared", metadata: ["package": packageID])
            } catch {
                installActionError = String(describing: error)
                recordLog(.error, .package, "Install plan failed", metadata: ["package": packageID, "error": String(describing: error)])
            }
        }
    }

    func confirmPreparedInstall() {
        guard let review = installPlanReview else { return }
        isInstallSubmitting = true
        installActionError = nil
        Task {
            do {
                _ = try await client.confirmInstall(reviewID: review.id)
                recordLog(.info, .transaction, "Package transaction completed", metadata: ["package": review.requestedPackageID, "action": "install"])
                installPlanReview = nil
                snapshot = await client.connectAndLoad(existingSources: snapshot.sources)
            } catch {
                installActionError = String(describing: error)
                recordLog(.error, .transaction, "Package transaction failed", metadata: ["package": review.requestedPackageID, "action": "install", "error": String(describing: error)])
            }
            isInstallSubmitting = false
        }
    }

    func discardPreparedInstall() {
        guard let review = installPlanReview else { return }
        Task { await client.discardInstall(reviewID: review.id) }
        installPlanReview = nil
    }

    func preparePackageRemoval(_ packageID: String, complete: Bool) {
        removalActionError = nil
        recordLog(.info, .package, "Removal plan requested", metadata: ["package": packageID, "mode": complete ? "purge" : "remove"])
        Task {
            do {
                removalPlanReview = try await client.prepareRemoval(
                    packageID: packageID,
                    mode: complete ? .purge : .remove,
                    removeUnusedDependencies: false
                )
                recordLog(.info, .package, "Removal plan prepared", metadata: ["package": packageID])
            } catch {
                removalActionError = String(describing: error)
                recordLog(.error, .package, "Removal plan failed", metadata: ["package": packageID, "error": String(describing: error)])
            }
        }
    }

    func confirmPreparedRemoval() {
        guard let review = removalPlanReview else { return }
        isRemovalSubmitting = true
        removalActionError = nil
        Task {
            do {
                _ = try await client.confirmRemoval(reviewID: review.id)
                recordLog(.info, .transaction, "Package removal completed", metadata: ["package": review.requestedPackageID, "mode": review.mode.rawValue])
                removalPlanReview = nil
                snapshot = await client.connectAndLoad(existingSources: snapshot.sources)
            } catch {
                removalActionError = String(describing: error)
                recordLog(.error, .transaction, "Package removal failed", metadata: ["package": review.requestedPackageID, "error": String(describing: error)])
            }
            isRemovalSubmitting = false
        }
    }

    func discardPreparedRemoval() {
        guard let review = removalPlanReview else { return }
        Task { await client.discardRemoval(reviewID: review.id) }
        removalPlanReview = nil
    }

    func refreshApplications() {
        Task { await refreshApplicationsFromRuntime() }
    }

    private func refreshApplicationsFromRuntime() async {
        do {
            let appSnapshot = try await applicationManagementController.snapshot()
            snapshot.apps = appSnapshot.apps
            applicationActionError = nil
            recordLog(.info, .application, "Application state refreshed", metadata: ["count": "\(appSnapshot.apps.count)"])
        } catch {
            applicationActionError = String(describing: error)
            recordLog(.warning, .application, "Application state unavailable", metadata: ["error": String(describing: error)])
        }
    }

    func registerApplication(_ bundleIdentifier: String) {
        performApplicationAction("register", bundleIdentifier: bundleIdentifier) {
            try await self.applicationManagementController.register(bundleIdentifier: bundleIdentifier)
        }
    }

    func repairApplication(_ bundleIdentifier: String) {
        performApplicationAction("refresh", bundleIdentifier: bundleIdentifier) {
            try await self.applicationManagementController.refresh(bundleIdentifier: bundleIdentifier)
        }
    }

    func removeApplication(_ bundleIdentifier: String) {
        performApplicationAction("remove", bundleIdentifier: bundleIdentifier) {
            try await self.applicationManagementController.remove(bundleIdentifier: bundleIdentifier)
        }
    }

    private func performApplicationAction(
        _ action: String,
        bundleIdentifier: String,
        operation: @escaping @Sendable () async throws -> PrismApplicationActionResult
    ) {
        guard !isApplicationSubmitting else { return }
        isApplicationSubmitting = true
        applicationActionError = nil
        recordLog(.info, .application, "Application action requested", metadata: ["action": action, "bundle": bundleIdentifier])
        Task {
            do {
                let result = try await operation()
                snapshot.apps = result.apps
                if let index = snapshot.transactions.firstIndex(where: { $0.id == result.transaction.id }) {
                    snapshot.transactions[index] = result.transaction
                } else {
                    snapshot.transactions.append(result.transaction)
                }
                recordLog(.info, .transaction, "Application transaction completed", metadata: ["action": action, "bundle": bundleIdentifier])
            } catch {
                applicationActionError = String(describing: error)
                recordLog(.error, .transaction, "Application transaction failed", metadata: ["action": action, "bundle": bundleIdentifier, "error": String(describing: error)])
            }
            isApplicationSubmitting = false
        }
    }

    func sourceDetail(_ source: PrismSourceRow) -> PrismSourceDetailPresentation {
        PrismStorePresentationBuilder.sourceDetail(source, packages: snapshot.packages)
    }

    func resetPackageFilters() {
        packageSearch = ""
        storeCategory = .all
        storeSourceID = nil
        storeInstallationFilter = .all
        storeCommerceFilter = .all
        storeSort = .name
    }

    func simulateAppInstall() {
        guard !isSimulationRunning else { return }
        recordLog(.info, .simulation, "Application installation simulation started")
        isSimulationRunning = true
        simulationError = nil
        Task {
            do {
                _ = try await simulationCenter.simulateDemoInstall()
                simulationSnapshot = try await simulationCenter.snapshot()
                recordLog(.info, .simulation, "Application installation simulation completed")
            } catch {
                simulationError = String(describing: error)
            }
            isSimulationRunning = false
        }
    }

    func simulateInjection() {
        guard !isSimulationRunning else { return }
        recordLog(.info, .simulation, "Application injection simulation started")
        guard !simulationSnapshot.apps.isEmpty else {
            simulationError = L("Run the app-install simulation first.")
            return
        }
        isSimulationRunning = true
        simulationError = nil
        Task {
            do {
                _ = try await simulationCenter.simulateDemoInjection()
                simulationSnapshot = try await simulationCenter.snapshot()
                recordLog(.info, .simulation, "Application injection simulation completed")
            } catch {
                simulationError = String(describing: error)
            }
            isSimulationRunning = false
        }
    }

    func simulateInjectionRemoval() {
        guard !isSimulationRunning else { return }
        recordLog(.info, .simulation, "Application injection-removal simulation started")
        guard !simulationSnapshot.apps.isEmpty else {
            simulationError = L("No simulated app is installed.")
            return
        }
        isSimulationRunning = true
        simulationError = nil
        Task {
            do {
                _ = try await simulationCenter.simulateDemoInjectionRemoval()
                simulationSnapshot = try await simulationCenter.snapshot()
                recordLog(.info, .simulation, "Application injection-removal simulation completed")
            } catch {
                simulationError = String(describing: error)
            }
            isSimulationRunning = false
        }
    }

    func registerCommerceProvider(_ provider: any RepositoryCommerceProvider, identifier: String) {
        commerceProviders[identifier] = provider
        recordLog(.info, .commerce, "Commerce provider registered", metadata: ["provider": identifier])
    }

    func commerceActionAvailable(for row: PrismPackageRow) -> Bool {
        guard let providerID = row.commerce.providerIdentifier else { return false }
        return commerceProviders[providerID] != nil
    }

    func performCommerceAction(for row: PrismPackageRow) {
        guard let providerID = row.commerce.providerIdentifier, let provider = commerceProviders[providerID] else {
            commerceActionError = L("No purchase adapter is available for this source.")
            recordLog(.warning, .commerce, "Commerce action unavailable", metadata: ["package": row.id])
            return
        }
        guard !isCommerceSubmitting else { return }
        isCommerceSubmitting = true
        commerceActionError = nil
        Task {
            do {
                if row.commerce.state == .signInRequired {
                    try await provider.signIn()
                    let entitlement = await provider.entitlement(for: row.commerce.product)
                    updateCommerceState(packageID: row.id, repositoryID: row.repositoryID, state: entitlement.state)
                    recordLog(.info, .commerce, "Repository sign-in completed", metadata: ["package": row.id, "provider": providerID])
                } else {
                    let outcome = try await provider.purchase(row.commerce.product)
                    updateCommerceState(packageID: row.id, repositoryID: row.repositoryID, state: outcome.entitlement.state)
                    recordLog(.info, .commerce, "Purchase entitlement updated", metadata: ["package": row.id, "provider": providerID, "state": outcome.entitlement.state.rawValue])
                }
            } catch {
                commerceActionError = String(describing: error)
                recordLog(.error, .commerce, "Commerce action failed", metadata: ["package": row.id, "provider": providerID, "error": String(describing: error)])
            }
            isCommerceSubmitting = false
        }
    }

    private func updateCommerceState(packageID: String, repositoryID: String?, state: PrismCommerceAccessState) {
        snapshot.packages = snapshot.packages.map { row in
            guard row.id == packageID, row.repositoryID == repositoryID else { return row }
            let commerce = PrismCommercePresentation(
                state: state,
                priceDisplay: row.commerce.priceDisplay,
                providerIdentifier: row.commerce.providerIdentifier,
                product: row.commerce.product
            )
            return PrismPackageRow(
                id: row.id, name: row.name, version: row.version, description: row.description,
                installed: row.installed, updateAvailable: row.updateAvailable, iconURL: row.iconURL,
                repositoryID: row.repositoryID, sourceURL: row.sourceURL, commerce: commerce,
                author: row.author, architecture: row.architecture, category: row.category,
                trustLabel: row.trustLabel, distributionLabel: row.distributionLabel,
                dependencySummary: row.dependencySummary, conflictSummary: row.conflictSummary,
                requirementSummary: row.requirementSummary, updatedAt: row.updatedAt
            )
        }
    }

    func clearLogs() {
        Task {
            await logStore.clear()
            logEntries = []
            logExportText = ""
        }
    }

    private func recordLog(_ level: PrismLogLevel, _ category: PrismLogCategory, _ message: String, metadata: [String: String] = [:]) {
        Task {
            await logStore.append(level: level, category: category, message: message, metadata: metadata)
            logEntries = await logStore.entries()
            logExportText = await logStore.exportText()
        }
    }

    private static func loadSources() -> [PrismSourceRow] {
        let values = UserDefaults.standard.stringArray(forKey: "PrismSources") ?? []
        return values.map { .init(id: $0, url: $0, packageCount: 0) }
    }

    private static func saveSources(_ sources: [PrismSourceRow]) {
        UserDefaults.standard.set(sources.map(\.url), forKey: "PrismSources")
    }
}
