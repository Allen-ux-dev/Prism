import Testing
@testable import PrismUIBridge

@Test func repositoryScopeFiltersBySourceURLBeforeSearch() {
    let rows = [
        PrismPackageRow(id: "pkg.alpha", name: "Alpha", version: "1", description: "first", installed: false, updateAvailable: false, repositoryID: "repo-a", sourceURL: "https://a.example/"),
        PrismPackageRow(id: "pkg.beta", name: "Beta", version: "1", description: "second", installed: false, updateAvailable: false, repositoryID: "repo-b", sourceURL: "https://b.example/"),
        PrismPackageRow(id: "pkg.gamma", name: "Gamma Tools", version: "1", description: "alpha helper", installed: false, updateAvailable: false, repositoryID: "repo-a", sourceURL: "https://a.example/")
    ]

    #expect(PrismRepositoryScope.filteredPackages(rows, sourceURL: "https://a.example/", query: "").map(\.id) == ["pkg.alpha", "pkg.gamma"])
    #expect(PrismRepositoryScope.filteredPackages(rows, sourceURL: "https://a.example/", query: "gamma").map(\.id) == ["pkg.gamma"])
    #expect(PrismRepositoryScope.filteredPackages(rows, sourceURL: "https://a.example/", query: "second").isEmpty)
}
