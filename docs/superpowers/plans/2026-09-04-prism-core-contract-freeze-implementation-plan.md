# Prism 0.4.1 Core Contract Freeze Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Prism 0.4 Core Contract Freeze by adding runtime installation/integration ownership, versioned handshakes, provider-policy separation, protocol decomposition, trust/provenance, persistent migration, transaction-safe self/provider updates, conformance suites, and Architecture Gates 3.0.

**Architecture:** Preserve Prism 0.4.0 Provider Runtime and its five-tab UI. Add stable integration/update/migration contracts around the existing provider/transaction core, move selection policy out of ProviderRegistry, and validate every write provider against shared conformance rules. RELAXIN-X remains runtime owner; Prism remains package-ecosystem owner.

**Tech Stack:** Swift 6, Foundation, Swift Testing, SwiftUI (iOS 15 baseline), Codable, actors, existing PrismCore Swift package, existing `prismd`, existing Xcode project and verification scripts.

**Spec:** `docs/superpowers/specs/2026-09-04-prism-core-contract-freeze-design.md`

## Global Constraints

- Target release is Prism 0.4.1 Build 41.
- Preserve exactly five primary iPhone tabs: Featured, Packages, Sources, Apps, Activity.
- Prism Core/UI must not gain direct apt/dpkg/basebin/jbctl/socket/root-prefix assumptions.
- RELAXIN-X owns Runtime installation/lifecycle; Prism declares requirements and consumes capabilities.
- Write transactions pin provider identity/version/protocol for the entire transaction.
- Prism/Provider updates must wait for a write-safe point and roll back on activation/handshake/health failure.
- Persistent migration failures preserve old bytes and produce NeedsReview diagnostics; never clear data silently.
- ProviderRegistry stores/discovers providers; Resolver produces candidates; Policy selects candidates.
- Unknown optional features/capabilities/JSON fields must be ignored safely where Codable allows it.
- App installation/injection remain optional extensions and cannot block Core Freeze.
- Every behavior change follows RED → GREEN → REFACTOR.
- macOS/Xcode build runs automatically when `xcodebuild` exists; Linux verification never claims Apple SDK compilation.

---

### Task 1: Runtime Integration Domain + Installer Contract

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDomain/RuntimeIntegrationModels.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/PrismRuntimeInstallerProtocol.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeInstallerContractTests.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeIntegrationStateTests.swift`

**Interfaces:**
- Produces: `RuntimeIntegrationCapability`, `CapabilityAvailability`, `PrismIntegrationState`, `PackageServiceLifecycleState`, `PrismInstallationOwnership`, `PrismInstallationState`, `PrismInstallRequest`, `PrismUpgradeRequest`, `PrismInstallationReceipt`, `PrismRepairResult`, `PrismRuntimeInstallerProtocol`.

- [ ] **Step 1: Write failing domain/installer tests**

```swift
@Test func runtimeManagedOwnershipKeepsLifecycleAuthorityWithRuntime() {
    let ownership = PrismInstallationOwnership.runtimeManaged(runtimeID: "dev.relaxin.runtime")
    #expect(ownership.lifecycleOwnerID == "dev.relaxin.runtime")
}

@Test func integrationStateCanRepresentRepairingAndIncompatible() {
    #expect(PrismIntegrationState.repairing != .ready)
    #expect(PrismIntegrationState.incompatible(reason: "protocol") != .ready)
}
```

- [ ] **Step 2: Run focused tests and confirm RED**

```bash
cd Packages/PrismCore
swift test --filter RuntimeInstallerContractTests
swift test --filter RuntimeIntegrationStateTests
```

Expected: compile failure because new types/protocol do not exist.

- [ ] **Step 3: Implement minimal types/protocol exactly from Spec**

- [ ] **Step 4: Run focused + full tests**

```bash
swift test --filter Runtime
swift test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/PrismCore
git commit -m "feat: add runtime installation contract"
```

---

### Task 2: Versioned Runtime Handshake + Contract Versions

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDomain/ContractVersions.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/RelaxinBridgeContract.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/RelaxinRuntimeProvider.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeProtocolNegotiationTests.swift`

**Interfaces:**
- Produces: version constants, `RuntimeHandshake`, `ProtocolVersionRange`, `RuntimeProtocolNegotiator`.

- [ ] **Step 1: Write failing overlap/incompatibility tests**

```swift
@Test func overlappingProtocolRangesNegotiateHighestCommonVersion() throws {
    let result = try RuntimeProtocolNegotiator.negotiate(runtime: 3...5, prism: 2...4)
    #expect(result == 4)
}

@Test func incompatibleProtocolRangeDoesNotCrash() {
    #expect(throws: RuntimeProtocolNegotiationError.self) {
        try RuntimeProtocolNegotiator.negotiate(runtime: 5...5, prism: 2...4)
    }
}
```

- [ ] **Step 2: Confirm RED**

```bash
swift test --filter RuntimeProtocolNegotiationTests
```

- [ ] **Step 3: Implement versioned handshake and adapter constants**

Use Int protocol versions for runtime/package-service contracts; keep existing string bridge fields decodable through compatibility initializers/adapters.

- [ ] **Step 4: Full bridge regression**

```bash
swift test --filter RelaxinBridge
swift test --filter RuntimeProtocol
swift test
```

- [ ] **Step 5: Commit**

```bash
git add Packages/PrismCore
git commit -m "feat: version runtime integration contracts"
```

---

### Task 3: Split ProviderRegistry / Resolver / Policy + Failure Containment

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismDomain/ProviderRegistry.swift`
- Create: `Packages/PrismCore/Sources/PrismDomain/ProviderResolver.swift`
- Create: `Packages/PrismCore/Sources/PrismDomain/ProviderPolicy.swift`
- Create: `Packages/PrismCore/Sources/PrismDomain/CompatibilityProfile.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/PackageServiceSession.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/ProviderResolverPolicyTests.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/ProviderFailureContainmentTests.swift`

**Interfaces:**
- Produces: `ProviderCandidate`, `ProviderResolving`, `DefaultProviderResolver`, `ProviderPolicyEvaluating`, `DefaultProviderPolicy`, `CompatibilityLevel`, `PrismCompatibilityProfile`.

- [ ] **Step 1: Write failing separation tests**

```swift
@Test func resolverReturnsCompatibleCandidatesWithoutChoosingPolicyWinner() async throws {
    let candidates = await resolver.candidates(for: requirements, environment: environment)
    #expect(candidates.count == 2)
}
```

```swift
@Test func failedRepositoryProviderDoesNotDisableHealthyPackageService() async throws {
    #expect(packageServiceCandidate.runtimeState.health.isUsable)
    #expect(!repositoryCandidate.runtimeState.health.isUsable)
}
```

- [ ] **Step 2: Confirm RED**

- [ ] **Step 3: Move compatibility/filtering from `ProviderRegistry.select` into Resolver and ranking into Policy**

Keep temporary deprecated `select` façade only if needed for source compatibility; implement it by delegating Resolver → Policy.

- [ ] **Step 4: Update SessionFactory to Resolver/Policy**

- [ ] **Step 5: Run registry/session/full regression**

```bash
swift test --filter Provider
swift test --filter PackageServiceSession
swift test
```

- [ ] **Step 6: Commit**

```bash
git add Packages/PrismCore
git commit -m "refactor: split provider registry resolver policy"
```

---

### Task 4: Decompose PackageService Protocol + Provider Conformance Surface

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismTransactions/PackageServiceProtocol.swift`
- Create: `Packages/PrismCore/Sources/PrismTransactions/PackageServiceContracts.swift`
- Modify: package-service providers under `PrismUIBridge/`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/PackageServiceContractTests.swift`

**Interfaces:**
- Produces: `PackageStateService`, `PackagePlanningService`, `PackageExecutionService`, `PackageRecoveryService`, aggregate `PackageServiceProtocol`.

- [ ] **Step 1: Write compile-time conformance tests for four service slices**

```swift
func requireState<T: PackageStateService>(_ value: T) {}
func requireRecovery<T: PackageRecoveryService>(_ value: T) {}
```

- [ ] **Step 2: Confirm RED**

- [ ] **Step 3: Split existing methods without changing behavior**

- [ ] **Step 4: Re-run all provider/session tests**

- [ ] **Step 5: Commit**

```bash
git add Packages/PrismCore
git commit -m "refactor: decompose package service contract"
```

---

### Task 5: Package Trust + Provenance + Journal Audit Metadata

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDomain/TrustModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/PackageModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/RepositoryModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismTransactions/Journal.swift`
- Modify: repository providers to normalize trust
- Test: `Packages/PrismCore/Tests/PrismCoreTests/TrustProvenanceTests.swift`

**Interfaces:**
- Produces: `PackageTrustStatus`, `RepositoryTrustStatus`, `PackageProvenance`.
- Transaction Journal gains provenance records without losing decode compatibility with old journals.

- [ ] **Step 1: Write failing trust/provenance tests**

```swift
@Test func packageProvenanceRecordsProviderAndTrust() {
    let provenance = PackageProvenance(
        packageID: "dev.example",
        version: "1.0",
        formatIdentifier: "dev.relaxin.package",
        repositoryID: "modern",
        providerID: "relaxin",
        providerVersion: "4",
        trustStatus: .verified,
        metadataRevision: "r7"
    )
    #expect(provenance.trustStatus == .verified)
}
```

- [ ] **Step 2: Confirm RED**

- [ ] **Step 3: Add additive fields/default decode behavior**

- [ ] **Step 4: Full repository/journal regression**

- [ ] **Step 5: Commit**

```bash
git add Packages/PrismCore
git commit -m "feat: add package trust and provenance"
```

---

### Task 6: Persistent Schema Versioning + Non-destructive Migration

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDomain/SchemaVersioning.swift`
- Create: `Packages/PrismCore/Sources/PrismTransactions/JournalMigration.swift`
- Modify: `Packages/PrismCore/Sources/PrismTransactions/Journal.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/PersistentStateMigration.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/SchemaMigrationTests.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/TransactionJournalMigrationTests.swift`

**Interfaces:**
- Produces: schema version constants, `PrismSchemaMigrator`, `MigrationResult<Value>`, `MigrationDiagnostic`.

- [ ] **Step 1: Write failing V1/current/future/corrupt tests**

```swift
@Test func futureSchemaVersionPreservesOriginalBytes() throws {
    let result = migrator.attemptMigration(data: data, from: 999)
    #expect(result.requiresReview)
    #expect(result.originalData == data)
}
```

- [ ] **Step 2: Confirm RED**

- [ ] **Step 3: Add versioned envelope and incremental journal migration**

Never delete source data on migration error. Corrupt current journal records continue quarantine behavior but diagnostics retain original bytes/path metadata.

- [ ] **Step 4: Add reusable migration envelopes for provider/environment/integration/ownership state**

- [ ] **Step 5: Run all recovery tests**

```bash
swift test --filter Migration
swift test --filter Recovery
swift test
```

- [ ] **Step 6: Commit**

```bash
git add Packages/PrismCore
git commit -m "feat: add non-destructive schema migration"
```

---

### Task 7: Transaction-safe Prism / Provider Update Coordinator

**Files:**
- Create: `Packages/PrismCore/Sources/PrismTransactions/PrismUpdateModels.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/PrismUpdateCoordinator.swift`
- Modify: `PackageServiceSession.swift` as needed for active write visibility
- Test: `Packages/PrismCore/Tests/PrismCoreTests/PrismSelfUpdateTests.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/ProviderUpdatePinningTests.swift`

**Interfaces:**
- Produces: `PrismUpdateState`, `PrismUpdateCandidate`, `PrismUpdateSnapshot`, `PrismUpdateRuntimeAdapter`, `PrismUpdateCoordinator`.

- [ ] **Step 1: Write safe-point tests**

```swift
@Test func writeTransactionForcesUpdateToWaitForSafePoint() async throws {
    let state = await coordinator.requestActivation(candidate)
    #expect(state == .waitingForSafePoint)
}
```

- [ ] **Step 2: Write rollback tests for activation/handshake/health failure**

- [ ] **Step 3: Confirm RED**

- [ ] **Step 4: Implement stage → wait → snapshot → activate → handshake → health → commit**

- [ ] **Step 5: Implement rollback restoring previous installation/provider registration**

- [ ] **Step 6: Full transaction/update regression**

- [ ] **Step 7: Commit**

```bash
git add Packages/PrismCore
git commit -m "feat: make Prism updates transaction safe"
```

---

### Task 8: Runtime Integration Coordinator + Ownership-aware Lifecycle

**Files:**
- Create: `Packages/PrismCore/Sources/PrismUIBridge/PrismRuntimeIntegrationCoordinator.swift`
- Modify: `Presentation.swift`
- Modify: `App/Navigation/PrismRootView.swift` only for high-level status presentation
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeLifecycleTests.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeOwnershipTests.swift`

**Interfaces:**
- Produces: coordinator that performs inspect/install-or-upgrade/register/handshake/activate/repair according to ownership and capabilities.

- [ ] **Step 1: Write failing install/repair/ownership tests**

- [ ] **Step 2: Confirm RED**

- [ ] **Step 3: Implement lifecycle flow and capability gates**

- [ ] **Step 4: UI remains high-level only**

Ordinary status may show Runtime / System Hooks / Package Service / Prism states; no paths/tool names.

- [ ] **Step 5: Run UI gate/full tests**

```bash
./Scripts/VerifyUI.command
(cd Packages/PrismCore && swift test)
```

- [ ] **Step 6: Commit**

```bash
git add Packages/PrismCore App
git commit -m "feat: coordinate Prism runtime integration lifecycle"
```

---

### Task 9: Provider + RELAXIN-X Bridge Conformance Suites

**Files:**
- Create: `Packages/PrismCore/Tests/PrismCoreTests/ProviderConformanceTests.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/RelaxinBridgeConformanceTests.swift`
- Extend mock providers/fault harness only when required by conformance tests.

**Interfaces:**
- Shared test helpers exercise capability negotiation, state, plan, prepare, execute, journal, interrupt, reconcile, rollback, safeAbort, reconnect, upgrade, runtime disconnect.

- [ ] **Step 1: Write reusable provider conformance harness**

- [ ] **Step 2: Run against Mock modern provider; confirm failures expose missing contracts**

- [ ] **Step 3: Make minimal production/mock changes needed to satisfy suite**

- [ ] **Step 4: Add RELAXIN-X protocol/capability/descriptor conformance matrix**

- [ ] **Step 5: Full test suite**

- [ ] **Step 6: Commit**

```bash
git add Packages/PrismCore
git commit -m "test: freeze provider and bridge conformance contracts"
```

---

### Task 10: Architecture Gates 3.0 + 0.4.1 Release

**Files:**
- Create: `Scripts/VerifyPrismCoreFreeze.command`
- Modify: `Scripts/VerifyXcodeProject.command`
- Modify: `README.md`
- Modify Xcode marketing/build versions to `0.4.1` / `41`
- Test: existing full gate + source scans.

**Interfaces:**
- Release gate verifies new runtime installer, version contracts, resolver/policy split, service decomposition, trust/provenance, schema migration, update coordinator, conformance suites, five-tab UI, AppIcon, `prismd` build and Xcode build when available.

- [ ] **Step 1: Write gate checks before version update so release gate fails**

Required grep/assertions:

```text
PrismRuntimeInstallerProtocol
PrismIntegrationState
RuntimeHandshake
ProviderResolving
ProviderPolicyEvaluating
PackageStateService
PackageRecoveryService
PackageProvenance
PrismSchemaMigrator
PrismUpdateState
ProviderConformanceTests
RelaxinBridgeConformanceTests
```

- [ ] **Step 2: Add Architecture Gates 3.0 forbidden scans**

Core/normal UI forbid `/basebin/`, `jbctl`, `apt-get`, `dpkg-query`, `prismd.sock`, `/var/jb`; explicit legacy-provider allowlist remains.

- [ ] **Step 3: Update release version to 0.4.1 / Build 41**

- [ ] **Step 4: Run full clean release gate**

```bash
./Scripts/VerifyPrismCoreFreeze.command
```

Expected on Linux:

```text
all Swift tests pass
prismd build passes
UI/navigation gates pass
AppIcon passes
Xcode project structure passes
xcodebuild explicitly reported as unavailable/not executed
```

- [ ] **Step 5: Commit**

```bash
git add Scripts README.md Prism.xcodeproj Packages App
git commit -m "chore: freeze Prism 0.4 core contract"
```

- [ ] **Step 6: Re-run release gate from clean commit and archive**

```bash
git status --short
./Scripts/VerifyPrismCoreFreeze.command
git archive --format=zip --output=/mnt/data/Prism-0.4.1-Core-Contract-Freeze-Build41-source.zip HEAD
```

---

## Self-review

- Spec coverage: all 30 source-upgrade sections map to Tasks 1–10 or existing preserved 0.4.0 behavior.
- No placeholders are permitted in implementation tasks.
- Existing 0.4.0 provider runtime is preserved; no rewrite of stable package/repository/transaction/UI foundations.
- Provider identity/version/protocol pinning remains intact throughout update/recovery work.
- RELAXIN-X installer/update operations remain capability-driven and do not implement system privilege acquisition.
- App installation/injection stay optional and non-blocking for Core Freeze.
