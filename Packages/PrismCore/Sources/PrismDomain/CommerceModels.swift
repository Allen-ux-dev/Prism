import Foundation

public enum PrismCommerceAccessState: String, Codable, Sendable, Hashable {
    case free
    case paid
    case owned
    case signInRequired
    case unavailable
}

public struct PrismMoney: Codable, Sendable, Hashable {
    public let amount: String
    public let currencyCode: String

    public init(amount: String, currencyCode: String) {
        self.amount = amount
        self.currencyCode = currencyCode
    }

    public var displayText: String { "\(currencyCode) \(amount)" }
}

public struct PrismCommerceProduct: Codable, Sendable, Hashable {
    public let identifier: String
    public let repositoryID: String
    public let price: PrismMoney?

    public init(identifier: String, repositoryID: String, price: PrismMoney? = nil) {
        self.identifier = identifier
        self.repositoryID = repositoryID
        self.price = price
    }
}

public struct PrismCommerceEntitlement: Codable, Sendable, Hashable {
    public let productIdentifier: String
    public let repositoryID: String
    public let state: PrismCommerceAccessState

    public init(productIdentifier: String, repositoryID: String, state: PrismCommerceAccessState) {
        self.productIdentifier = productIdentifier
        self.repositoryID = repositoryID
        self.state = state
    }
}

public struct PrismPurchaseOutcome: Codable, Sendable, Hashable {
    public let entitlement: PrismCommerceEntitlement

    public init(entitlement: PrismCommerceEntitlement) {
        self.entitlement = entitlement
    }
}
