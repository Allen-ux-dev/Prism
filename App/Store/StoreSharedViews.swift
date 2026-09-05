import SwiftUI
import UIKit
import PrismUIBridge

@MainActor
final class StoreRemoteImageLoader: ObservableObject {
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
                if let cached = Self.cache.object(forKey: url as NSURL) { image = cached; return }
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
                } catch { continue }
            }
        }
    }
}

struct StoreRemoteIcon: View {
    let candidates: [String]
    let fallback: String
    var size: CGFloat = 46
    @StateObject private var loader = StoreRemoteImageLoader()
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22).fill(Color.secondary.opacity(0.12))
            if let image = loader.image {
                Image(uiImage: image).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else { Image(systemName: fallback).foregroundColor(.secondary) }
        }
        .frame(width: size, height: size).clipped()
        .onAppear { loader.load(candidates) }
        .onChange(of: candidates) { loader.load($0) }
    }
}

struct StoreEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(L(title)).font(.headline)
                Text(L(subtitle)).font(.caption).foregroundColor(.secondary)
            }
        }.padding(.vertical, 8)
    }
}

struct StoreMetricCard: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold())
            Text(L(label)).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StoreStatusPill: View {
    let text: String
    let systemImage: String
    var body: some View {
        Label(L(text), systemImage: systemImage)
            .font(.caption.bold())
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }
}

struct StorePackageRowView: View {
    let row: PrismPackageRow
    var body: some View {
        HStack(spacing: 12) {
            StoreRemoteIcon(candidates: row.iconURL.map { [$0] } ?? [], fallback: "shippingbox")
            VStack(alignment: .leading, spacing: 3) {
                Text(row.name).font(.headline).lineLimit(1)
                Text(row.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(row.version)
                    Text("•")
                    Text(row.category)
                    if row.updateAvailable { Text("•"); Text(L("Update")) }
                }.font(.caption2).foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            if let price = row.commerce.priceDisplay, row.commerce.state != .owned { Text(price).font(.caption.bold()) }
            else if row.commerce.state == .owned { Image(systemName: "checkmark.seal.fill").foregroundColor(.green) }
        }.padding(.vertical, 3)
    }
}
