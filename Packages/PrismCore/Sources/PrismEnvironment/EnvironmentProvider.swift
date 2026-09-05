import Foundation

public protocol EnvironmentProvider: Sendable {
    var identifier: String { get }
    func probe(_ probe: EnvironmentProbeSnapshot) -> PrismEnvironment?
}

public struct EnvironmentProbeDiagnostic: Codable, Sendable, Equatable {
    public let providerIdentifier: String
    public let matched: Bool

    public init(providerIdentifier: String, matched: Bool) {
        self.providerIdentifier = providerIdentifier
        self.matched = matched
    }
}

public struct EnvironmentResolution: Codable, Sendable, Equatable {
    public let environment: PrismEnvironment
    public let diagnostics: [EnvironmentProbeDiagnostic]

    public init(environment: PrismEnvironment, diagnostics: [EnvironmentProbeDiagnostic]) {
        self.environment = environment
        self.diagnostics = diagnostics
    }
}

public enum EnvironmentResolutionError: Error, Equatable {
    case noProviderMatched
}
