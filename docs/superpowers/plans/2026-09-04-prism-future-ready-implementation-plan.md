# Prism Future-Ready Package Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Prism 0.2.0 from a legacy-centered package manager into a provider-driven, modern-first RELAXIN-X package platform without breaking its transaction/recovery guarantees or iPhone/iPad UI structure.

**Architecture:** Open the Domain first (version schemes and package-format identifiers), then introduce ProviderRegistry and PrismEnvironment 2.0, then insert PackageServiceProtocol between Application code and `prismd`. Migrate the existing daemon/APT path into a Legacy provider, add a Modern RELAXIN-X provider and mock app/injection providers, then update presentation and gates so normal UI is capability-driven and quiet-by-default.

**Tech Stack:** Swift 6, SwiftUI/iOS 15+, Foundation, Swift Testing, Codable, existing Unix-socket typed IPC, Swift Package Manager, Xcode project gates.

**Spec:** `docs/superpowers/specs/2026-09-04-prism-future-ready-package-platform-design.md`

## Global Constraints

- Modern-first, Legacy-compatible, Provider-driven, Transaction-safe.
- Prism Core must not require APT, dpkg, DEB, `/var/jb`, bootstrap identity, root prefix, or `prismd`.
- All write operations remain Plan → Transaction → Journal → Reconcile/Recovery.
- No arbitrary shell/command privileged API.
- Legacy filesystem/tool details remain provider-private and Advanced-Diagnostics-only.
- iPhone keeps exactly five primary destinations: Featured, Packages, Sources, Apps, Activity.
- iPad/regular width uses a sidebar without duplicating destination state.
- iOS deployment floor stays iOS 15.
- “Runtime isolation” means low interference and implementation-detail isolation, not evasion of third-party security detection.

---

### Task 1: Open Package Version and Package Format Domain Types

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDomain/PackageVersion.swift`
- Create: `Packages/PrismCore/Sources/PrismDomain/PackageFormatIdentifier.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/PackageModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/Dependency.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/FutureDomainTests.swift`

**Interfaces:**
- Produces: `PackageVersion`, `VersionScheme`, `VersionSchemeRegistry`, `PackageFormatIdentifier`.
- Existing DEB packages migrate through `DebianVersionScheme` without losing Debian ordering semantics.

- [ ] **Step 1: Write failing tests** proving Debian and SemVer schemes compare independently and an unknown package format can be constructed without editing an enum.
- [ ] **Step 2: Run `swift test --filter FutureDomainTests` and verify RED.**
- [ ] **Step 3: Implement `PackageVersion`, scheme registry, Debian/SemVer/native schemes, and open string-backed `PackageFormatIdentifier`.**
- [ ] **Step 4: Migrate `PrismPackage` and dependency constraints to the new abstractions with compatibility initializers for V1 call sites.**
- [ ] **Step 5: Run full `swift test`; keep existing Debian tests green.**
- [ ] **Step 6: Commit `feat: open Prism package version and format types`.**

### Task 2: Introduce PrismEnvironment 2.0 and CapabilityStatus

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismEnvironment/EnvironmentModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismEnvironment/EnvironmentProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismEnvironment/StandardRootlessEnvironmentProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismEnvironment/RootfulEnvironmentProvider.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/FutureEnvironmentTests.swift`

**Interfaces:**
- Produces: optional `legacy` details, runtime identity/version, OS/build, compatibility layers, `CapabilityStatus` report.
- Modern environments are valid without bootstrap/root-prefix/package-database fields.

- [ ] **Step 1: Write failing tests** for a valid modern environment with no legacy namespace and degraded/unknown capability states.
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Implement `PrismEnvironment` 2.0 and migration accessors used by legacy providers.**
- [ ] **Step 4: Move Rootless/Rootful details under `legacy` and keep existing provider behavior through compatibility accessors.**
- [ ] **Step 5: Run environment and full tests.**
- [ ] **Step 6: Commit `feat: add modern Prism environment capability model`.**

### Task 3: Add ProviderRegistry and Repository Provider 2.0

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDomain/ProviderModels.swift`
- Create: `Packages/PrismCore/Sources/PrismDomain/ProviderRegistry.swift`
- Modify: `Packages/PrismCore/Sources/PrismRepositories/RepositoryProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismRepositories/APTRepositoryProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismRepositories/PrismNativeRepositoryProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismRepositories/RelaxinModernRepositoryProvider.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/ProviderRegistryTests.swift`

**Interfaces:**
- Produces deterministic provider selection by kind/health/priority/mode.
- APT filenames and Debian-control parsing stay inside `APTRepositoryProvider`.

- [ ] **Step 1: Write failing selection tests** for Modern > Hybrid > Legacy, explicit override, and no silent fallback after execution begins.
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Implement provider metadata, health, registry, and deterministic selection.**
- [ ] **Step 4: Wrap current Sileo/APT flow behind `APTRepositoryProvider`; add native/Relaxin provider foundations returning normalized snapshots.**
- [ ] **Step 5: Run repository/provider tests and full suite.**
- [ ] **Step 6: Commit `feat: add provider registry and repository provider v2`.**

### Task 4: Insert PackageServiceProtocol and Demote prismd to Legacy Provider

**Files:**
- Create: `Packages/PrismCore/Sources/PrismTransactions/PackageServiceProtocol.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/PrismDaemonProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/RelaxinRuntimeProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/MockPackageServiceProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/PackageActions.swift`
- Modify: `Packages/PrismCore/Sources/PrismPrivilegedProtocol/Messages.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/PackageServiceProviderTests.swift`

**Interfaces:**
- Produces abstract inspect/resolve/prepare/execute/reconcile/rollback/safeAbort surface.
- `PrismDaemonProvider` adapts existing typed IPC; UI/Application code no longer assumes `prismd`.

- [ ] **Step 1: Write failing tests** proving UI actions consume a package-service provider and Modern mode can work without a daemon transport.
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Implement focused service protocols and provider adapters.**
- [ ] **Step 4: Move daemon-specific assumptions behind `PrismDaemonProvider`; add modern runtime protocol adapter with no direct legacy tool knowledge.**
- [ ] **Step 5: Run package-service and full tests.**
- [ ] **Step 6: Commit `feat: abstract Prism package services`.**

### Task 5: Strengthen Transaction 2.0 and Provider-Aware Recovery

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismTransactions/TransactionModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismTransactions/Journal.swift`
- Modify: `Packages/PrismCore/Sources/PrismTransactions/Execution.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/FutureRecoveryTests.swift`

**Interfaces:**
- Adds provider identity/version, interrupted/rollingBack/rolledBack states, opaque recovery token, explicit safe recovery capability.

- [ ] **Step 1: Write failing tests** for interrupted provider recovery, rollback availability, and refusal to silently migrate providers mid-transaction.
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Extend journal and transaction phases while keeping V1 decode migration safe.**
- [ ] **Step 4: Reconcile actual state before continuation; use `NeedsReview` if no safe path exists.**
- [ ] **Step 5: Run recovery and full tests.**
- [ ] **Step 6: Commit `feat: make transaction recovery provider aware`.**

### Task 6: Add Modern/Hybrid/Legacy Mode and Runtime Isolation Policy

**Files:**
- Create: `Packages/PrismCore/Sources/PrismUIBridge/RuntimeModeController.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/RuntimeIsolationPolicy.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/Presentation.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeModeTests.swift`

**Interfaces:**
- Produces `modern`, `hybrid`, `legacy` operating modes and quiet-by-default activation state.
- Ordinary presentation hides legacy paths/tool/socket details; diagnostics can request redacted advanced data.

- [ ] **Step 1: Write failing tests** for Modern default, lazy Legacy activation, provider failure containment, and UI redaction of implementation details.
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Implement mode selection and runtime activation policy.**
- [ ] **Step 4: Coalesce non-actionable health warnings and keep idle services out of normal status text.**
- [ ] **Step 5: Run tests and architecture leak gates.**
- [ ] **Step 6: Commit `feat: add quiet modern runtime modes`.**

### Task 7: Add Safe Mock App Installation and Injection Providers

**Files:**
- Create: `Packages/PrismCore/Sources/PrismUIBridge/MockTrollStoreStyleProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/MockTrollFoolsStyleProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismResolution/AppPlans.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/MockAppProviderTests.swift`

**Interfaces:**
- Simulates IPA import/register/remove/reinstall and injection apply/remove/history through real Prism Plan/Transaction/Journal/Reconcile semantics.
- Does not modify real app bundles or expose arbitrary injection/command execution.

- [ ] **Step 1: Write failing end-to-end simulation tests** for install/reconnect/reconcile and injection/reconnect/reconcile.
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Implement deterministic in-memory/mock providers and typed state snapshots.**
- [ ] **Step 4: Route app/injection simulations through the same transaction engine.**
- [ ] **Step 5: Run tests and privileged API gate.**
- [ ] **Step 6: Commit `feat: add safe app and injection simulation providers`.**

### Task 8: Migrate UI to Modern-First Capability Presentation and Add Layout Gates

**Files:**
- Modify: `App/Navigation/PrismRootView.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/Presentation.swift`
- Create/Modify: existing SwiftUI feature views under the Prism UI target/source group
- Modify: `Scripts/VerifyUI.command`
- Modify: `Scripts/VerifyXcodeProject.command`
- Modify: `Scripts/VerifyPrismV1.command`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/FuturePresentationTests.swift`

**Interfaces:**
- iPhone: exactly 5 top-level destinations.
- iPad: sidebar; same selection state.
- Normal status: Runtime / Package Service / Compatibility / Background only.
- Advanced diagnostics may show provider IDs and redacted legacy details.

- [ ] **Step 1: Write failing presentation tests** for destination count, modern-first labels, degraded/unavailable action states, and no legacy path text in normal UI.
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Update presentation/view structure without changing five-tab information architecture.**
- [ ] **Step 4: Add compact-width/Dynamic-Type-safe layout rules: no fixed-width content cards, scrollable long sections, adaptive grids, minimum tap targets.**
- [ ] **Step 5: Extend static UI gate to reject legacy paths/tool names in ordinary Views and reject accidental sixth primary tab.**
- [ ] **Step 6: Run full Swift tests, `swift build --product prismd`, all static gates, and `xcodebuild` automatically when available on macOS.**
- [ ] **Step 7: Commit `feat: ship Prism future-ready modern UI`.**

### Task 9: Documentation, Migration Gate, and Release Bundle

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-09-04-prism-future-ready-package-platform-design.md`
- Create: `Scripts/VerifyPrismFutureReady.command`

**Interfaces:**
- Produces one release gate covering Core, Provider architecture, UI leak/layout checks, daemon compatibility build, and Xcode build when available.

- [ ] **Step 1: Add release-gate script** that runs `swift test`, `swift build --product prismd`, architecture gates, UI gates, icon/Xcode project checks, and macOS Xcode build when available.
- [ ] **Step 2: Update README architecture and operating-mode documentation.**
- [ ] **Step 3: Mark the approved spec status final and document V1 migration compatibility.**
- [ ] **Step 4: Run `./Scripts/VerifyPrismFutureReady.command` from a clean worktree/repo.**
- [ ] **Step 5: Commit `chore: finalize Prism future-ready migration`.**
- [ ] **Step 6: Produce a clean source ZIP excluding `.git`, `.build`, derived data, and temporary files.**

## Self-Review

- Spec coverage: all sections 4–24 map to Tasks 1–9.
- No new package format requires a Core enum edit.
- No modern environment requires bootstrap/root-prefix/package database.
- `prismd` remains supported but only through `PrismDaemonProvider`.
- Every destructive flow remains Transaction-owned.
- Runtime isolation is UX/architecture isolation only; no detection-evasion behavior is included.
- Mock TrollStore/TrollFools-style flows are non-destructive simulations using the real Prism transaction model.
- UI constraints and compilation gates are explicit release blockers.
