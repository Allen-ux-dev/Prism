import Foundation
import Testing
@testable import PrismDomain
@testable import PrismUIBridge

private func storeRow(
    id: String,
    name: String,
    source: String,
    category: String,
    installed: Bool = false,
    update: Bool = false,
    commerceState: PrismCommerceAccessState = .free,
    updatedAt: Date? = nil
) -> PrismPackageRow {
    PrismPackageRow(
        id: id,
        name: name,
        version: "1.0",
        description: "\(name) package",
        installed: installed,
        updateAvailable: update,
        repositoryID: source,
        sourceURL: "https://\(source).example/",
        commerce: .init(
            state: commerceState,
            priceDisplay: commerceState == .paid ? "USD 1.99" : nil,
            providerIdentifier: commerceState == .free ? nil : "commerce.\(source)",
            product: .init(identifier: id, repositoryID: source)
        ),
        author: "Author \(source)",
        architecture: "iphoneos-arm64",
        category: category,
        trustLabel: "Trusted",
        distributionLabel: "deb",
        dependencySummary: ["firmware >= 15.0"],
        conflictSummary: [],
        requirementSummary: ["packageInstall"],
        updatedAt: updatedAt
    )
}

@Test func storeQueryCombinesSearchCategorySourceInstallAndCommerceFilters() {
    let rows = [
        storeRow(id: "pkg.alpha", name: "Alpha", source: "repo-a", category: "Tweaks", installed: true, commerceState: .owned),
        storeRow(id: "pkg.beta", name: "Beta", source: "repo-a", category: "Themes", installed: false, commerceState: .paid),
        storeRow(id: "pkg.gamma", name: "Gamma Alpha", source: "repo-b", category: "Tweaks", installed: true, update: true, commerceState: .owned)
    ]

    let query = PrismStoreQuery(
        searchText: "alpha",
        category: .named("Tweaks"),
        sourceID: "repo-b",
        installationFilter: .updates,
        commerceFilter: .owned,
        sort: .name
    )

    #expect(PrismStorePresentationBuilder.filteredPackages(rows, query: query).map(\.id) == ["pkg.gamma"])
}

@Test func storeSortNewestUsesNormalizedUpdatedMetadataDeterministically() {
    let early = Date(timeIntervalSince1970: 100)
    let late = Date(timeIntervalSince1970: 200)
    let rows = [
        storeRow(id: "pkg.a", name: "A", source: "repo", category: "Tools", updatedAt: early),
        storeRow(id: "pkg.b", name: "B", source: "repo", category: "Tools", updatedAt: late),
        storeRow(id: "pkg.c", name: "C", source: "repo", category: "Tools", updatedAt: nil)
    ]

    let query = PrismStoreQuery(sort: .newest)
    #expect(PrismStorePresentationBuilder.filteredPackages(rows, query: query).map(\.id) == ["pkg.b", "pkg.a", "pkg.c"])
}

@Test func storeOverviewDerivesUpdatesInstalledCategoriesAndRecommendations() {
    let rows = [
        storeRow(id: "pkg.alpha", name: "Alpha", source: "repo-a", category: "Tweaks", installed: true),
        storeRow(id: "pkg.beta", name: "Beta", source: "repo-a", category: "Themes", update: true),
        storeRow(id: "pkg.gamma", name: "Gamma", source: "repo-b", category: "Tweaks")
    ]
    let sources = [
        PrismSourceRow(id: "repo-a", url: "https://repo-a.example/", packageCount: 2),
        PrismSourceRow(id: "repo-b", url: "https://repo-b.example/", packageCount: 1)
    ]

    let overview = PrismStorePresentationBuilder.overview(packages: rows, sources: sources, transactions: [])
    #expect(overview.installedCount == 1)
    #expect(overview.updateCount == 1)
    #expect(overview.sourceCount == 2)
    #expect(overview.categories.map(\.displayName) == ["Themes", "Tweaks"])
    #expect(Set(overview.recommendedPackages.map(\.id)) == Set(["pkg.alpha", "pkg.beta", "pkg.gamma"]))
}

@Test func storePackageDetailCarriesNormalizedTechnicalAndCommerceMetadata() {
    let row = storeRow(id: "pkg.alpha", name: "Alpha", source: "repo-a", category: "Tweaks", installed: true, commerceState: .owned)
    let detail = PrismStorePresentationBuilder.packageDetail(row)

    #expect(detail.identifier == "pkg.alpha")
    #expect(detail.author == "Author repo-a")
    #expect(detail.architecture == "iphoneos-arm64")
    #expect(detail.category == "Tweaks")
    #expect(detail.trustLabel == "Trusted")
    #expect(detail.dependencies == ["firmware >= 15.0"])
    #expect(detail.requirements == ["packageInstall"])
    #expect(detail.commerceState == .owned)
}

@Test func storeSourceDetailScopesPackagesAndPreservesProviderNeutralStatus() {
    let source = PrismSourceRow(
        id: "repo-a",
        url: "https://repo-a.example/",
        packageCount: 2,
        displayName: "Repo A",
        providerIdentifier: "provider.modern",
        refreshState: "Ready",
        trustLabel: "Trusted",
        compatibilityLabel: "Native",
        lastRefresh: Date(timeIntervalSince1970: 123)
    )
    let packages = [
        storeRow(id: "pkg.alpha", name: "Alpha", source: "repo-a", category: "Tweaks"),
        storeRow(id: "pkg.beta", name: "Beta", source: "repo-b", category: "Themes")
    ]

    let detail = PrismStorePresentationBuilder.sourceDetail(source, packages: packages)
    #expect(detail.providerIdentifier == "provider.modern")
    #expect(detail.trustLabel == "Trusted")
    #expect(detail.compatibilityLabel == "Native")
    #expect(detail.packages.map(\.id) == ["pkg.alpha"])
}

@Test func activityBucketsNormalizeTransactionPhasesForRecoveryUI() {
    let rows = [
        PrismTransactionRow(id: UUID(), title: "queued", phase: "created", progress: 0),
        PrismTransactionRow(id: UUID(), title: "running", phase: "executing", progress: 0.5),
        PrismTransactionRow(id: UUID(), title: "done", phase: "completed", progress: 1),
        PrismTransactionRow(id: UUID(), title: "bad", phase: "failed", progress: 0.5),
        PrismTransactionRow(id: UUID(), title: "review", phase: "needsReview", progress: 0.7)
    ]

    let grouped = PrismStorePresentationBuilder.activityBuckets(rows)
    #expect(grouped[.pending]?.map(\.title) == ["queued"])
    #expect(grouped[.running]?.map(\.title) == ["running"])
    #expect(grouped[.completed]?.map(\.title) == ["done"])
    #expect(grouped[.failed]?.map(\.title) == ["bad"])
    #expect(grouped[.recovery]?.map(\.title) == ["review"])
}

@Test func catalogRowMapperCarriesNormalizedPackageAndSourceMetadata() {
    let package = PrismPackage(
        identifier: "pkg.map",
        name: "Mapped",
        version: PackageVersion.native("2.0"),
        architecture: "iphoneos-arm64",
        author: "Mapper",
        description: "Mapped package",
        repositoryID: "repo-map",
        dependencies: [.init(packageIdentifier: "dep.one", relation: .greaterThanOrEqual, requiredVersion: PackageVersion.native("1.0"))],
        conflicts: [.init(packageIdentifier: "conflict.one")],
        requirements: [.init(identifier: "packageInstall")],
        distribution: .debianDeb,
        metadata: ["Section": "Utilities", "TrustStatus": "verified", "Updated": "2026-09-04T12:00:00Z"]
    )
    let visual = RepositorySourceVisual(
        displayName: "Mapped Repo",
        iconURLs: [],
        commerceProviderIdentifier: "commerce.map",
        providerIdentifier: "provider.map",
        refreshState: "Ready",
        trustLabel: "Trusted",
        compatibilityLabel: "Native",
        lastRefresh: Date(timeIntervalSince1970: 100),
        summary: "Repository summary"
    )

    let packageRow = PrismStoreRowMapper.packageRow(
        package: package,
        installedVersion: PackageVersion.native("1.0"),
        sourceURL: "https://repo-map.example/",
        sourceVisual: visual,
        iconURL: nil
    )
    #expect(packageRow.category == "Utilities")
    #expect(packageRow.author == "Mapper")
    #expect(packageRow.architecture == "iphoneos-arm64")
    #expect(packageRow.trustLabel == "Verified")
    #expect(packageRow.distributionLabel == "org.debian.deb")
    #expect(packageRow.dependencySummary == ["dep.one >= 1.0"])
    #expect(packageRow.conflictSummary == ["conflict.one"])
    #expect(packageRow.requirementSummary == ["packageInstall"])
    #expect(packageRow.updateAvailable)
    #expect(packageRow.updatedAt != nil)

    let sourceRow = PrismStoreRowMapper.sourceRow(
        existing: PrismSourceRow(id: "repo-map", url: "https://repo-map.example/", packageCount: 0),
        visual: visual,
        packageCount: 42
    )
    #expect(sourceRow.providerIdentifier == "provider.map")
    #expect(sourceRow.refreshState == "Ready")
    #expect(sourceRow.trustLabel == "Trusted")
    #expect(sourceRow.compatibilityLabel == "Native")
    #expect(sourceRow.summary == "Repository summary")
    #expect(sourceRow.packageCount == 42)
}
