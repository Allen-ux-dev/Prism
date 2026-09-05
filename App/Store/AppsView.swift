import SwiftUI
import PrismUIBridge

struct StoreAppsView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            Section(header: Text(L("Runtime Application Service"))) {
                HStack { Text(L("Bridge")); Spacer(); Text(L(container.runtimeBridgeStatus.connectionState.rawValue.capitalized)).foregroundColor(.secondary) }
                HStack { Text(L("Application Provider")); Spacer(); Text(container.runtimeBridgeStatus.applicationProviderIdentifier ?? L("Unavailable")).foregroundColor(.secondary).multilineTextAlignment(.trailing) }
                HStack { Text(L("Injection Provider")); Spacer(); Text(container.runtimeBridgeStatus.injectionProviderIdentifier ?? L("Unavailable")).foregroundColor(.secondary).multilineTextAlignment(.trailing) }
                Button(L("Refresh Apps")) { container.refreshApplications() }
            }
            Section(header: Text(L("Application Installation"))) {
                NavigationLink { StoreIPAImportView() } label: { Label(L("Import IPA"), systemImage: "square.and.arrow.down") }
                    .disabled(container.runtimeBridgeStatus.applicationProviderIdentifier == nil)
                if container.runtimeBridgeStatus.applicationProviderIdentifier == nil {
                    Text(L("The current runtime does not provide an application installation service.")).font(.caption).foregroundColor(.secondary)
                }
            }
            Section(header: Text(L("Installed Applications"))) {
                if container.snapshot.apps.isEmpty { StoreEmptyState(icon: "square.grid.2x2", title: "No managed apps", subtitle: "Connect a runtime application service or refresh the app state.") }
                ForEach(container.snapshot.apps) { app in NavigationLink { StoreAppDetailView(app: app) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name).font(.headline)
                        Text(app.id).font(.caption).foregroundColor(.secondary)
                        HStack { Text(app.version); Text("•"); Text(app.registrationState); if app.injectionCount > 0 { Text("•"); Text(LF("%d injections", app.injectionCount)) } }.font(.caption2).foregroundColor(.secondary)
                    }
                } }
            }
            Section(header: Text(L("Advanced / Lab"))) {
                NavigationLink(L("Simulation Environment")) { AppSimulationInfoView() }
                Text(L("Simulation is isolated test state and is never presented as a real installed app or runtime capability.")).font(.caption).foregroundColor(.secondary)
            }
            if let error = container.applicationActionError { Section(header: Text(L("Status"))) { Text(error).font(.caption).foregroundColor(.secondary) } }
        }
        .refreshable { container.refreshApplications() }
    }
}

struct StoreAppDetailView: View {
    @EnvironmentObject private var container: AppContainer
    let app: PrismAppRow
    @State private var confirmRemoval = false
    var body: some View {
        List {
            Section { Text(app.name).font(.title3.bold()); Text(app.id).font(.caption).foregroundColor(.secondary) }
            Section(header: Text(L("Application Information"))) {
                row("Version", app.version); row("Architecture", app.architecture); row("Registration", app.registrationState); row("Installation Source", app.installationSource)
                if let minimumOS = app.minimumOS { row("Minimum OS", minimumOS) }
            }
            Section(header: Text(L("Actions"))) {
                Button(L("Register Application")) { container.registerApplication(app.id) }.disabled(container.isApplicationSubmitting)
                Button(L("Repair / Refresh")) { container.repairApplication(app.id) }.disabled(container.isApplicationSubmitting)
                Button(L("Remove Application"), role: .destructive) { confirmRemoval = true }.disabled(container.isApplicationSubmitting)
            }
            Section(header: Text(L("Injection"))) {
                Text(app.injectionCount == 0 ? L("No active injection records") : LF("%d active injection records", app.injectionCount))
                if container.runtimeBridgeStatus.injectionProviderIdentifier == nil { Text(L("The current runtime does not provide application injection.")).font(.caption).foregroundColor(.secondary) }
            }
        }
        .navigationTitle(app.name).navigationBarTitleDisplayMode(.inline)
        .alert(L("Remove Application?"), isPresented: $confirmRemoval) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Remove Application"), role: .destructive) { container.removeApplication(app.id) }
        } message: { Text(L("The request is journaled as a typed application transaction and verified against actual runtime state.")) }
    }
    private func row(_ label: String, _ value: String) -> some View { HStack { Text(L(label)); Spacer(); Text(value).foregroundColor(.secondary) } }
}

struct StoreIPAImportView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            Section { Label(L("Runtime-managed IPA import"), systemImage: "checkmark.shield"); Text(L("Prism passes installation through the typed Runtime Application Service. It does not embed a signing bypass or privilege-acquisition path.")).font(.subheadline).foregroundColor(.secondary) }
            Section(header: Text(L("Runtime Provider"))) { Text(container.runtimeBridgeStatus.applicationProviderIdentifier ?? L("Unavailable")) }
            Section(header: Text(L("Artifact Staging"))) {
                Text(L("The RELAXIN-X Runtime Service Host must provide the artifact-staging capability before a selected IPA can be transferred to the privileged runtime boundary.")).font(.subheadline)
                Text(L("Build 52 keeps the store-side import entry and capability gate ready; the runtime host upgrade specification defines the staging service contract.")).font(.caption).foregroundColor(.secondary)
            }
        }.navigationTitle(L("Import IPA")).navigationBarTitleDisplayMode(.inline)
    }
}
