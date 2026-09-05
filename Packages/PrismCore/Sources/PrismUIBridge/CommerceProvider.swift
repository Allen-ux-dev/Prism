import Foundation
import PrismDomain

public protocol EntitlementProvider: Sendable {
    func entitlement(for product: PrismCommerceProduct) async -> PrismCommerceEntitlement
}

public protocol PurchaseProvider: Sendable {
    func signIn() async throws
    func purchase(_ product: PrismCommerceProduct) async throws -> PrismPurchaseOutcome
}

public protocol RepositoryCommerceProvider: EntitlementProvider, PurchaseProvider {}

public enum PrismCommerceProviderError: Error, Equatable, Sendable {
    case signInRequired
    case unavailable
}

public struct PrismCommercePresentation: Sendable, Hashable {
    public let state: PrismCommerceAccessState
    public let priceDisplay: String?
    public let providerIdentifier: String?
    public let product: PrismCommerceProduct

    public init(state: PrismCommerceAccessState, priceDisplay: String?, providerIdentifier: String?, product: PrismCommerceProduct) {
        self.state = state
        self.priceDisplay = priceDisplay
        self.providerIdentifier = providerIdentifier
        self.product = product
    }
}

public enum PrismCommerceMetadataParser {
    public static func presentation(packageID: String, repositoryID: String, metadata: [String: String]) -> PrismCommercePresentation {
        let amount = metadata["Price"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currency = metadata["Currency"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let money: PrismMoney? = {
            guard let amount, !amount.isEmpty else { return nil }
            return PrismMoney(amount: amount, currencyCode: (currency?.isEmpty == false ? currency! : "USD"))
        }()
        let product = PrismCommerceProduct(identifier: packageID, repositoryID: repositoryID, price: money)
        let providerID = metadata["Purchase-Provider"] ?? metadata["Commerce-Provider"]

        let owned = bool(metadata["Owned"])
        let unavailable = bool(metadata["Purchase-Unavailable"]) || metadata["Commerce-Available"]?.lowercased() == "false"
        let requiresLogin = bool(metadata["Requires-Login"])
        let explicitlyPaid = bool(metadata["Paid"])
        let state: PrismCommerceAccessState
        if owned { state = .owned }
        else if unavailable { state = .unavailable }
        else if requiresLogin { state = .signInRequired }
        else if explicitlyPaid || money != nil { state = .paid }
        else { state = .free }

        return .init(state: state, priceDisplay: money?.displayText, providerIdentifier: providerID, product: product)
    }

    private static func bool(_ value: String?) -> Bool {
        guard let value else { return false }
        return ["1", "true", "yes", "y"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

public actor InMemoryRepositoryCommerceProvider: RepositoryCommerceProvider {
    private let providerIdentifier: String
    private let requiresSignIn: Bool
    private var signedIn: Bool
    private var owned = Set<String>()

    public init(providerIdentifier: String, requiresSignIn: Bool = false) {
        self.providerIdentifier = providerIdentifier
        self.requiresSignIn = requiresSignIn
        self.signedIn = !requiresSignIn
    }

    public func entitlement(for product: PrismCommerceProduct) async -> PrismCommerceEntitlement {
        let key = Self.key(product)
        let state: PrismCommerceAccessState
        if owned.contains(key) { state = .owned }
        else if requiresSignIn && !signedIn { state = .signInRequired }
        else if product.price != nil { state = .paid }
        else { state = .free }
        return .init(productIdentifier: product.identifier, repositoryID: product.repositoryID, state: state)
    }

    public func signIn() async throws { signedIn = true }

    public func purchase(_ product: PrismCommerceProduct) async throws -> PrismPurchaseOutcome {
        if requiresSignIn && !signedIn { throw PrismCommerceProviderError.signInRequired }
        guard product.price != nil else {
            let entitlement = PrismCommerceEntitlement(productIdentifier: product.identifier, repositoryID: product.repositoryID, state: .free)
            return .init(entitlement: entitlement)
        }
        owned.insert(Self.key(product))
        return .init(entitlement: .init(productIdentifier: product.identifier, repositoryID: product.repositoryID, state: .owned))
    }

    private static func key(_ product: PrismCommerceProduct) -> String { "\(product.repositoryID)|\(product.identifier)" }
}
