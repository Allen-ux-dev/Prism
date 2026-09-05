# Prism 0.4.1 Core Contract Freeze Design

**Status:** Approved for implementation  
**Product:** Prism / RELAXIN-X Package Platform  
**Target:** Prism 0.4.1 Build 41  
**Baseline:** Prism 0.4.0 Provider Runtime Upgrade, commit `cbbbdd9`, branch `feature/prism-v1`  
**Source upgrade document:** `Prism-0.4.0-Final-Architecture-Upgrade.md`

## 1. Goal

Prism 0.4.1 completes the final architecture hardening required before freezing the Prism 0.4 Core Contract. The existing provider-runtime architecture remains intact; this release adds the missing long-lived integration, ownership, update-safety, migration, trust, protocol-versioning, failure-containment, and conformance contracts.

The four mandatory long-term additions are:

1. Runtime Installer Contract
2. Installation Ownership
3. Transaction-safe Prism / Provider Update
4. Persistent Schema Migration

This release also adds:

- Runtime integration state and capabilities
- Background lifecycle model
- Protocol version negotiation and versioned contracts
- ProviderRegistry responsibility split into Registry / Resolver / Policy
- PackageService protocol decomposition
- Package trust and provenance
- Compatibility profile
- Provider failure containment
- Provider / RELAXIN-X bridge conformance suites
- Architecture Gates 3.0

After this release, future changes must preferentially extend Provider / Capability contracts instead of changing Prism Domain.

---

## 2. Runtime Installer Contract

Prism currently knows how an already-installed Prism connects to RELAXIN-X. It now also needs a stable contract for RELAXIN-X to install, register, activate, repair, upgrade, deactivate and unregister Prism.

```swift
public protocol PrismRuntimeInstallerProtocol: Sendable {
    func inspectInstallation() async throws -> PrismInstallationState
    func install(request: PrismInstallRequest) async throws -> PrismInstallationReceipt
    func upgrade(request: PrismUpgradeRequest) async throws -> PrismInstallationReceipt
    func registerPrism() async throws
    func registerPackageService() async throws
    func registerLifecycle() async throws
    func activate() async throws
    func repair() async throws -> PrismRepairResult
    func deactivate() async throws
    func unregister() async throws
}
```

Prism never acquires system-level capability by itself. RELAXIN-X Runtime exposes capability and performs runtime-specific installation work.

---

## 3. Runtime Integration Capability and State

```swift
public enum RuntimeIntegrationCapability: String, Codable, Sendable, CaseIterable {
    case packageService
    case backgroundExecution
    case serviceRegistration
    case lifecycleRecovery
    case packageStoreAccess
    case repositoryNetworking
    case userspaceRestart
    case appRegistration
    case runtimeDiagnostics
}

public enum CapabilityAvailability: String, Codable, Sendable {
    case available, degraded, unavailable, unknown
}
```

```swift
public enum PrismIntegrationState: Codable, Sendable, Equatable {
    case notInstalled
    case installed
    case registered
    case activating
    case ready
    case degraded(reason: String)
    case repairing
    case recovering
    case disabled
    case incompatible(reason: String)
}
```

Standard integration flow:

```text
Runtime Ready
→ Inspect Prism
→ Install / Upgrade
→ Register Prism
→ Register Package Service
→ Register Lifecycle
→ Handshake
→ Activate
→ Ready
```

Prism Core must not query basebin/jbctl/launchd paths/root-prefix paths directly.

---

## 4. Background Lifecycle

```swift
public enum PackageServiceLifecycleState: String, Codable, Sendable {
    case idle
    case activating
    case active
    case finishing
    case recovering
    case degraded
    case unavailable
}
```

The normal pattern is background-capable but not permanently busy:

```text
Idle → Activating → Active → Transaction → Reconcile → Journal Commit → Finishing → Idle
```

Legacy APT, source build, injection, and advanced diagnostics remain off/idle unless required.

---

## 5. Runtime Handshake and Version Negotiation

Runtime and Prism versions are not assumed equal.

```swift
public struct RuntimeHandshake: Codable, Sendable, Equatable {
    public let protocolVersion: Int
    public let minimumCompatibleVersion: Int
    public let runtimeIdentity: String
    public let runtimeVersion: String
    public let prismVersion: String
    public let packageServiceVersion: Int
    public let capabilities: [RuntimeIntegrationCapability: CapabilityAvailability]
    public let optionalFeatures: Set<String>
}
```

Prism advertises a supported range and negotiates an overlap. Incompatible protocol versions produce `PrismIntegrationState.incompatible` and never crash or silently fall back for write operations.

Long-lived version constants:

```text
RuntimeIntegrationProtocolVersion
PackageServiceProtocolVersion
RepositoryProviderProtocolVersion
TransactionJournalSchemaVersion
EnvironmentSchemaVersion
CapabilitySchemaVersion
ProviderStateSchemaVersion
```

Rules:

- Prefer additive changes.
- Keep old fields while compatible.
- Breaking changes require an Adapter.
- Multiple adapters may coexist during transition.
- Unknown JSON fields are safely ignored.
- Unknown capabilities do not make an entire object undecodable.

---

## 6. Installation Ownership

```swift
public enum PrismInstallationOwnership: Codable, Sendable, Equatable {
    case standalone
    case runtimeManaged(runtimeID: String)
    case legacyMigrated
    case external(identifier: String)
}
```

Ownership determines lifecycle authority for install/upgrade/repair/registration/unregister/removal. It does **not** select package functionality; capability remains the behavior contract.

When runtime-managed, Prism must not independently replace itself while RELAXIN-X owns update lifecycle.

---

## 7. Transaction-safe Prism and Provider Updates

```swift
public enum PrismUpdateState: Codable, Sendable, Equatable {
    case idle
    case downloading
    case validating
    case staged
    case waitingForSafePoint
    case activating
    case verifying
    case committed
    case rollingBack
    case rolledBack
    case failed(reason: String)
}
```

Correct update sequence:

```text
Download
→ Validate
→ Stage
→ Wait for transaction-safe point
→ Snapshot installation
→ Activate candidate
→ Handshake
→ Health check
→ Commit
```

Failure sequence:

```text
Activation/handshake/health failure
→ Restore previous installation
→ Restore provider registration
→ Handshake
→ Rollback complete
```

Provider updates obey the same safe-point and pinning rules.

A write transaction pins Provider ID, Provider Version and Protocol Version for its lifetime. Provider failure leads to Interrupted → Reconcile → explicit Resume / Rollback / SafeAbort / NeedsReview. Silent provider switching remains prohibited.

---

## 8. Provider Responsibility Split

`ProviderRegistry` becomes storage/discovery only:

```text
Register
Remove
Discover
Lookup
Runtime State
Diagnostics Snapshot
```

Selection logic moves to:

```swift
public protocol ProviderResolving: Sendable {
    func candidates(
        for requirements: ProviderOperationRequirements,
        environment: PrismEnvironment
    ) async -> [ProviderCandidate]
}

public protocol ProviderPolicyEvaluating: Sendable {
    func select(
        from candidates: [ProviderCandidate],
        context: ProviderSelectionContext
    ) async -> ProviderCandidate?
}
```

Final flow:

```text
ProviderRegistry → ProviderResolver → ProviderPolicy → Selected Provider
```

This prevents ProviderRegistry from becoming a policy god object.

---

## 9. Package Service Protocol Decomposition

Split the long-term service contract:

```swift
public protocol PackageStateService: Sendable {}
public protocol PackagePlanningService: Sendable {}
public protocol PackageExecutionService: Sendable {}
public protocol PackageRecoveryService: Sendable {}

public protocol PackageServiceProtocol:
    PrismProvider,
    PackageStateService,
    PackagePlanningService,
    PackageExecutionService,
    PackageRecoveryService {}
```

The application façade may consume the aggregate protocol. Partial providers can advertise only the capability groups they implement through adapters/composition.

---

## 10. Package Trust and Provenance

```swift
public enum PackageTrustStatus: String, Codable, Sendable {
    case trusted, verified, unverified, invalid, unknown
}

public enum RepositoryTrustStatus: String, Codable, Sendable {
    case trusted, verified, unverified, invalid, unknown
}
```

Provider-specific verification stays inside the provider. Prism Core consumes only normalized trust state.

```swift
public struct PackageProvenance: Codable, Sendable, Equatable {
    public let packageID: String
    public let version: String
    public let formatIdentifier: String
    public let repositoryID: String?
    public let providerID: String
    public let providerVersion: String
    public let trustStatus: PackageTrustStatus
    public let metadataRevision: String?
}
```

Transaction Journal records provider, repository, package identity/version/format/trust provenance for auditable recovery.

---

## 11. Persistent Schema Migration

Every persisted root structure gains `schemaVersion`:

- Transaction Journal
- Package Store
- Repository Cache
- Provider Metadata
- Provider Runtime State
- Environment Snapshot
- Installed Package State
- Prism Integration State
- Installation Ownership

Migration contract:

```swift
public protocol PrismSchemaMigrator: Sendable {
    associatedtype Value
    var currentVersion: Int { get }
    func migrate(data: Data, from version: Int, to version: Int) throws -> Value
}
```

Migration is incremental (`V1 → V2 → V3 → current`). Decode failure must never silently clear persistent state.

Migration failure:

```text
Preserve original data
→ NeedsReview
→ Diagnostic snapshot
→ Recovery available
```

Unknown future schema versions fail safely and preserve data.

---

## 12. Compatibility Profile

```swift
public enum CompatibilityLevel: String, Codable, Sendable {
    case compatible
    case partiallyCompatible
    case degraded
    case unsupported
    case unknown
}

public struct PrismCompatibilityProfile: Codable, Sendable, Equatable {
    public let runtimeCompatibility: CompatibilityLevel
    public let osCompatibility: CompatibilityLevel
    public let architectureCompatibility: CompatibilityLevel
    public let packageFormatCompatibility: CompatibilityLevel
    public let providerCompatibility: CompatibilityLevel
    public let requiredCapabilities: Set<String>
    public let optionalCapabilities: Set<String>
}
```

UI avoids binary supported/unsupported when the environment is partially usable.

---

## 13. Provider Failure Containment

Failures are isolated by provider kind:

```text
Repository Provider
Package Service Provider
Environment Provider
App Installation Provider
Injection Provider
```

One provider becoming failed/degraded never globally disables Prism when another independent path remains healthy. Provider identity and provider health remain separate concepts.

---

## 14. RELAXIN-X Bridge Boundary

Prism may know:

- Runtime identity/version
- OS version/build
- architecture/SoC family
- capabilities/environment state
- package-service descriptor
- protocol version

Prism must not know:

- exploit implementation
- kernel backend internals
- basebin/jbctl/hook binary paths
- bootstrap directory structure

Kernel backend replacement requires no Prism Core change.

---

## 15. Source / Package Compatibility Contract

Application Layer submits only:

```text
Package Requirements
Capabilities
Transaction Request
```

ProviderResolver decides whether APT/Sileo/Zebra legacy or Modern RELAXIN-X services satisfy those requirements. Application code must not branch on package format or runtime identity.

---

## 16. Conformance Suites

A write Package Service Provider must pass shared conformance tests covering:

- Capability negotiation
- State inspection
- Plan creation
- Prepare
- Execute
- Journal integration
- Interrupted transaction
- Reconcile
- Rollback
- SafeAbort
- Provider reconnect
- Provider upgrade
- Runtime disconnect

RELAXIN-X Bridge conformance tests additionally cover protocol ranges, unknown optional features/capabilities, degraded/unavailable service states and descriptor compatibility.

Runtime installer tests cover missing/already-installed/outdated/newer Prism, interrupted install/registration/lifecycle registration, runtime reconnect repair, unregister failure.

Self-update tests cover idle/read/write safe points, activation/handshake/health failures and rollback success/failure.

Schema migration tests cover every supported historical version, current-to-current, corrupted data, unknown future version and partial migration failure.

---

## 17. Architecture Gates 3.0

Prism Core must compile and test without:

```text
APT
dpkg
DEB
/var/jb
prismd
RELAXIN-X
basebin
traditional bootstrap
specific runtime name
specific kernel backend
specific repository format
```

Core / normal UI forbid direct references to:

```text
/basebin/
jbctl
apt-get
dpkg-query
prismd.sock
/var/jb
```

Only explicitly allowlisted legacy-provider implementation files may contain legacy implementation details.

---

## 18. Scope Freeze

Priority remains:

```text
P0 Package Platform
P1 RELAXIN-X Integration
P2 Legacy Compatibility
P3 Optional Extensions
```

App Installation / Injection Provider abstractions remain supported but cannot block Core Freeze.

---

## 19. Definition of Done

Before Prism 0.4 Core Contract Freeze:

- Runtime installer contract implemented
- Runtime integration state implemented
- Runtime handshake versioned and negotiated
- Package Service protocol versioned
- RELAXIN-X-side installer adapter can install/upgrade/register/activate/repair Prism through the contract
- Installation ownership implemented
- Prism and Provider update flows are transaction-safe
- ProviderRegistry / Resolver / Policy responsibilities separated
- Provider failure containment implemented
- Package trust abstraction and provenance implemented
- Persistent schema migration implemented without destructive fallback
- Provider Conformance Suite passes
- RELAXIN-X Bridge Conformance passes
- Legacy provider remains available
- Modern provider works without prismd/basebin/traditional bootstrap
- App/UI has no kernel-backend dependency
- Kernel backend replacement requires no Prism Core change
- Five-tab iPhone navigation and existing UI layout gates remain green
- Swift Core and prismd compile in the available environment
- macOS/Xcode gate runs automatically when Xcode is present and Linux never claims Apple SDK compilation

---

## 20. Final Principle

> Exploit is replaceable.  
> Runtime is modular.  
> Package services are provider-driven.  
> Integration contracts stay stable.  
> Transactions survive implementation changes.  
> Legacy is compatibility, not architecture.  
> RELAXIN-X owns Runtime.  
> Prism owns Package Ecosystem.

**Change only what changed.**
