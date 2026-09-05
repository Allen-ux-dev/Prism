import Testing
@testable import PrismDomain
@testable import PrismUIBridge

@Test func commerceMetadataNormalizesFreePaidAndSignInStates() {
    let free = PrismCommerceMetadataParser.presentation(packageID: "free", repositoryID: "repo", metadata: [:])
    #expect(free.state == .free)

    let paid = PrismCommerceMetadataParser.presentation(packageID: "paid", repositoryID: "repo", metadata: ["Price": "2.99", "Currency": "USD"])
    #expect(paid.state == .paid)
    #expect(paid.priceDisplay == "USD 2.99")

    let signIn = PrismCommerceMetadataParser.presentation(packageID: "login", repositoryID: "repo", metadata: ["Price": "1.00", "Requires-Login": "true"])
    #expect(signIn.state == .signInRequired)
}

@Test func sourceOwnedCommerceProviderRequiresSignInThenGrantsEntitlement() async throws {
    let provider = InMemoryRepositoryCommerceProvider(providerIdentifier: "repo-commerce", requiresSignIn: true)
    let product = PrismCommerceProduct(identifier: "pkg.paid", repositoryID: "repo", price: .init(amount: "2.99", currencyCode: "USD"))

    #expect(await provider.entitlement(for: product).state == .signInRequired)
    try await provider.signIn()
    #expect(await provider.entitlement(for: product).state == .paid)
    let outcome = try await provider.purchase(product)
    #expect(outcome.entitlement.state == .owned)
    #expect(await provider.entitlement(for: product).state == .owned)
}
