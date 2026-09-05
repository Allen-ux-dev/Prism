import SwiftUI
import PrismUIBridge

struct StoreFeaturedView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prism").font(.largeTitle.bold())
                    Text(L("Packages, apps and transactions in one place.")).foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    StoreMetricCard(value: "\(container.storeOverview.installedCount)", label: "Installed")
                    StoreMetricCard(value: "\(container.storeOverview.updateCount)", label: "Updates")
                    StoreMetricCard(value: "\(container.storeOverview.sourceCount)", label: "Sources")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Runtime")).font(.headline)
                    HStack {
                        StoreStatusPill(text: container.serviceStatusText, systemImage: container.snapshot.serviceStatus == .connected ? "checkmark.circle" : "exclamationmark.circle")
                        if let runtime = container.runtimeBridgeStatus.runtimeDisplayName { Text(runtime).font(.subheadline).foregroundColor(.secondary) }
                        Spacer()
                    }
                }

                if !container.storeOverview.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("Categories")).font(.title3.bold())
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                            ForEach(container.storeOverview.categories) { category in
                                NavigationLink {
                                    StorePackagesView(initialCategory: category)
                                } label: {
                                    Label(category.displayName, systemImage: "square.grid.2x2")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text(L("Recommended")).font(.title3.bold()); Spacer(); NavigationLink(L("See All")) { StorePackagesView() } }
                    if container.storeOverview.recommendedPackages.isEmpty {
                        StoreEmptyState(icon: "shippingbox", title: "No packages", subtitle: "Add or refresh a source to browse packages.")
                    } else {
                        ForEach(container.storeOverview.recommendedPackages.prefix(5)) { row in
                            NavigationLink { StorePackageDetailView(row: row) } label: { StorePackageRowView(row: row) }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                }

                if !container.storeOverview.recentTransactions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Recent Activity")).font(.title3.bold())
                        ForEach(container.storeOverview.recentTransactions) { tx in
                            HStack { Text(tx.title).font(.subheadline).lineLimit(1); Spacer(); Text(L(tx.phase.capitalized)).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                }
            }.padding()
        }
        .refreshable { container.refresh() }
    }
}
