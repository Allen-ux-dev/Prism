public struct EnvironmentResolver: Sendable {
    private let providers: [any EnvironmentProvider]

    public init(providers: [any EnvironmentProvider]) {
        self.providers = providers
    }

    public func resolve(_ probe: EnvironmentProbeSnapshot) throws -> EnvironmentResolution {
        var diagnostics: [EnvironmentProbeDiagnostic] = []

        for provider in providers {
            if let environment = provider.probe(probe) {
                diagnostics.append(.init(providerIdentifier: provider.identifier, matched: true))
                return EnvironmentResolution(environment: environment, diagnostics: diagnostics)
            }
            diagnostics.append(.init(providerIdentifier: provider.identifier, matched: false))
        }

        throw EnvironmentResolutionError.noProviderMatched
    }
}
