import SwiftUI
import PrismDomain
import PrismUIBridge

struct StorePackagesView: View {
    @EnvironmentObject private var container: AppContainer
    let initialCategory: PrismStoreCategory?
    init(initialCategory: PrismStoreCategory? = nil) { self.initialCategory = initialCategory }

    var body: some View {
        List {
            Section(header: Text(L("Filters"))) {
                Picker(L("Category"), selection: $container.storeCategory) {
                    Text(L("All")).tag(PrismStoreCategory.all)
                    ForEach(container.storeOverview.categories) { category in Text(category.displayName).tag(category) }
                }
                Picker(L("Source"), selection: $container.storeSourceID) {
                    Text(L("All Sources")).tag(Optional<String>.none)
                    ForEach(container.snapshot.sources) { source in Text(source.displayName).tag(Optional(source.id)) }
                }
                Picker(L("Status"), selection: $container.storeInstallationFilter) {
                    Text(L("All")).tag(PrismPackageInstallationFilter.all)
                    Text(L("Installed")).tag(PrismPackageInstallationFilter.installed)
                    Text(L("Available")).tag(PrismPackageInstallationFilter.available)
                    Text(L("Updates")).tag(PrismPackageInstallationFilter.updates)
                }
                Picker(L("Commerce"), selection: $container.storeCommerceFilter) {
                    Text(L("All")).tag(PrismPackageCommerceFilter.all)
                    Text(L("Free")).tag(PrismPackageCommerceFilter.free)
                    Text(L("Paid")).tag(PrismPackageCommerceFilter.paid)
                    Text(L("Owned")).tag(PrismPackageCommerceFilter.owned)
                }
                Picker(L("Sort"), selection: $container.storeSort) {
                    Text(L("Name")).tag(PrismPackageSort.name)
                    Text(L("Newest")).tag(PrismPackageSort.newest)
                    Text(L("Installed")).tag(PrismPackageSort.installed)
                    Text(L("Updates")).tag(PrismPackageSort.updates)
                }
                Button(L("Reset Filters")) { container.resetPackageFilters() }
            }
            Section(header: Text(L("Packages"))) {
                if container.filteredPackages.isEmpty { StoreEmptyState(icon: "shippingbox", title: "No matching packages", subtitle: "Change filters, search text, or refresh your sources.") }
                ForEach(container.filteredPackages) { row in
                    NavigationLink { StorePackageDetailView(row: row) } label: { StorePackageRowView(row: row) }
                }
            }
        }
        .searchable(text: $container.packageSearch, prompt: L("Search packages"))
        .refreshable { container.refresh() }
        .onAppear { if let initialCategory { container.storeCategory = initialCategory } }
    }
}

struct StorePackagesListView: View {
    let rows: [PrismPackageRow]
    var body: some View {
        List(rows) { row in NavigationLink { StorePackageDetailView(row: row) } label: { StorePackageRowView(row: row) } }
    }
}

struct StorePackageDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let row: PrismPackageRow
    private var detail: PrismPackageDetailPresentation { PrismStorePresentationBuilder.packageDetail(row) }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    StoreRemoteIcon(candidates: row.iconURL.map { [$0] } ?? [], fallback: "shippingbox", size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.name).font(.title3.bold())
                        Text(row.id).font(.caption).foregroundColor(.secondary)
                        Text(row.version).font(.subheadline)
                    }
                }
                Text(row.description)
            }
            Section(header: Text(L("Package Information"))) {
                detailRow("Author", detail.author ?? L("Unknown"))
                detailRow("Architecture", detail.architecture ?? L("Unknown"))
                detailRow("Category", detail.category)
                detailRow("Trust", detail.trustLabel)
                detailRow("Format", detail.distributionLabel)
                if let source = detail.sourceURL { detailRow("Source", source) }
            }
            if !detail.dependencies.isEmpty { Section(header: Text(L("Dependencies"))) { ForEach(detail.dependencies, id: \.self) { Text($0) } } }
            if !detail.conflicts.isEmpty { Section(header: Text(L("Conflicts"))) { ForEach(detail.conflicts, id: \.self) { Text($0) } } }
            if !detail.requirements.isEmpty { Section(header: Text(L("Requirements"))) { ForEach(detail.requirements, id: \.self) { Text($0) } } }
            Section(header: Text(L("Access"))) {
                detailRow("Commerce", L(detail.commerceState.rawValue.capitalized))
                if let price = detail.priceDisplay { detailRow("Price", price) }
                commerceOrInstallButton
            }
            if row.installed {
                Section(header: Text(L("Installed Package"))) {
                    if row.updateAvailable { Button(L("Update")) { container.preparePackageInstall(row.id) }.disabled(container.isInstallSubmitting) }
                    Button(L("Remove Package"), role: .destructive) { container.preparePackageRemoval(row.id, complete: false) }
                    Button(L("Complete Removal"), role: .destructive) { container.preparePackageRemoval(row.id, complete: true) }
                }
            }
            if let error = container.installActionError ?? container.removalActionError ?? container.commerceActionError {
                Section(header: Text(L("Status"))) { Text(error).font(.caption).foregroundColor(.secondary) }
            }
        }
        .navigationTitle(row.name).navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var commerceOrInstallButton: some View {
        switch row.commerce.state {
        case .paid, .signInRequired:
            Button(row.commerce.state == .signInRequired ? L("Sign In to Source") : L("Purchase")) { container.performCommerceAction(for: row) }
                .disabled(container.isCommerceSubmitting || !container.commerceActionAvailable(for: row))
        case .unavailable:
            Text(L("Unavailable from this source")).foregroundColor(.secondary)
        case .free, .owned:
            if !row.installed { Button(L("Install")) { container.preparePackageInstall(row.id) }.disabled(container.isInstallSubmitting) }
            else { Text(L("Installed")).foregroundColor(.secondary) }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack { Text(L(label)); Spacer(); Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing) }
    }
}
