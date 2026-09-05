import Foundation
import Testing
@testable import PrismDaemonCore
import PrismDomain
import PrismEnvironment
import PrismResolution
import PrismTransactions

private actor RecordingApplicationProvider: ApplicationExecutionProvider {
    let identifier = "test-app-provider"
    let capabilities: Set<EnvironmentCapability> = [.ipaInstall, .appRegistration]
    private var apps: [String: PrismInstalledApp] = [:]
    private var registered: Set<String> = []
    private var installCalls = 0
    private var registerCalls = 0

    func inspectInstalledApps() async throws -> [String: PrismInstalledApp] { apps }
    func inspectRegisteredBundleIdentifiers() async throws -> Set<String> { registered }
    func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        installCalls += 1
        apps[operation.bundleIdentifier] = PrismInstalledApp(
            bundleIdentifier: operation.bundleIdentifier,
            displayName: operation.displayName,
            version: "1.0",
            architecture: "arm64",
            installationSource: .prism,
            registrationState: .unregistered
        )
        return .init(operationID: "app-install:\(operation.bundleIdentifier)")
    }
    func register(bundleIdentifier: String) async throws -> BackendOperationResult {
        registerCalls += 1
        registered.insert(bundleIdentifier)
        return .init(operationID: "app-register:\(bundleIdentifier)")
    }
    func counts() -> (Int, Int) { (installCalls, registerCalls) }
}

private actor RecordingInjectionProvider: InjectionExecutionProvider {
    let identifier = "test-injection-provider"
    let capabilities: Set<EnvironmentCapability> = [.appInjection, .dylibInjection]
    private var active: Set<InjectionStateKey> = []
    private var applyCalls = 0

    func inspectActiveInjections() async throws -> Set<InjectionStateKey> { active }
    func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult {
        applyCalls += 1
        active.insert(.init(bundleIdentifier: operation.targetBundleIdentifier, artifactIdentifier: operation.artifact.identifier))
        return .init(operationID: operation.stableIDForTest)
    }
    func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult {
        active.remove(.init(bundleIdentifier: targetBundleIdentifier, artifactIdentifier: artifactIdentifier))
        return .init(operationID: "inject-remove:\(targetBundleIdentifier):\(artifactIdentifier)")
    }
    func count() -> Int { applyCalls }
}

private extension InjectionOperation {
    var stableIDForTest: String { "inject:\(targetBundleIdentifier):\(artifact.identifier)" }
}

@Test func composableBackendRoutesApplicationAndInjectionOperations() async throws {
    let packageBackend = MockPackageExecutionBackend()
    let appProvider = RecordingApplicationProvider()
    let injectionProvider = RecordingInjectionProvider()
    let backend = ComposableExecutionBackend(
        packageBackend: packageBackend,
        applicationProvider: appProvider,
        injectionProvider: injectionProvider
    )

    let install = TransactionOperation.installApp(.init(bundleIdentifier: "dev.prism.demo", displayName: "Demo"))
    let register = TransactionOperation.registerApp("dev.prism.demo")
    let artifact = InjectionArtifact(identifier: "demo.tweak", displayName: "Demo Tweak", kind: .dylib, supportedArchitectures: ["arm64"])
    let inject = TransactionOperation.applyInjection(.init(targetBundleIdentifier: "dev.prism.demo", artifact: artifact))

    _ = try await backend.execute(install)
    _ = try await backend.execute(register)
    _ = try await backend.execute(inject)

    let state = try await backend.inspectApplicationState()
    #expect(state.installedApps["dev.prism.demo"] != nil)
    #expect(state.registeredBundleIdentifiers.contains("dev.prism.demo"))
    #expect(state.activeInjections.contains(.init(bundleIdentifier: "dev.prism.demo", artifactIdentifier: "demo.tweak")))
    let counts = await appProvider.counts()
    #expect(counts.0 == 1)
    #expect(counts.1 == 1)
    #expect(await injectionProvider.count() == 1)
}

@Test func providerCapabilitiesAreReportedWithoutGuessingToolNames() async {
    let appProvider = RecordingApplicationProvider()
    let injectionProvider = RecordingInjectionProvider()
    let set = ExecutionProviderCapabilities(applicationProvider: appProvider, injectionProvider: injectionProvider)
    #expect(set.capabilities == [.ipaInstall, .appRegistration, .appInjection, .dylibInjection])
}

@Test func unavailableProvidersRejectTypedOperations() async {
    let backend = ComposableExecutionBackend(
        packageBackend: MockPackageExecutionBackend(),
        applicationProvider: UnavailableApplicationExecutionProvider(),
        injectionProvider: UnavailableInjectionExecutionProvider()
    )
    do {
        _ = try await backend.execute(.installApp(.init(bundleIdentifier: "dev.prism.demo", displayName: "Demo")))
        Issue.record("Expected provider unavailable error")
    } catch let error as ExecutionProviderError {
        #expect(error == .providerUnavailable("application"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
