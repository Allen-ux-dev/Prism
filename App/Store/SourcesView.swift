import SwiftUI
import PrismUIBridge

struct StoreSourcesView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            if container.snapshot.sources.isEmpty { StoreEmptyState(icon: "tray.full", title: "No sources", subtitle: "Add a repository to start browsing packages.") }
            ForEach(container.snapshot.sources) { source in
                NavigationLink { StoreSourceDetailView(source: source) } label: {
                    HStack(spacing: 12) {
                        StoreRemoteIcon(candidates: source.iconURLs, fallback: "tray.full")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.displayName).font(.headline)
                            Text(source.url).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            Text(LF("%d packages", source.packageCount)).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .refreshable { container.refresh() }
        .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button { container.isAddSourcePresented = true } label: { Image(systemName: "plus") } } }
    }
}

struct StoreSourceDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let source: PrismSourceRow
    @State private var query = ""
    @State private var confirmRemoval = false
    private var detail: PrismSourceDetailPresentation { container.sourceDetail(source) }
    private var packages: [PrismPackageRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return detail.packages }
        return detail.packages.filter { $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q) || $0.description.lowercased().contains(q) }
    }
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    StoreRemoteIcon(candidates: source.iconURLs, fallback: "tray.full", size: 58)
                    VStack(alignment: .leading) { Text(detail.displayName).font(.title3.bold()); Text(detail.url).font(.caption).foregroundColor(.secondary) }
                }
                if let summary = detail.summary, !summary.isEmpty { Text(summary).foregroundColor(.secondary) }
            }
            Section(header: Text(L("Source Status"))) {
                row("Provider", detail.providerIdentifier ?? L("Unknown"))
                row("Refresh", detail.refreshState)
                row("Trust", detail.trustLabel)
                row("Compatibility", detail.compatibilityLabel)
                if let date = detail.lastRefresh { HStack { Text(L("Last Refresh")); Spacer(); Text(date, style: .relative).foregroundColor(.secondary) } }
                if let commerce = source.commerceProviderIdentifier { row("Commerce Provider", commerce) }
            }
            Section(header: Text(L("Packages"))) {
                if packages.isEmpty { StoreEmptyState(icon: "shippingbox", title: "No matching packages", subtitle: "Try another search or refresh this source.") }
                ForEach(packages) { pkg in NavigationLink { StorePackageDetailView(row: pkg) } label: { StorePackageRowView(row: pkg) } }
            }
            Section {
                Button(L("Refresh Sources")) { container.refresh() }
                Button(L("Remove Source"), role: .destructive) { confirmRemoval = true }
            }
        }
        .searchable(text: $query, prompt: L("Search this source"))
        .navigationTitle(source.displayName).navigationBarTitleDisplayMode(.inline)
        .alert(L("Remove Source?"), isPresented: $confirmRemoval) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Remove Source"), role: .destructive) { container.removeSource(source) }
        } message: { Text(L("Removing a source does not uninstall packages already installed from it.")) }
    }
    private func row(_ label: String, _ value: String) -> some View { HStack { Text(L(label)); Spacer(); Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing) } }
}

struct StoreAddSourceView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.presentationMode) private var presentation
    var body: some View {
        Form {
            Section(header: Text(L("Repository URL"))) {
                TextField("https://example.com/repo/", text: $container.sourceDraft).keyboardType(.URL).autocapitalization(.none).disableAutocorrection(true)
                if let error = container.sourceDraftError { Text(error).font(.caption).foregroundColor(.red) }
            }
            Section { Button(L("Add Source")) { container.addSource() } }
            Section { Text(L("Prism probes the source and lets the repository resolver select a compatible provider. Adding a source never installs a package by itself.")).font(.caption).foregroundColor(.secondary) }
        }
        .navigationTitle(L("Add Source"))
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { presentation.wrappedValue.dismiss() } } }
    }
}
