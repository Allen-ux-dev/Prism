import Foundation
import Testing
@testable import PrismDomain
@testable import PrismEnvironment
@testable import PrismTransactions
@testable import PrismDaemonCore

private actor RecordingCompatibilityApplicationService: RuntimeApplicationService {
    nonisolated let descriptor = RuntimeApplicationServiceDescriptor(
        identifier: "compat.install.service",
        displayName: "Compatibility Install Service",
        providerKind: .compatibility,
        priority: 1,
        capabilities: [.appInstall, .appRegistration, .packageService],
        health: .healthy
    )
    private var installs = 0
    private var registrations = 0

    func inspectInstalledApps() async throws -> [String: PrismInstalledApp] { [:] }
    func inspectRegisteredBundleIdentifiers() async throws -> Set<String> { [] }
    func install(_ operation: AppInstallOperation) async throws -> BackendOperationResult {
        installs += 1
        return .init(operationID: "app-install:\(operation.bundleIdentifier)")
    }
    func register(bundleIdentifier: String) async throws -> BackendOperationResult {
        registrations += 1
        return .init(operationID: "app-register:\(bundleIdentifier)")
    }
    func counts() -> (Int, Int) { (installs, registrations) }
}

private actor RecordingCompatibilityInjectionService: RuntimeInjectionService {
    nonisolated let descriptor = RuntimeApplicationServiceDescriptor(
        identifier: "compat.inject.service",
        displayName: "Compatibility Injection Service",
        providerKind: .compatibility,
        priority: 1,
        capabilities: [.appInjection, .dylibInjection, .packageService],
        health: .healthy
    )
    private var applies = 0
    private var removals = 0

    func inspectActiveInjections() async throws -> Set<InjectionStateKey> { [] }
    func apply(_ operation: InjectionOperation) async throws -> BackendOperationResult {
        applies += 1
        return .init(operationID: "inject:\(operation.targetBundleIdentifier):\(operation.artifact.identifier)")
    }
    func remove(targetBundleIdentifier: String, artifactIdentifier: String) async throws -> BackendOperationResult {
        removals += 1
        return .init(operationID: "inject-remove:\(targetBundleIdentifier):\(artifactIdentifier)")
    }
    func counts() -> (Int, Int) { (applies, removals) }
}

@Test func trollStoreStyleAdapterDelegatesOnlyTypedApplicationOperations() async throws {
    let service = RecordingCompatibilityApplicationService()
    let adapter = TrollStoreStyleApplicationExecutionAdapter(service: service)
    #expect(adapter.capabilities == [.appInstall, .appRegistration])
    #expect(adapter.identifier.contains("compat.install.service"))

    _ = try await adapter.install(.init(bundleIdentifier: "dev.demo.app", displayName: "Demo"))
    _ = try await adapter.register(bundleIdentifier: "dev.demo.app")
    let counts = await service.counts()
    #expect(counts.0 == 1)
    #expect(counts.1 == 1)
}

@Test func trollFoolsStyleAdapterDelegatesOnlyTypedInjectionOperations() async throws {
    let service = RecordingCompatibilityInjectionService()
    let adapter = TrollFoolsStyleInjectionExecutionAdapter(service: service)
    #expect(adapter.capabilities == [.appInjection, .dylibInjection])
    #expect(adapter.identifier.contains("compat.inject.service"))

    let artifact = InjectionArtifact(identifier: "dev.demo.artifact", displayName: "Demo", kind: .dylib, supportedArchitectures: ["arm64"])
    _ = try await adapter.apply(.init(targetBundleIdentifier: "dev.demo.app", artifact: artifact))
    _ = try await adapter.remove(targetBundleIdentifier: "dev.demo.app", artifactIdentifier: artifact.identifier)
    let counts = await service.counts()
    #expect(counts.0 == 1)
    #expect(counts.1 == 1)
}
