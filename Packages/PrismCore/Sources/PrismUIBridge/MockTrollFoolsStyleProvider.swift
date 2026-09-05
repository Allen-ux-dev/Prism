import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions

public struct MockTrollFoolsStyleProvider: PrismProvider, Sendable {
    public let descriptor = PrismProviderDescriptor(
        identifier: "dev.prism.app-injection.mock-trollfools-style",
        kind: .appInjection,
        version: "1.0",
        priority: 5,
        operatingModes: [.modern, .hybrid],
        supportedRequirements: ["appInjection"],
        recoveryStrategies: [.reconcile, .rollback, .safeAbort],
        health: .healthy,
        diagnosticsMetadata: ["simulation": "true", "behavior": "non-destructive", "faultHarness": "shared-service"]
    )

    public init() {}

    public func plan(target: PrismInstalledApp, artifact: InjectionArtifact, environment: PrismEnvironment) -> InjectionPlan {
        InjectionPlanner().plan(target: target, artifact: artifact, environment: environment)
    }

    public func applyTransaction(for plan: InjectionPlan) -> PrismTransaction {
        guard plan.isExecutable else { return PrismTransaction(operations: [], phase: .needsReview) }
        return PrismTransaction(operations: [
            .applyInjection(.init(targetBundleIdentifier: plan.target.bundleIdentifier, artifact: plan.artifact))
        ])
    }

    public func removeTransaction(target: PrismInstalledApp, artifact: InjectionArtifact) -> PrismTransaction {
        PrismTransaction(operations: [
            .removeInjection(targetBundleIdentifier: target.bundleIdentifier, artifactIdentifier: artifact.identifier)
        ])
    }
}
