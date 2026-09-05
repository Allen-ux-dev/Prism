import Foundation
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions

public struct MockTrollStoreStyleProvider: PrismProvider, Sendable {
    public let descriptor = PrismProviderDescriptor(
        identifier: "dev.prism.app-install.mock-trollstore-style",
        kind: .appInstallation,
        version: "1.0",
        priority: 5,
        operatingModes: [.modern, .hybrid],
        supportedRequirements: ["appInstall", "appRegistration"],
        recoveryStrategies: [.reconcile, .rollback, .safeAbort],
        health: .healthy,
        diagnosticsMetadata: ["simulation": "true", "behavior": "non-destructive", "faultHarness": "shared-service"]
    )

    public init() {}

    public func plan(ipa: IPAInspectionSnapshot, environment: PrismEnvironment) -> AppInstallPlan {
        AppInstallPlanner().plan(ipa: ipa, environment: environment)
    }

    public func transaction(for plan: AppInstallPlan) -> PrismTransaction {
        guard plan.isExecutable else { return PrismTransaction(operations: [], phase: .needsReview) }
        return PrismTransaction(operations: [
            .installApp(.init(bundleIdentifier: plan.ipa.bundleIdentifier, displayName: plan.ipa.displayName, version: plan.ipa.version)),
            .registerApp(plan.ipa.bundleIdentifier)
        ])
    }
}
