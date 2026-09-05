# Prism 0.4.0 Provider Runtime Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Prism 0.3.0 into a dynamic provider runtime platform for RELAXIN-X while preserving the stable package, transaction, journal, recovery, UI-navigation, and legacy compatibility contracts.

**Architecture:** Keep Prism Domain/UI independent of concrete package backends. Turn ProviderRegistry into a live registry, formalize the RELAXIN-X bridge/session contract, enforce safe recovery before write-provider selection, remove direct prismd construction from application bootstrap, and use deterministic mock fault injection to validate interruption/rollback/safe-abort behavior. UI remains provider-aware but implementation-detail free.

**Tech Stack:** Swift 6, Foundation, Swift Testing, SwiftUI (iOS 15 baseline), Codable, actors, existing PrismCore Swift package, existing Xcode project and verification scripts.

**Spec:** `docs/superpowers/specs/2026-09-04-prism-provider-runtime-upgrade-design.md`

## Global Constraints

- Target release is Prism 0.4.0 Build 40.
- Preserve exactly five primary iPhone tabs: Featured, Packages, Sources, Apps, Activity.
- Prism UI and Domain must not gain direct apt/dpkg/basebin/socket/path assumptions.
- A write transaction is pinned to its selected provider identity/version/protocol and never silently migrates providers during recovery.
- A write-capable provider must advertise at least one safe recovery strategy: reconcile, rollback, or safeAbort.
- RELAXIN-X modern provider is preferred in Modern mode; Legacy compatibility is never a silent write fallback.
- Mock TrollStore-style and TrollFools-style flows remain non-destructive and reuse the same transaction/recovery fault harness.
- All behavior changes follow RED → GREEN → REFACTOR.
- macOS/Xcode builds are executed by `VerifyPrismProviderRuntime.command` when `xcodebuild` is present; Linux verification must not claim Apple SDK compilation.

---

### Task 1: Provider Runtime State + Registry 2.0

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismDomain/ProviderModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/ProviderRegistry.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/ProviderRegistryRuntimeTests.swift`

**Interfaces:**
- Produces: `ProviderIdentity`, `ProviderRuntimeState`, `ProviderRecoveryStrategy`, `ProviderDiagnosticsSnapshot`
- Produces: `ProviderRegistry.refreshHealth(_:)`, `runtimeState(_:)`, `resolveCapabilities(_:)`, `diagnosticsSnapshot()`, `changes()`
- Consumes existing `PrismProviderDescriptor`, `ProviderSelectionContext`, `ProviderHealth`

- [ ] **Step 1: Write failing live-health tests**

```swift
@Test func registryRefreshesLiveProviderHealthWithoutReregistering() async throws {
    let provider = MutableHealthFixtureProvider(id: "modern", health: .healthy)
    let registry = ProviderRegistry()
    await registry.register(provider)
    await provider.setHealth(.degraded("runtime restarting"))
    let refreshed = try await registry.refreshHealth("modern")
    #expect(refreshed.health == .degraded("runtime restarting"))
}

@Test func registryDiagnosticsExposeStableIdentityAndLiveStateSeparately() async throws {
    let registry = ProviderRegistry()
    await registry.register(MutableHealthFixtureProvider(id: "modern", health: .healthy))
    let snapshot = await registry.diagnosticsSnapshot()
    #expect(snapshot.first?.identity.providerID == "modern")
    #expect(snapshot.first?.runtimeState.health == .healthy)
}
```

- [ ] **Step 2: Run tests and verify RED**

Run: `cd Packages/PrismCore && swift test --filter ProviderRegistryRuntimeTests`

Expected: compile/test failure because runtime-state APIs do not exist.

- [ ] **Step 3: Add stable identity + live runtime state models**

```swift
public struct ProviderIdentity: Codable, Hashable, Sendable {
    public let providerID: String
    public let providerKind: ProviderKind
    public let providerVersion: String
    public let protocolVersion: String?
}

public enum ProviderRecoveryStrategy: String, Codable, Hashable, Sendable {
    case reconcile, rollback, safeAbort
}

public struct ProviderRuntimeState: Codable, Hashable, Sendable {
    public var health: ProviderHealth
    public var capabilityReport: [String: ProviderHealth]
    public var supportedFormats: Set<PackageFormatIdentifier>
    public var supportedVersionSchemes: Set<String>
    public var recoveryStrategies: Set<ProviderRecoveryStrategy>
    public var lastHealthChange: Date
    public var diagnosticSummary: String?
}
```

Keep `PrismProviderDescriptor` source-compatible by deriving an initial `ProviderIdentity` and `ProviderRuntimeState` from existing fields.

- [ ] **Step 4: Make Registry cache live state and refresh from providers**

Add a small optional live-state protocol:

```swift
public protocol PrismRuntimeStateReporting: PrismProvider {
    func providerRuntimeState() async -> ProviderRuntimeState
}
```

If a provider does not conform, Registry derives state from descriptor.

- [ ] **Step 5: Run focused + full tests**

Run:

```bash
cd Packages/PrismCore
swift test --filter ProviderRegistryRuntimeTests
swift test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Packages/PrismCore
git commit -m "feat: make provider registry runtime-aware"
```

---

### Task 2: Enforce Safe Recovery Contracts Before Provider Selection

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismDomain/ProviderModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/ProviderRegistry.swift`
- Modify: `Packages/PrismCore/Sources/PrismTransactions/PackageServiceProtocol.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/ProviderRecoveryContractTests.swift`

**Interfaces:**
- Produces: `ProviderWriteCapability`, `ProviderRegistryError.missingRecoveryStrategy`
- Produces: selection rule rejecting write providers with zero recovery strategy

- [ ] **Step 1: Write failing selection tests**

```swift
@Test func writeProviderWithoutRecoveryStrategyIsUnavailableForWriteSelection() async throws {
    let registry = ProviderRegistry()
    await registry.register(UnsafeWriteProvider())
    await #expect(throws: ProviderRegistryError.self) {
        _ = try await registry.select(
            kind: .packageService,
            context: .init(mode: .modern, requiredRequirements: ["packageInstall"])
        )
    }
}
```

- [ ] **Step 2: Verify RED**

Run: `cd Packages/PrismCore && swift test --filter ProviderRecoveryContractTests`

- [ ] **Step 3: Add recovery-strategy advertising to PackageServiceProtocol**

```swift
public protocol PackageServiceProtocol: PrismProvider {
    var recoveryStrategies: Set<ProviderRecoveryStrategy> { get }
    // existing methods remain
}
```

Default is read-only safe: `[]`. Every concrete write provider must explicitly advertise strategies.

- [ ] **Step 4: Add Registry preflight validation**

When request requirements contain any write capability (`packageInstall`, `packageRemove`, `packageUpgrade`, `appInstall`, `appInjection`) and runtime state has no recovery strategy, treat provider as unavailable with reason `Write provider has no safe recovery strategy`.

- [ ] **Step 5: Update concrete providers**

Advertise:

```text
RelaxinRuntimeProvider  -> transport descriptor strategies
PrismDaemonProvider     -> reconcile + safeAbort (+ rollback only if implemented)
MockPackageService      -> reconcile + rollback + safeAbort
Mock App providers      -> reuse mock service recovery set
```

- [ ] **Step 6: Run focused + full tests and commit**

```bash
cd Packages/PrismCore
swift test --filter ProviderRecoveryContractTests
swift test
git add Packages/PrismCore
git commit -m "feat: enforce provider recovery contracts"
```

---

### Task 3: Formal RELAXIN-X Bridge Handshake and Descriptor Contract

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/RelaxinRuntimeProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/RelaxinBridgeContract.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/RelaxinBridgeTests.swift`

**Interfaces:**
- Produces: `RelaxinBridgeHandshake`, `RuntimeDescriptor`, `PackageServiceDescriptor`, `RelaxinBridgeSession`
- Produces structured `BridgeError`
- `RelaxinRuntimeServiceTransport.activate()` must negotiate descriptors before servicing writes

- [ ] **Step 1: Write failing bridge tests**

```swift
@Test func relaxinBridgeRejectsUnsupportedProtocolBeforeCreatingSession() async throws {
    let transport = FixtureRelaxinBridgeTransport(protocolVersion: "99")
    let provider = RelaxinRuntimeProvider(transport: transport)
    await #expect(throws: BridgeError.self) { try await provider.activate() }
}

@Test func relaxinBridgePublishesRuntimeAndServiceDescriptorsAfterHandshake() async throws {
    let provider = RelaxinRuntimeProvider(transport: FixtureRelaxinBridgeTransport(protocolVersion: "1"))
    try await provider.activate()
    let session = try await provider.bridgeSession()
    #expect(session.runtime.runtimeIdentity == "dev.relaxin.runtime")
    #expect(session.service.supportedPackageFormats.contains(.relaxinPackage))
}
```

- [ ] **Step 2: Verify RED**

Run: `cd Packages/PrismCore && swift test --filter RelaxinBridgeTests`

- [ ] **Step 3: Implement typed descriptors**

`RuntimeDescriptor` includes runtime identity/version, architecture, SoC family, OS version/build, environment state, compatibility layers, runtime capabilities.

`PackageServiceDescriptor` includes service identity/version, protocol version, capabilities, supported formats/version schemes, recovery strategies and session behavior.

- [ ] **Step 4: Make activate perform handshake + protocol validation**

No concrete socket/path fields are exposed to UI. Unsupported protocol maps provider health to `.unavailable("Unsupported bridge protocol")`.

- [ ] **Step 5: Run tests and commit**

```bash
cd Packages/PrismCore
swift test --filter RelaxinBridgeTests
swift test
git add Packages/PrismCore
git commit -m "feat: formalize RELAXIN-X bridge contract"
```

---

### Task 4: PackageServiceSession + Registry-Driven Bootstrap

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/PackageServiceBootstrap.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/Presentation.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/PackageServiceSession.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/PackageServiceSessionTests.swift`

**Interfaces:**
- Produces: `PackageServiceSession`, `PackageServiceSessionFactory`
- Removes direct application construction of `PrismDaemonProvider`
- `PrismClientFacade` consumes a session factory/session rather than daemon knowledge

- [ ] **Step 1: Write failing bootstrap test**

```swift
@Test func bootstrapSelectsThroughRegistryWithoutConstructingLegacyProviderInApplicationLayer() async throws {
    let registry = ProviderRegistry()
    let modern = MockPackageServiceProvider(environment: .fixtureModern)
    await registry.register(modern)
    let session = try await PackageServiceSessionFactory(registry: registry)
        .makeSession(mode: .modern, runtimeIdentity: "dev.relaxin.runtime")
    #expect(session.providerIdentity.providerID == modern.descriptor.identifier)
}
```

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement session wrapper**

```swift
public actor PackageServiceSession {
    public let providerIdentity: ProviderIdentity
    public private(set) var runtimeState: ProviderRuntimeState
    public let service: any PackageServiceProtocol

    public func refreshProviderState() async
    public func reconnectIfSupported() async throws
    public func diagnosticsSnapshot() async -> ProviderDiagnosticsSnapshot
}
```

- [ ] **Step 4: Replace `compatibilityFallback()` construction**

`PackageServiceBootstrap` registers passed providers and returns a session factory. Legacy provider registration occurs in composition/root code only, never in `PrismClientFacade`.

- [ ] **Step 5: Update facade constructors**

Retain test-friendly `init(service:)`, add `init(session:)`; remove direct socket-path/daemon constructor from ordinary application path.

- [ ] **Step 6: Run tests + architecture grep and commit**

```bash
cd Packages/PrismCore
swift test --filter PackageServiceSessionTests
swift test
cd ../..
! grep -RIn 'PrismDaemonProvider(' Packages/PrismCore/Sources/PrismUIBridge/Presentation.swift Packages/PrismCore/Sources/PrismUIBridge/PackageServiceBootstrap.swift
git add Packages/PrismCore
git commit -m "refactor: bootstrap package services through registry sessions"
```

---

### Task 5: Repository / Service Compatibility Selection

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismDomain/ProviderModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/ProviderRegistry.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/PackageActions.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/ProviderCompatibilitySelectionTests.swift`

**Interfaces:**
- Produces request requirements derived from package format/capabilities, not hard-coded `.deb` application switches

- [ ] **Step 1: Write failing Hybrid selection tests**

```swift
@Test func hybridDebRequestSelectsServiceThatSupportsDebCompatibility() async throws {
    // modern provider lacks org.debian.deb; compatibility provider supports it.
    // Expect compatibility provider only because the request requires that format.
}

@Test func modernRelaxinPackageNeverFallsBackToLegacyProvider() async throws {
    // Expect noCompatibleProvider when modern service unavailable.
}
```

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Add generic `ProviderOperationRequirements`**

```swift
public struct ProviderOperationRequirements: Sendable, Hashable {
    public let capabilities: Set<String>
    public let packageFormats: Set<PackageFormatIdentifier>
    public let runtimeIdentity: String?
    public let isWrite: Bool
}
```

Package actions derive this object from Domain data.

- [ ] **Step 4: Select service through Registry using those requirements**

No application switch on `.debianDeb` or `dev.relaxin.package` identifiers.

- [ ] **Step 5: Run tests and commit**

```bash
cd Packages/PrismCore
swift test --filter ProviderCompatibilitySelectionTests
swift test
git add Packages/PrismCore
git commit -m "feat: coordinate repository formats with service providers"
```

---

### Task 6: Deterministic Fault-Injection + Recovery Harness

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/MockPackageServiceProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/MockTrollStoreStyleProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/MockTrollFoolsStyleProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/MockProviderFaults.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/ProviderFaultInjectionTests.swift`

**Interfaces:**
- Produces `MockProviderFaultMode`
- Produces deterministic rollback/safeAbort/reconcile outcomes reusable by package/app/injection simulations

- [ ] **Step 1: Write failing fault-mode tests**

Required tests:

```text
normal → completed
failBeforeExecution → failed without backend mutation
interruptAfterOperation(0) → interrupted → reconcile → completed/needsRecovery based on actual state
rollbackSucceeds → rolledBack
rollbackFails → needsReview
safeAbortSucceeds → cancelled
reconcileAlreadyApplied → completed without duplicate execution
```

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement deterministic fault controller**

```swift
public enum MockProviderFaultMode: Sendable, Equatable {
    case normal
    case failBeforeExecution
    case failAfterOperation(Int)
    case interruptAfterOperation(Int)
    case degradedBeforeExecution
    case degradedDuringExecution
    case rollbackSucceeds
    case rollbackFails
    case safeAbortSucceeds
    case safeAbortFails
    case reconcileAlreadyApplied
    case reconcilePartiallyApplied
}
```

- [ ] **Step 4: Reuse the same controller in Mock package, TrollStore-style, and TrollFools-style providers**

Simulation remains non-destructive.

- [ ] **Step 5: Run tests and commit**

```bash
cd Packages/PrismCore
swift test --filter ProviderFaultInjectionTests
swift test
git add Packages/PrismCore
git commit -m "test: add provider fault injection recovery harness"
```

---

### Task 7: Provider-Aware UI State + Advanced Diagnostics

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/Presentation.swift`
- Modify: `App/Navigation/PrismRootView.swift`
- Modify: `Scripts/VerifyUI.command`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/ProviderPresentationTests.swift`

**Interfaces:**
- Produces presentation rows for Provider ID/version/protocol/health/formats/capabilities/recovery strategies/last health change
- Normal settings remain task-oriented and implementation-detail free

- [ ] **Step 1: Write failing presentation tests**

```swift
@Test func degradedProviderShowsConciseDailyReasonAndAdvancedProviderDetails() {
    let state = ProviderRuntimeState.fixtureDegraded
    let presentation = PrismProviderPresentation.make(identity: .fixture, state: state)
    #expect(presentation.dailyRows.contains { $0.title == "Package Service" && $0.detail.contains("Degraded") })
    #expect(presentation.advancedRows.contains { $0.title == "Provider ID" })
    #expect(presentation.advancedRows.contains { $0.title == "Recovery" })
}
```

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement presentation mapping**

Daily rows stay exactly: Runtime, Package Service, Compatibility, Background.

Advanced rows include only sanitized provider/runtime metadata.

- [ ] **Step 4: Make SwiftUI layout adaptive**

Use vertical/adaptive stacks, `fixedSize(horizontal: false, vertical: true)` for long reasons, no large fixed widths, keep five tabs exactly.

- [ ] **Step 5: Run presentation tests + UI gate and commit**

```bash
cd Packages/PrismCore
swift test --filter ProviderPresentationTests
cd ../..
./Scripts/VerifyUI.command
git add Packages/PrismCore App Scripts
git commit -m "feat: surface live provider state in Prism UI"
```

---

### Task 8: 0.4.0 Versioning + Release/Compilation Gate

**Files:**
- Modify: `Prism.xcodeproj/project.pbxproj`
- Modify: `Packages/PrismCore/Sources/prismd/main.swift`
- Modify: relevant service handshake/version constants
- Modify: `README.md`
- Create: `Scripts/VerifyPrismProviderRuntime.command`
- Modify: `Scripts/VerifyXcodeProject.command`
- Modify: `docs/superpowers/specs/2026-09-04-prism-provider-runtime-upgrade-design.md` status

**Interfaces:**
- Release: `0.4.0`, Build `40`
- Final gate validates registry 2.0, bridge, recovery enforcement, session bootstrap, UI, app icon, prismd build, full tests, and Xcode build when available

- [ ] **Step 1: Write version expectation test and verify RED**

Update existing provider/handshake test to expect `0.4.0`, run it before production version changes.

- [ ] **Step 2: Update production version/build**

Set:

```text
MARKETING_VERSION = 0.4.0
CURRENT_PROJECT_VERSION = 40
provider/service release version = 0.4.0
```

- [ ] **Step 3: Add final gate**

`VerifyPrismProviderRuntime.command` runs:

```bash
./Scripts/VerifyArchitecture.command
./Scripts/VerifyUI.command
./Scripts/VerifyAppIcon.command
./Scripts/VerifyXcodeProject.command
```

and greps for:

```text
ProviderRuntimeState
refreshHealth
RelaxinBridgeHandshake
PackageServiceSession
ProviderRecoveryStrategy
MockProviderFaultMode
```

It fails if ordinary App/UI contains `/var/jb`, `apt-get`, `dpkg-query`, `prismd.sock`, `basebin`, or direct `PrismDaemonProvider(` construction.

- [ ] **Step 4: Run final verification**

```bash
./Scripts/VerifyPrismProviderRuntime.command
```

Expected on Linux: Swift tests/build + static/Xcode structure gates pass, with explicit `xcodebuild not present` message.
Expected on macOS: iOS Simulator `xcodebuild` also passes.

- [ ] **Step 5: Update README + spec status and commit**

```bash
git add README.md Prism.xcodeproj Packages Scripts docs
git commit -m "chore: release Prism 0.4.0 provider runtime upgrade"
```

---

## Self-Review Coverage

- ProviderRegistry 2.0: Task 1
- Safe recovery contract enforcement: Task 2
- RELAXIN-X formal bridge/session descriptors: Task 3
- prismd demotion / application bootstrap cleanup: Task 4
- Repository/service format compatibility: Task 5
- Modern + TrollStore-style + TrollFools-style failure validation: Task 6
- Dynamic provider health in UI/diagnostics with layout constraints: Task 7
- Version/build/compile/release gates: Task 8
- Transaction provider pinning remains covered by existing `FutureRecoveryTests` and is exercised again by Tasks 2/6.

No production task introduces generic shell execution, privilege escalation, third-party detection evasion, or direct UI access to backend paths.
