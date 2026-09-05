import Testing
@testable import PrismDomain
@testable import PrismRepositories

@Test func exactIdentifierRanksBeforeDescriptionMatch() {
    let exact = PrismPackage(identifier: "demo", name: "Other", description: "", distribution: .deb)
    let fuzzy = PrismPackage(identifier: "other", name: "Another", description: "mentions demo", distribution: .deb)
    let result = SearchService().search("demo", in: .init(packages: [fuzzy, exact]))
    #expect(result.map(\.identifier) == ["demo", "other"])
}
