import SwiftUI
import UIKit
import PrismUIBridge
import PrismResolution
import PrismDomain

@MainActor
private final class PrismRemoteImageLoader: ObservableObject {
    static let cache = NSCache<NSURL, UIImage>()
    @Published private(set) var image: UIImage?
    private var task: Task<Void, Never>?

    func load(_ candidates: [String]) {
        task?.cancel()
        image = nil
        task = Task { [weak self] in
            guard let self else { return }
            for raw in candidates {
                guard !Task.isCancelled, let url = URL(string: raw) else { continue }
                if let cached = Self.cache.object(forKey: url as NSURL) {
                    image = cached
                    return
                }
                do {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .returnCacheDataElseLoad
                    request.timeoutInterval = 10
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { continue }
                    guard let decoded = UIImage(data: data) else { continue }
                    Self.cache.setObject(decoded, forKey: url as NSURL)
                    image = decoded
                    return
                } catch {
                    continue
                }
            }
        }
    }
}

private struct PrismRemoteIcon: View {
    let candidates: [String]
    let fallbackSystemImage: String
    let size: CGFloat
    let cornerRadius: CGFloat
    @StateObject private var loader = PrismRemoteImageLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.12))
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if fallbackSystemImage == "shippingbox" {
                Image(systemName: "shippingbox")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "tray.full")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .onAppear { loader.load(candidates) }
        .onChange(of: candidates) { loader.load($0) }
    }
}

private enum PrismSection: String, CaseIterable, Identifiable {
    case featured = "Featured"
    case packages = "Packages"
    case sources = "Sources"
    case apps = "Apps"
    case activity = "Activity"
    case installed = "Installed"
    case updates = "Updates"
    case settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .featured: return "sparkles"
        case .packages: return "shippingbox"
        case .sources: return "tray.full"
        case .apps: return "square.grid.2x2"
        case .activity: return "clock.arrow.circlepath"
        case .installed: return "checkmark.circle"
        case .updates: return "arrow.down.circle"
        case .settings: return "gearshape"
        }
    }
}

struct PrismRootView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var sidebarSelection: PrismSection? = .featured

    var body: some View {
        Group {
            if sizeClass == .regular { tabletLayout } else { phoneLayout }
        }
        .id(container.language.rawValue)
        .sheet(isPresented: $container.isSettingsPresented) {
            NavigationView { StoreSettingsView() }
        }
        .sheet(isPresented: $container.isAddSourcePresented) {
            NavigationView { StoreAddSourceView() }
        }
        .sheet(item: $container.installPlanReview) { review in
            NavigationView { InstallPlanReviewView(review: review) }
                .interactiveDismissDisabled(container.isInstallSubmitting)
        }
        .sheet(item: $container.removalPlanReview) { review in
            NavigationView { RemovalPlanReviewView(review: review) }
                .interactiveDismissDisabled(container.isRemovalSubmitting)
        }
    }

    private var phoneLayout: some View {
        TabView {
            RootNavigation(title: L("Featured")) { StoreFeaturedView() }.tabItem { Label(L("Featured"), systemImage: "sparkles") }
            RootNavigation(title: L("Packages")) { StorePackagesView() }.tabItem { Label(L("Packages"), systemImage: "shippingbox") }
            RootNavigation(title: L("Sources")) { StoreSourcesView() }.tabItem { Label(L("Sources"), systemImage: "tray.full") }
            RootNavigation(title: L("Apps")) { StoreAppsView() }.tabItem { Label(L("Apps"), systemImage: "square.grid.2x2") }
            RootNavigation(title: L("Activity")) { StoreActivityView() }.tabItem { Label(L("Activity"), systemImage: "clock.arrow.circlepath") }
        }
    }

    private var tabletLayout: some View {
        NavigationView {
            List(selection: $sidebarSelection) {
                Section {
                    sidebarRow(.featured); sidebarRow(.packages); sidebarRow(.sources); sidebarRow(.apps)
                }
                Section { sidebarRow(.installed); sidebarRow(.updates); sidebarRow(.activity) } header: { Text(L("Library")) }
                Section { sidebarRow(.settings) }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Prism")

            tabletDetail(sidebarSelection ?? .featured)
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }

    @ViewBuilder private func sidebarRow(_ section: PrismSection) -> some View {
        Label(L(section.rawValue), systemImage: section.icon).tag(Optional(section))
    }

    @ViewBuilder private func tabletDetail(_ section: PrismSection) -> some View {
        switch section {
        case .featured: RootNavigation(title: L("Featured")) { StoreFeaturedView() }
        case .packages: RootNavigation(title: L("Packages")) { StorePackagesView() }
        case .sources: RootNavigation(title: L("Sources")) { StoreSourcesView() }
        case .apps: RootNavigation(title: L("Apps")) { StoreAppsView() }
        case .activity: RootNavigation(title: L("Activity")) { StoreActivityView() }
        case .installed: RootNavigation(title: L("Installed")) { StorePackagesListView(rows: container.installedPackages) }
        case .updates: RootNavigation(title: L("Updates")) { StorePackagesListView(rows: container.updatePackages) }
        case .settings: NavigationView { StoreSettingsView() }
        }
    }
}

private struct RootNavigation<Content: View>: View {
    @EnvironmentObject private var container: AppContainer
    let title: String
    let content: () -> Content
    init(title: String, @ViewBuilder content: @escaping () -> Content) { self.title = title; self.content = content }
    var body: some View {
        NavigationView {
            content()
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { container.isSettingsPresented = true } label: { Image(systemName: "gearshape") }
                    }
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct FeaturedView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: "triangle.fill").font(.system(size: 34, weight: .bold)).foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Prism").font(.title.bold())
                        Text(L("Packages, apps and transactions in one place.")).foregroundColor(.secondary)
                    }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 18).fill(Color.secondary.opacity(0.10)))

                StatusCard()
                metricGrid
                if !container.snapshot.packages.isEmpty {
                    Text(L("Recently Seen")).font(.headline)
                    ForEach(Array(container.snapshot.packages.prefix(4))) { PackageRow(row: $0) }
                }
            }.padding()
        }
        .refreshableCompat { container.refresh() }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
            MetricCard(value: "\(container.snapshot.packages.count)", label: L("Packages"))
            MetricCard(value: "\(container.snapshot.sources.count)", label: L("Sources"))
            MetricCard(value: "\(container.snapshot.transactions.count)", label: L("Activity"))
        }
    }
}

private struct MetricCard: View {
    let value: String; let label: String
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(value).font(.title2.bold()); Text(label).font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.08))) }
}

private struct StatusCard: View {
    @EnvironmentObject private var container: AppContainer
    private var packageServiceValue: String {
        container.snapshot.environment.dailyRows.first(where: { $0.title == "Package Service" })?.value ?? container.serviceStatusText
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(container.snapshot.serviceStatus == .connected ? Color.green : (container.snapshot.serviceStatus == .recovering ? Color.orange : Color.secondary))
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Package Service")).font(.headline)
                Text(L(packageServiceValue)).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            Button(L("Reconnect")) { container.reconnect() }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.08)))
    }
}

private struct PackagesView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            if !container.installedPackages.isEmpty {
                Section { NavigationLink(LF("View %d installed packages", container.installedPackages.count)) { PackageListView(rows: container.installedPackages).navigationTitle(L("Installed")) } } header: { Text(L("Installed")) }
            }
            if !container.updatePackages.isEmpty {
                Section { NavigationLink(LF("%d updates available", container.updatePackages.count)) { PackageListView(rows: container.updatePackages).navigationTitle(L("Updates")) } } header: { Text(L("Updates")) }
            }
            Section {
                if container.filteredPackages.isEmpty { EmptyState(icon: "shippingbox", title: "No packages", subtitle: "Add a source or reconnect to the package service.") }
                ForEach(container.filteredPackages) { row in NavigationLink(destination: PackageDetailView(row: row)) { PackageRow(row: row) } }
            } header: { Text(L("All Packages")) }
        }
        .searchableCompat(text: $container.packageSearch, prompt: L("Search packages"))
    }
}

private struct PackageListView: View {
    let rows: [PrismPackageRow]
    var body: some View { List { if rows.isEmpty { EmptyState(icon: "shippingbox", title: "Nothing here", subtitle: "This section will update when package state changes.") }; ForEach(rows) { row in NavigationLink(destination: PackageDetailView(row: row)) { PackageRow(row: row) } } } }
}

private struct PackageRow: View {
    let row: PrismPackageRow
    var body: some View {
        HStack(spacing: 12) {
            PrismRemoteIcon(
                candidates: row.iconURL.map { [$0] } ?? [],
                fallbackSystemImage: "shippingbox",
                size: 42,
                cornerRadius: 10
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(row.name).font(.headline)
                Text(row.id).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(row.version).font(.caption).foregroundColor(.secondary)
                if row.commerce.state != .free {
                    Text(commerceLabel(row.commerce))
                        .font(.caption2.bold())
                        .foregroundColor(row.commerce.state == .owned ? .green : .secondary)
                }
            }
        }.padding(.vertical, 3)
    }
}

private func commerceLabel(_ commerce: PrismCommercePresentation) -> String {
    switch commerce.state {
    case .free: return L("Free")
    case .paid: return commerce.priceDisplay ?? L("Paid")
    case .owned: return L("Owned")
    case .signInRequired: return L("Sign In Required")
    case .unavailable: return L("Purchase Unavailable")
    }
}

private struct PackageDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let row: PrismPackageRow

    private var actionTitle: String {
        if row.updateAvailable { return L("Update") }
        if row.installed { return L("Installed") }
        return L("Install")
    }

    private var canRequestChange: Bool {
        !row.installed || row.updateAvailable
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    PrismRemoteIcon(
                        candidates: row.iconURL.map { [$0] } ?? [],
                        fallbackSystemImage: "shippingbox",
                        size: 62,
                        cornerRadius: 14
                    )
                    VStack(alignment: .leading) {
                        Text(row.name).font(.title3.bold())
                        Text(row.id).font(.caption).foregroundColor(.secondary)
                        Text(row.version).font(.subheadline)
                    }
                }
            }
            Section { Text(row.description.isEmpty ? L("No description provided.") : row.description) } header: { Text(L("Description")) }
            Section {
                Label(row.installed ? L("Installed") : L("Not Installed"), systemImage: row.installed ? "checkmark.circle.fill" : "circle")
                if row.updateAvailable { Label(L("Update Available"), systemImage: "arrow.down.circle.fill") }
            } header: { Text(L("State")) }
            Section(header: Text(L("Access"))) {
                HStack {
                    Text(commerceLabel(row.commerce))
                    Spacer()
                    if let price = row.commerce.priceDisplay, row.commerce.state != .owned { Text(price).foregroundColor(.secondary) }
                }
                if row.commerce.state == .paid {
                    Button(container.isCommerceSubmitting ? L("Working…") : L("Purchase")) { container.performCommerceAction(for: row) }
                        .disabled(!container.commerceActionAvailable(for: row) || container.isCommerceSubmitting)
                } else if row.commerce.state == .signInRequired {
                    Button(container.isCommerceSubmitting ? L("Working…") : L("Sign In")) { container.performCommerceAction(for: row) }
                        .disabled(!container.commerceActionAvailable(for: row) || container.isCommerceSubmitting)
                }
                if [.paid, .signInRequired].contains(row.commerce.state) && !container.commerceActionAvailable(for: row) {
                    Text(L("No purchase adapter is available for this source."))
                        .font(.caption).foregroundColor(.secondary)
                }
                if row.commerce.state == .owned {
                    Text(L("Purchase entitlement is owned. Installation still goes through Prism's normal InstallPlan and transaction review."))
                        .font(.caption).foregroundColor(.secondary)
                }
                if let error = container.commerceActionError {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            Section {
                Button(actionTitle) { container.preparePackageInstall(row.id) }
                    .disabled(!canRequestChange || container.snapshot.serviceStatus != .connected || container.isInstallSubmitting)
                if container.snapshot.serviceStatus != .connected && canRequestChange {
                    Text(L("Connect to the package service before making package changes."))
                        .font(.caption).foregroundColor(.secondary)
                } else if canRequestChange {
                    Text(L("Prism will show the InstallPlan before any system change is submitted."))
                        .font(.caption).foregroundColor(.secondary)
                }
                if let error = container.installActionError {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            if row.installed {
                Section(header: Text(L("Removal"))) {
                    Button(L("Remove"), role: .destructive) {
                        container.preparePackageRemoval(row.id, complete: false)
                    }
                    .disabled(container.snapshot.serviceStatus != .connected || container.isRemovalSubmitting)
                    Button(L("Complete Removal"), role: .destructive) {
                        container.preparePackageRemoval(row.id, complete: true)
                    }
                    .disabled(container.snapshot.serviceStatus != .connected || container.isRemovalSubmitting)
                    Text(L("Complete Removal also removes package-managed configuration. Dependencies are preserved unless a future provider can prove they are safe to clean."))
                        .font(.caption).foregroundColor(.secondary)
                    if let error = container.removalActionError {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle(row.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InstallPlanReviewView: View {
    @EnvironmentObject private var container: AppContainer
    let review: PrismInstallPlanReview

    var body: some View {
        List {
            Section(header: Text(L("Requested"))) { Text(review.requestedPackageID) }
            if !review.installs.isEmpty {
                Section(header: Text(L("Install"))) {
                    ForEach(review.installs) { change in
                        HStack { Text(change.name); Spacer(); Text(change.version).foregroundColor(.secondary) }
                    }
                }
            }
            if !review.upgrades.isEmpty {
                Section(header: Text(L("Upgrade"))) {
                    ForEach(review.upgrades) { change in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(change.name)
                            Text("\(change.fromVersion) → \(change.toVersion)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            if !review.removals.isEmpty {
                Section(header: Text(L("Remove"))) { ForEach(review.removals) { change in Text(change.name) } }
            }
            if !review.conflicts.isEmpty {
                Section(header: Text(L("Conflicts"))) { ForEach(review.conflicts, id: \.self) { Text($0).foregroundColor(.red) } }
            }
            if !review.unmetCapabilities.isEmpty {
                Section(header: Text(L("Unavailable Capabilities"))) { ForEach(review.unmetCapabilities, id: \.self) { Text($0) } }
            }
            if let error = container.installActionError {
                Section(header: Text(L("Error"))) { Text(error).foregroundColor(.red) }
            }
        }
        .navigationTitle(L("Review Changes"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("Cancel")) { container.discardPreparedInstall() }
                    .disabled(container.isInstallSubmitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(container.isInstallSubmitting ? L("Working…") : L("Confirm")) { container.confirmPreparedInstall() }
                    .disabled(!review.isExecutable || container.isInstallSubmitting)
            }
        }
    }
}

private struct RemovalPlanReviewView: View {
    @EnvironmentObject private var container: AppContainer
    let review: PrismPackageRemovalReview

    var body: some View {
        List {
            Section(header: Text(L("Requested"))) {
                Text(review.requestedPackageID)
            }
            Section(header: Text(L("Removal Mode"))) {
                Label(
                    review.mode == .purge ? L("Complete Removal") : L("Remove"),
                    systemImage: review.mode == .purge ? "trash.slash" : "trash"
                )
                if review.removesConfiguration {
                    Text(L("Delete package configuration and managed cache data."))
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text(L("Keep package configuration and user preferences where the package manager marks them as persistent."))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Section(header: Text(L("Packages to Remove"))) {
                ForEach(review.packagesToRemove) { change in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(change.name)
                            Text(change.identifier).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(change.version).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            if !review.preservedDependencies.isEmpty {
                Section(header: Text(L("Preserved Dependencies"))) {
                    ForEach(review.preservedDependencies) { dependency in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dependency.name)
                            Text(dependency.identifier).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Text(L("Shared or unproven dependencies are kept to avoid removing files another package may need."))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Section(header: Text(L("Residue Verification"))) {
                Label(L("Prism verifies package state again after removal."), systemImage: "checkmark.shield")
                if review.residueCheckRequired {
                    Text(L("If the package database still reports a planned package, the operation is treated as incomplete instead of silently succeeding."))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            if !review.unmetCapabilities.isEmpty {
                Section(header: Text(L("Unavailable Capabilities"))) {
                    ForEach(review.unmetCapabilities, id: \.self) { Text($0) }
                }
            }
            if let error = container.removalActionError {
                Section(header: Text(L("Error"))) { Text(error).foregroundColor(.red) }
            }
        }
        .navigationTitle(L("Review Removal"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("Cancel")) { container.discardPreparedRemoval() }
                    .disabled(container.isRemovalSubmitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(container.isRemovalSubmitting ? L("Working…") : L("Confirm"), role: .destructive) {
                    container.confirmPreparedRemoval()
                }
                .disabled(!review.isExecutable || container.isRemovalSubmitting)
            }
        }
    }
}

private struct SourcesView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            Section { Button { container.isAddSourcePresented = true } label: { Label(L("Add Source"), systemImage: "plus.circle.fill") } }
            Section {
                if container.snapshot.sources.isEmpty { EmptyState(icon: "tray", title: "No sources", subtitle: "Add a Debian/APT or Sileo-compatible repository.") }
                ForEach(container.snapshot.sources) { source in
                    NavigationLink(destination: SourceDetailView(source: source)) {
                        HStack(alignment: .top, spacing: 12) {
                            PrismRemoteIcon(candidates: source.iconURLs, fallbackSystemImage: "tray.full", size: 44, cornerRadius: 10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.displayName).font(.headline).lineLimit(1)
                                Text(source.url).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                Text(LF("%d indexed packages", source.packageCount)).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete(perform: container.removeSources)
            } header: { Text(L("Repositories")) }
        }
    }
}

private struct SourceDetailView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.presentationMode) private var presentation
    let source: PrismSourceRow
    @State private var searchText = ""
    @State private var confirmRemoval = false

    private var packages: [PrismPackageRow] {
        PrismRepositoryScope.filteredPackages(container.snapshot.packages, sourceURL: source.url, query: searchText)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    PrismRemoteIcon(candidates: source.iconURLs, fallbackSystemImage: "tray.full", size: 60, cornerRadius: 14)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.displayName).font(.title3.bold())
                        Text(source.url).font(.caption).foregroundColor(.secondary).textSelectionCompat()
                        Text(LF("%d indexed packages", source.packageCount)).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Section(header: Text(L("Packages in this Source"))) {
                if packages.isEmpty { EmptyState(icon: "shippingbox", title: "No matching packages", subtitle: "Try a different search or refresh this source.") }
                ForEach(packages) { row in
                    NavigationLink(destination: PackageDetailView(row: row)) { PackageRow(row: row) }
                }
            }
            if let providerID = source.commerceProviderIdentifier {
                Section(header: Text(L("Purchases"))) {
                    LabeledContentCompat(label: L("Purchase Provider"), value: providerID)
                    Text(L("Accounts and payments are owned by the repository. Prism only consumes normalized entitlement results and never stores card details."))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Section(header: Text(L("Source Management"))) {
                Button(L("Remove Source"), role: .destructive) { confirmRemoval = true }
                Text(L("Removing a source only removes its repository registration from Prism. Installed packages are not automatically removed."))
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .searchableCompat(text: $searchText, prompt: L("Search this source"))
        .navigationTitle(source.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("Remove Source?"), isPresented: $confirmRemoval) {
            Button(L("Cancel"), role: .cancel) { }
            Button(L("Remove Source"), role: .destructive) {
                container.removeSource(source)
                presentation.wrappedValue.dismiss()
            }
        } message: {
            Text(L("This source will be removed from Prism. Installed packages remain installed."))
        }
    }
}

private struct AddSourceView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.presentationMode) private var presentation
    var body: some View {
        Form {
            Section(header: Text(L("Repository URL"))) { TextField("https://repo.example/", text: $container.sourceDraft).textInputAutocapitalizationCompatNever().disableAutocorrection(true) }
            Section { Text(L("Prism normalizes compatible Debian/APT and Sileo repository metadata into its own package model.")).font(.caption).foregroundColor(.secondary) }
        }
        .navigationTitle(L("Add Source"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { presentation.wrappedValue.dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button(L("Add")) { container.addSource() }.disabled(container.sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }
}

private struct AppsView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            if let integration = container.snapshot.integration {
                Section(header: Text(L("Prism Integration"))) {
                    ForEach(Array(integration.rows.enumerated()), id: \.offset) { _, row in
                        StatusSettingRow(row: row)
                    }
                }
            }
            Section(header: Text(L("Capabilities"))) {
                capabilityRow("Application Installation", systemImage: "square.and.arrow.down", key: "appInstall")
                capabilityRow("Application Injection", systemImage: "puzzlepiece.extension", key: "appInjection")
            }
            Section(header: Text(L("Installed Apps"))) {
                if container.snapshot.apps.isEmpty {
                    EmptyState(icon: "square.grid.2x2", title: "No app data", subtitle: "Connect to a compatible app-management provider to inspect installed apps.")
                }
                ForEach(container.snapshot.apps) { app in
                    NavigationLink(destination: AppDetailView(app: app)) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name).font(.headline)
                                Text(app.id).font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            if app.injectionCount > 0 {
                                Text("\(app.injectionCount)").font(.caption.bold()).padding(6).background(Capsule().fill(Color.secondary.opacity(0.12)))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            Section(header: Text(L("App Management"))) {
                NavigationLink(L("Application Installation")) { ApplicationCapabilityView(feature: .installation) }
                NavigationLink(L("Application Injection")) { ApplicationCapabilityView(feature: .injection) }
                NavigationLink(L("Simulation Environment")) { AppSimulationInfoView() }
            }
        }
    }

    @ViewBuilder private func capabilityRow(_ title: String, systemImage: String, key: String) -> some View {
        HStack(spacing: 12) {
            Label(L(title), systemImage: systemImage)
            Spacer(minLength: 8)
            CapabilityBadge(presentation: container.snapshot.environment.capability(key))
        }
    }
}

private enum ApplicationManagementFeature { case installation, injection }

private struct ApplicationCapabilityView: View {
    @EnvironmentObject private var container: AppContainer
    let feature: ApplicationManagementFeature

    private var key: String { feature == .installation ? "appInstall" : "appInjection" }
    private var title: String { feature == .installation ? L("Application Installation") : L("Application Injection") }
    private var systemImage: String { feature == .installation ? "square.and.arrow.down" : "puzzlepiece.extension" }

    var body: some View {
        List {
            Section {
                Label(title, systemImage: systemImage).font(.headline)
                CapabilityBadge(presentation: container.snapshot.environment.capability(key))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section(header: Text(L("Runtime Capability"))) {
                if container.snapshot.environment.capability(key).isUsable {
                    Text(L("A compatible runtime provider is available. Real changes must still pass Prism's plan, transaction, journal and reconcile pipeline."))
                } else {
                    Text(L("This feature is unavailable in the current environment. Prism will not attempt a real operation without a compatible runtime provider."))
                }
            }
            Section(header: Text(L("Testing"))) {
                NavigationLink(L("Open Simulation Environment")) { AppSimulationInfoView(focus: feature == .installation ? .appInstall : .injection) }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let app: PrismAppRow
    var body: some View {
        List {
            Section {
                Text(app.name).font(.title3.bold())
                Text(app.id).font(.caption).foregroundColor(.secondary).textSelectionCompat()
            }
            Section(header: Text(L("Version"))) { Text(app.version) }
            Section(header: Text(L("Injection"))) {
                Text(app.injectionCount == 0 ? L("No active injection records") : LF("%d active injection records", app.injectionCount))
                NavigationLink(L("Application Injection")) { ApplicationCapabilityView(feature: .injection) }
            }
        }
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CapabilityBadge: View {
    let presentation: PrismCapabilityPresentation
    private var tint: Color {
        switch presentation.state {
        case .available: return .green
        case .degraded: return .orange
        case .unavailable: return .secondary
        case .unknown: return .secondary
        }
    }
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(L(presentation.label)).font(.caption.bold()).foregroundColor(tint)
            if let detail = presentation.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum SimulationFocus { case appInstall, injection }

struct AppSimulationInfoView: View {
    @EnvironmentObject private var container: AppContainer
    let focus: SimulationFocus?
    init(focus: SimulationFocus? = nil) { self.focus = focus }
    var body: some View {
        List {
            Section {
                Label(L("Non-destructive simulation"), systemImage: "checkmark.shield")
                Text(L("The simulation environment exercises the real Plan → Transaction → Journal → Reconcile flow against isolated application state. It never modifies a real app bundle."))
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Section(header: Text(L("Application Installation Flow"))) {
                Button(container.isSimulationRunning ? L("Running…") : L("Simulate IPA Install")) { container.simulateAppInstall() }
                    .disabled(container.isSimulationRunning)
                    .frame(minHeight: 44)
                Label(L("IPA metadata → AppInstallPlan → registration"), systemImage: "list.bullet.rectangle")
                    .font(.subheadline)
            }
            Section(header: Text(L("Application Injection Flow"))) {
                Button(container.isSimulationRunning ? L("Running…") : L("Simulate dylib Injection")) { container.simulateInjection() }
                    .disabled(container.isSimulationRunning || container.simulationSnapshot.apps.isEmpty)
                    .frame(minHeight: 44)
                Button(L("Simulate Injection Removal")) { container.simulateInjectionRemoval() }
                    .disabled(container.isSimulationRunning || !hasInjection)
                    .frame(minHeight: 44)
            }
            if !container.simulationSnapshot.apps.isEmpty {
                Section(header: Text(L("Simulated Apps"))) {
                    ForEach(container.simulationSnapshot.apps) { app in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name).font(.headline)
                                Text(app.id).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(app.injectionCount == 1 ? LF("%d injection", app.injectionCount) : LF("%d injections", app.injectionCount))
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            if !container.simulationSnapshot.transactions.isEmpty {
                Section(header: Text(L("Simulation Transactions"))) {
                    ForEach(container.simulationSnapshot.transactions) { tx in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(tx.title).font(.subheadline).lineLimit(2)
                            HStack { Text(L(tx.phase.capitalized)); Spacer(); Text("\(Int(tx.progress * 100))%") }
                                .font(.caption).foregroundColor(.secondary)
                            ProgressView(value: tx.progress)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            if let error = container.simulationError {
                Section(header: Text(L("Simulation Status"))) { Text(error).font(.caption).foregroundColor(.secondary) }
            } else if focus != nil {
                Section(header: Text(L("Simulation Status"))) { Text(L("Ready. No real application is modified.")).font(.caption).foregroundColor(.secondary) }
            }
        }
        .navigationTitle(L("Simulation Environment"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasInjection: Bool {
        container.simulationSnapshot.apps.contains { $0.injectionCount > 0 }
    }
}

private struct ActivityView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            Section(header: Text(L("Transactions"))) {
                if container.snapshot.transactions.isEmpty { EmptyState(icon: "clock.arrow.circlepath", title: "No transactions", subtitle: "Confirmed package and app changes will appear here.") }
                ForEach(container.snapshot.transactions) { tx in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text(tx.title).font(.headline).lineLimit(1); Spacer(); Text(L(tx.phase.capitalized)).font(.caption).foregroundColor(.secondary) }
                        ProgressView(value: tx.progress)
                    }
                }
            }
            Section(header: Text(L("Global Log"))) {
                NavigationLink(L("View Global Log")) { GlobalLogView() }
                if container.logEntries.isEmpty {
                    Text(L("No log entries yet.")).font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(Array(container.logEntries.suffix(5).reversed())) { entry in CompactLogRow(entry: entry) }
                }
            }
        }
    }
}

private enum PrismLogUIFilter: String, CaseIterable, Identifiable {
    case all, info, warning, error
    var id: String { rawValue }
}

private struct CompactLogRow: View {
    let entry: PrismLogEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(L(entry.category.rawValue.capitalized)).font(.caption.bold())
                Spacer()
                Text(entry.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
            }
            Text(entry.message).font(.caption).lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

struct GlobalLogView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var filter: PrismLogUIFilter = .all
    @State private var searchText = ""

    private var rows: [PrismLogEntry] {
        let minimum: PrismLogLevel? = {
            switch filter { case .all: return nil; case .info: return .info; case .warning: return .warning; case .error: return .error }
        }()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return container.logEntries.reversed().filter { entry in
            let levelOK: Bool
            if let minimum {
                let rank: [PrismLogLevel: Int] = [.debug: 0, .info: 1, .warning: 2, .error: 3]
                levelOK = rank[entry.level, default: 0] >= rank[minimum, default: 0]
            } else { levelOK = true }
            guard levelOK else { return false }
            guard !query.isEmpty else { return true }
            return entry.message.lowercased().contains(query) || entry.category.rawValue.lowercased().contains(query)
        }
    }

    var body: some View {
        List {
            Section {
                Picker(L("Log Level"), selection: $filter) {
                    Text(L("All")).tag(PrismLogUIFilter.all)
                    Text(L("Info+")).tag(PrismLogUIFilter.info)
                    Text(L("Warning+")).tag(PrismLogUIFilter.warning)
                    Text(L("Errors Only")).tag(PrismLogUIFilter.error)
                }
            }
            Section(header: Text(L("Entries"))) {
                if rows.isEmpty { Text(L("No matching log entries.")).foregroundColor(.secondary) }
                ForEach(rows) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L(entry.level.rawValue.capitalized)).font(.caption.bold())
                            Text(L(entry.category.rawValue.capitalized)).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(entry.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
                        }
                        Text(entry.message).font(.subheadline)
                        if !entry.metadata.isEmpty {
                            Text(entry.metadata.keys.sorted().map { "\($0)=\(entry.metadata[$0]!)" }.joined(separator: " · "))
                                .font(.caption2).foregroundColor(.secondary).textSelectionCompat()
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .searchableCompat(text: $searchText, prompt: L("Search logs"))
        .navigationTitle(L("Global Log"))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { UIPasteboard.general.string = container.logExportText } label: { Image(systemName: "doc.on.doc") }
                Button(role: .destructive) { container.clearLogs() } label: { Image(systemName: "trash") }
            }
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.presentationMode) private var presentation
    var body: some View {
        Form {
            Section {
                Picker(L("Language"), selection: $container.language) {
                    ForEach(PrismLanguage.allCases) { language in
                        Text(L(language.localizationKey)).tag(language)
                    }
                }
            } header: { Text(L("Language")) }
            Section(header: Text(L("Runtime"))) {
                ForEach(Array(container.snapshot.environment.dailyRows.enumerated()), id: \.offset) { _, row in
                    StatusSettingRow(row: row)
                }
                Button(L("Reconnect Package Service")) { container.reconnect() }
                    .frame(minHeight: 44)
            }
            Section(header: Text(L("Runtime Background Service"))) {
                Toggle(isOn: Binding(
                    get: { container.runtimeBackgroundRequested },
                    set: { container.setRuntimeBackgroundEnabled($0) }
                )) {
                    Text(L("Enable Runtime Background Service"))
                }
                .disabled(!container.runtimeBridgeStatus.backgroundSupported)

                LabeledContentCompat(
                    label: L("Runtime Bridge Status"),
                    value: L(container.runtimeBridgeStatus.connectionState.rawValue.capitalized)
                )
                LabeledContentCompat(
                    label: L("Background State"),
                    value: L(container.runtimeBridgeStatus.backgroundState.rawValue.capitalized)
                )
                if let runtime = container.runtimeBridgeStatus.runtimeDisplayName, !runtime.isEmpty {
                    LabeledContentCompat(label: L("Runtime"), value: runtime)
                }
                Text(L("This switch only controls a background session already authorized by the current runtime. Prism does not create jailbreak or system privileges."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(L("Reconnect Runtime Bridge")) { container.reconnectRuntimeBridge() }
                    .frame(minHeight: 44)
            }
            if let integration = container.snapshot.integration {
                Section(header: Text(L("Prism Integration"))) {
                    ForEach(Array(integration.rows.enumerated()), id: \.offset) { _, row in
                        StatusSettingRow(row: row)
                    }
                }
            }
            Section(header: Text(L("Capabilities"))) {
                capabilityRow("Package Install", key: "packageInstall")
                capabilityRow("Package Remove", key: "packageRemove")
                capabilityRow("Package Upgrade", key: "packageUpgrade")
                capabilityRow("Application Installation", key: "appInstall")
                capabilityRow("Application Injection", key: "appInjection")
                capabilityRow("Source Build", key: "sourceBuild")
            }
            Section(header: Text(L("Recovery"))) {
                Text(L("Confirmed transactions are journaled and reconciled against actual state after reconnect or runtime interruption. A UI disconnect is not treated as transaction failure."))
                    .font(.caption).foregroundColor(.secondary)
            }
            Section(header: Text(L("Diagnostics"))) {
                NavigationLink(L("Advanced Diagnostics")) { AdvancedDiagnosticsView() }
                NavigationLink(L("Global Log")) { GlobalLogView() }
                if let error = container.snapshot.lastError {
                    Text(error).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(L("Settings"))
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { presentation.wrappedValue.dismiss() } } }
    }

    @ViewBuilder private func capabilityRow(_ name: String, key: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L(name))
            CapabilityBadge(presentation: container.snapshot.environment.capability(key))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct StatusSettingRow: View {
    let row: PrismStatusRow
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L(row.title))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(L(row.value))
                .fixedSize(horizontal: false, vertical: true)
            if let detail = row.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

private struct AdvancedStatusRow: View {
    let row: PrismStatusRow
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L(row.title))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(L(row.value))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .textSelectionCompat()
            if let detail = row.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

private struct AdvancedDiagnosticsView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            Section(header: Text(L("Provider Diagnostics"))) {
                ForEach(Array(container.snapshot.environment.advancedRows.enumerated()), id: \.offset) { _, row in
                    AdvancedStatusRow(row: row)
                }
            }
            Section(header: Text(L("Note"))) {
                Text(L("Implementation paths are redacted in Prism diagnostics. Legacy compatibility details are shown here only when they are relevant to troubleshooting."))
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .navigationTitle(L("Advanced Diagnostics"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EmptyState: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View { HStack(spacing: 12) { Image(systemName: icon).font(.title2).foregroundColor(.secondary); VStack(alignment: .leading, spacing: 3) { Text(L(title)).font(.headline); Text(L(subtitle)).font(.caption).foregroundColor(.secondary) } }.padding(.vertical, 8) }
}

private struct LabeledContentCompat: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 12)
            Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing).textSelectionCompat()
        }
    }
}

// MARK: - iOS 15 compatibility helpers
private extension View {
    @ViewBuilder func searchableCompat(text: Binding<String>, prompt: String) -> some View {
        if #available(iOS 15.0, *) { self.searchable(text: text, prompt: prompt) } else { self }
    }
    @ViewBuilder func refreshableCompat(action: @escaping () -> Void) -> some View {
        if #available(iOS 15.0, *) { self.refreshable { action() } } else { self }
    }
    @ViewBuilder func textInputAutocapitalizationCompatNever() -> some View {
        if #available(iOS 15.0, *) { self.textInputAutocapitalization(.never) } else { self }
    }
    @ViewBuilder func textSelectionCompat() -> some View {
        if #available(iOS 15.0, *) { self.textSelection(.enabled) } else { self }
    }
}
