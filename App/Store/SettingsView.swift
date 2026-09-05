import SwiftUI
import PrismUIBridge

struct StoreSettingsView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.presentationMode) private var presentation
    var body: some View {
        Form {
            Section(header: Text(L("Language"))) {
                Picker(L("Language"), selection: $container.language) { ForEach(PrismLanguage.allCases) { language in Text(L(language.localizationKey)).tag(language) } }
            }
            Section(header: Text(L("Runtime"))) {
                ForEach(Array(container.snapshot.environment.dailyRows.enumerated()), id: \.offset) { _, row in VStack(alignment: .leading, spacing: 3) { Text(L(row.title)).font(.caption).foregroundColor(.secondary); Text(L(row.value)); if let detail = row.detail { Text(detail).font(.caption2).foregroundColor(.secondary) } } }
                Button(L("Reconnect Package Service")) { container.reconnect() }
                Button(L("Reconnect Runtime Bridge")) { container.reconnectRuntimeBridge() }
            }
            Section(header: Text(L("Runtime Background Service"))) {
                Toggle(L("Enable Runtime Background Service"), isOn: Binding(get: { container.runtimeBackgroundRequested }, set: { container.setRuntimeBackgroundEnabled($0) })).disabled(!container.runtimeBridgeStatus.backgroundSupported)
                Text(L("This switch only controls a background session already authorized by the current runtime. Prism does not create jailbreak or system privileges.")).font(.caption).foregroundColor(.secondary)
            }
            Section(header: Text(L("Store"))) {
                Button(L("Reset Package Filters")) { container.resetPackageFilters() }
                Text(LF("%d sources · %d installed · %d updates", container.storeOverview.sourceCount, container.storeOverview.installedCount, container.storeOverview.updateCount)).font(.caption).foregroundColor(.secondary)
            }
            Section(header: Text(L("Diagnostics"))) {
                NavigationLink(L("Global Log")) { GlobalLogView() }
            }
        }
        .navigationTitle(L("Settings"))
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { presentation.wrappedValue.dismiss() } } }
    }
}
