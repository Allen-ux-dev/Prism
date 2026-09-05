import SwiftUI
import PrismUIBridge

struct StoreActivityView: View {
    @EnvironmentObject private var container: AppContainer
    var body: some View {
        List {
            bucket(.pending, title: "Pending")
            bucket(.running, title: "Running")
            bucket(.recovery, title: "Needs Review / Recovery")
            bucket(.failed, title: "Failed")
            bucket(.completed, title: "Completed")
            Section(header: Text(L("Global Log"))) {
                NavigationLink(L("View Global Log")) { GlobalLogView() }
                if container.logEntries.isEmpty { Text(L("No log entries yet.")).font(.caption).foregroundColor(.secondary) }
                else { ForEach(Array(container.logEntries.suffix(5).reversed())) { entry in StoreCompactLogRow(entry: entry) } }
            }
        }
    }
    @ViewBuilder private func bucket(_ bucket: PrismActivityBucket, title: String) -> some View {
        let rows = container.activityBuckets[bucket] ?? []
        Section(header: Text(L(title))) {
            if rows.isEmpty { Text(L("No items")).font(.caption).foregroundColor(.secondary) }
            ForEach(rows) { tx in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(tx.title).font(.headline).lineLimit(1); Spacer(); Text(L(tx.phase.capitalized)).font(.caption).foregroundColor(.secondary) }
                    ProgressView(value: tx.progress)
                    if bucket == .recovery { Text(L("This transaction needs reconciliation, rollback, safe abort, or review before another provider can take ownership.")).font(.caption2).foregroundColor(.secondary) }
                }.padding(.vertical, 3)
            }
        }
    }
}

struct StoreCompactLogRow: View {
    let entry: PrismLogEntry
    var body: some View { VStack(alignment: .leading, spacing: 3) { HStack { Text(L(entry.category.rawValue.capitalized)).font(.caption.bold()); Spacer(); Text(entry.timestamp, style: .time).font(.caption2).foregroundColor(.secondary) }; Text(entry.message).font(.caption).lineLimit(2) }.padding(.vertical, 2) }
}
