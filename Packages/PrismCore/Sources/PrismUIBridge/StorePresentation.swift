import Foundation
import PrismDomain

public enum PrismStoreCategory: Sendable, Hashable, Identifiable {
    case all
    case named(String)

    public var id: String { displayName }
    public var displayName: String {
        switch self {
        case .all: return "All"
        case .named(let value): return value
        }
    }
}

public enum PrismPackageInstallationFilter: String, Sendable, Hashable, CaseIterable, Identifiable {
    case all, installed, available, updates
    public var id: String { rawValue }
}

public enum PrismPackageCommerceFilter: String, Sendable, Hashable, CaseIterable, Identifiable {
    case all, free, paid, owned
    public var id: String { rawValue }
}

public enum PrismPackageSort: String, Sendable, Hashable, CaseIterable, Identifiable {
    case name, newest, installed, updates
    public var id: String { rawValue }
}

public struct PrismStoreQuery: Sendable, Hashable {
    public var searchText: String
    public var category: PrismStoreCategory
    public var sourceID: String?
    public var installationFilter: PrismPackageInstallationFilter
    public var commerceFilter: PrismPackageCommerceFilter
    public var sort: PrismPackageSort

    public init(
        searchText: String = "",
        category: PrismStoreCategory = .all,
        sourceID: String? = nil,
        installationFilter: PrismPackageInstallationFilter = .all,
        commerceFilter: PrismPackageCommerceFilter = .all,
        sort: PrismPackageSort = .name
    ) {
        self.searchText = searchText
        self.category = category
        self.sourceID = sourceID
        self.installationFilter = installationFilter
        self.commerceFilter = commerceFilter
        self.sort = sort
    }
}

public struct PrismPackageDetailPresentation: Sendable, Hashable {
    public let identifier: String
    public let name: String
    public let version: String
    public let description: String
    public let author: String?
    public let architecture: String?
    public let category: String
    public let trustLabel: String
    public let distributionLabel: String
    public let repositoryID: String?
    public let sourceURL: String?
    public let dependencies: [String]
    public let conflicts: [String]
    public let requirements: [String]
    public let commerceState: PrismCommerceAccessState
    public let priceDisplay: String?
    public let installed: Bool
    public let updateAvailable: Bool
}

public struct PrismSourceDetailPresentation: Sendable, Hashable {
    public let id: String
    public let displayName: String
    public let url: String
    public let providerIdentifier: String?
    public let refreshState: String
    public let trustLabel: String
    public let compatibilityLabel: String
    public let lastRefresh: Date?
    public let summary: String?
    public let packages: [PrismPackageRow]
}

public struct PrismStoreOverview: Sendable, Hashable {
    public let installedCount: Int
    public let updateCount: Int
    public let sourceCount: Int
    public let categories: [PrismStoreCategory]
    public let recommendedPackages: [PrismPackageRow]
    public let recentTransactions: [PrismTransactionRow]
}

public enum PrismActivityBucket: String, Sendable, Hashable, CaseIterable, Identifiable {
    case pending, running, completed, failed, recovery
    public var id: String { rawValue }
}

public enum PrismStorePresentationBuilder {
    public static func filteredPackages(_ rows: [PrismPackageRow], query: PrismStoreQuery) -> [PrismPackageRow] {
        let search = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = rows.filter { row in
            if !search.isEmpty {
                let haystack = [row.name, row.id, row.description, row.author ?? "", row.category].joined(separator: " ").lowercased()
                guard haystack.contains(search) else { return false }
            }
            if case .named(let category) = query.category, row.category.caseInsensitiveCompare(category) != .orderedSame { return false }
            if let sourceID = query.sourceID, row.repositoryID != sourceID && row.sourceURL != sourceID { return false }
            switch query.installationFilter {
            case .all: break
            case .installed: guard row.installed else { return false }
            case .available: guard !row.installed else { return false }
            case .updates: guard row.updateAvailable else { return false }
            }
            switch query.commerceFilter {
            case .all: break
            case .free: guard row.commerce.state == .free else { return false }
            case .paid: guard row.commerce.state == .paid || row.commerce.state == .signInRequired else { return false }
            case .owned: guard row.commerce.state == .owned else { return false }
            }
            return true
        }
        switch query.sort {
        case .name:
            result.sort { lhs, rhs in
                let cmp = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                return cmp == .orderedSame ? lhs.id < rhs.id : cmp == .orderedAscending
            }
        case .newest:
            result.sort { lhs, rhs in
                switch (lhs.updatedAt, rhs.updatedAt) {
                case let (l?, r?): return l == r ? lhs.id < rhs.id : l > r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.id < rhs.id
                }
            }
        case .installed:
            result.sort { lhs, rhs in lhs.installed != rhs.installed ? lhs.installed && !rhs.installed : lhs.name < rhs.name }
        case .updates:
            result.sort { lhs, rhs in lhs.updateAvailable != rhs.updateAvailable ? lhs.updateAvailable && !rhs.updateAvailable : lhs.name < rhs.name }
        }
        return result
    }

    public static func overview(packages: [PrismPackageRow], sources: [PrismSourceRow], transactions: [PrismTransactionRow]) -> PrismStoreOverview {
        let categories = Set(packages.map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map(PrismStoreCategory.named)
        let recommended = packages.sorted { lhs, rhs in
            if lhs.updateAvailable != rhs.updateAvailable { return lhs.updateAvailable && !rhs.updateAvailable }
            if lhs.installed != rhs.installed { return lhs.installed && !rhs.installed }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return PrismStoreOverview(
            installedCount: packages.filter(\.installed).count,
            updateCount: packages.filter(\.updateAvailable).count,
            sourceCount: sources.count,
            categories: categories,
            recommendedPackages: Array(recommended.prefix(8)),
            recentTransactions: Array(transactions.suffix(5).reversed())
        )
    }

    public static func packageDetail(_ row: PrismPackageRow) -> PrismPackageDetailPresentation {
        .init(
            identifier: row.id,
            name: row.name,
            version: row.version,
            description: row.description,
            author: row.author,
            architecture: row.architecture,
            category: row.category,
            trustLabel: row.trustLabel,
            distributionLabel: row.distributionLabel,
            repositoryID: row.repositoryID,
            sourceURL: row.sourceURL,
            dependencies: row.dependencySummary,
            conflicts: row.conflictSummary,
            requirements: row.requirementSummary,
            commerceState: row.commerce.state,
            priceDisplay: row.commerce.priceDisplay,
            installed: row.installed,
            updateAvailable: row.updateAvailable
        )
    }

    public static func sourceDetail(_ row: PrismSourceRow, packages: [PrismPackageRow]) -> PrismSourceDetailPresentation {
        .init(
            id: row.id,
            displayName: row.displayName,
            url: row.url,
            providerIdentifier: row.providerIdentifier,
            refreshState: row.refreshState,
            trustLabel: row.trustLabel,
            compatibilityLabel: row.compatibilityLabel,
            lastRefresh: row.lastRefresh,
            summary: row.summary,
            packages: packages.filter { $0.repositoryID == row.id || $0.sourceURL == row.url }
        )
    }

    public static func activityBuckets(_ rows: [PrismTransactionRow]) -> [PrismActivityBucket: [PrismTransactionRow]] {
        Dictionary(grouping: rows, by: { row in
            switch row.phase.lowercased() {
            case "created", "preparing", "resolving", "ready": return .pending
            case "executing", "reconciling", "rollingback": return .running
            case "completed", "rolledback", "cancelled": return .completed
            case "failed": return .failed
            case "interrupted", "needsrecovery", "needsreview": return .recovery
            default: return .pending
            }
        })
    }
}

public enum PrismStoreRowMapper {
    public static func packageRow(
        package: PrismPackage,
        installedVersion: PackageVersion?,
        sourceURL: String?,
        sourceVisual: RepositorySourceVisual?,
        iconURL: String?
    ) -> PrismPackageRow {
        var commerceMetadata = package.metadata
        if commerceMetadata["Purchase-Provider"] == nil,
           commerceMetadata["Commerce-Provider"] == nil,
           let providerID = sourceVisual?.commerceProviderIdentifier {
            commerceMetadata["Purchase-Provider"] = providerID
        }
        return PrismPackageRow(
            id: package.identifier,
            name: package.name,
            version: package.version.rawValue,
            description: package.description,
            installed: installedVersion != nil,
            updateAvailable: installedVersion.map { $0 < package.version } ?? false,
            iconURL: iconURL,
            repositoryID: package.repositoryID,
            sourceURL: sourceURL,
            commerce: PrismCommerceMetadataParser.presentation(
                packageID: package.identifier,
                repositoryID: package.repositoryID ?? sourceURL ?? "unknown",
                metadata: commerceMetadata
            ),
            author: package.author,
            architecture: package.architecture,
            category: normalizedCategory(package.metadata),
            trustLabel: package.trustStatus.rawValue.capitalized,
            distributionLabel: package.distribution.rawValue,
            dependencySummary: package.dependencies.map(dependencyLabel),
            conflictSummary: package.conflicts.map(dependencyLabel),
            requirementSummary: package.requirements.map(\.identifier),
            updatedAt: parseDate(package.metadata)
        )
    }

    public static func sourceRow(existing: PrismSourceRow, visual: RepositorySourceVisual?, packageCount: Int) -> PrismSourceRow {
        PrismSourceRow(
            id: existing.id,
            url: existing.url,
            packageCount: packageCount,
            displayName: visual?.displayName ?? existing.displayName,
            iconURLs: visual?.iconURLs ?? existing.iconURLs,
            commerceProviderIdentifier: visual?.commerceProviderIdentifier ?? existing.commerceProviderIdentifier,
            providerIdentifier: visual?.providerIdentifier ?? existing.providerIdentifier,
            refreshState: visual?.refreshState ?? existing.refreshState,
            trustLabel: visual?.trustLabel ?? existing.trustLabel,
            compatibilityLabel: visual?.compatibilityLabel ?? existing.compatibilityLabel,
            lastRefresh: visual?.lastRefresh ?? existing.lastRefresh,
            summary: visual?.summary ?? existing.summary
        )
    }

    private static func normalizedCategory(_ metadata: [String: String]) -> String {
        for key in ["Category", "Section"] {
            if let value = metadata[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return "Other"
    }

    private static func dependencyLabel(_ dependency: PackageDependency) -> String {
        guard let relation = dependency.relation, let version = dependency.requiredVersion else {
            return dependency.packageIdentifier
        }
        let symbol: String
        switch relation {
        case .equal: symbol = "="
        case .greaterThan: symbol = ">"
        case .greaterThanOrEqual: symbol = ">="
        case .lessThan: symbol = "<"
        case .lessThanOrEqual: symbol = "<="
        }
        return "\(dependency.packageIdentifier) \(symbol) \(version.rawValue)"
    }

    private static func parseDate(_ metadata: [String: String]) -> Date? {
        let value = metadata["Updated"] ?? metadata["Last-Modified"] ?? metadata["Date"]
        guard let value else { return nil }
        if let timestamp = TimeInterval(value) { return Date(timeIntervalSince1970: timestamp) }
        let iso = ISO8601DateFormatter()
        return iso.date(from: value)
    }
}
