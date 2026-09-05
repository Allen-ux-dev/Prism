# Prism Future Wiring Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Convert Prism Build 48 application wiring to future-first runtime/repository composition without redesigning the frozen package/transaction core.

**Architecture:** Add open capability identifiers and adapters, a runtime-aware composition resolver, provider-neutral repository probing/resolution, and descriptor-driven presentation. Preserve all V1 contracts through adapters and keep legacy package service / APT as explicit fallbacks rather than architectural defaults.

**Tech Stack:** Swift 6, Swift Package Manager, Swift Testing, SwiftUI application shell, Xcode project static gates.

**Spec:** `docs/superpowers/specs/2026-09-04-future-wiring-pass-design.md`

## Global Constraints

- Do not redesign Prism Core.
- Do not rewrite Transaction / Journal / Reconcile / Recovery.
- Runtime integration changes must be additive and preserve V1 decoding.
- Modern provider first; legacy provider only as explicit compatibility fallback.
- No silent write-provider fallback after a transaction begins.
- Sources UI consumes normalized Prism repository/package models only.
- Provider failure, timeout, or cancellation must not block unrelated providers or the catalog.
- Build 48 behavior and tests must remain green.

---

### Task 1: Open Capability Contract

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDomain/CapabilityModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/RuntimeIntegrationModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/ContractVersions.swift`
- Modify: `Packages/PrismCore/Sources/PrismDomain/CompatibilityProfile.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/PrismRuntimeIntegrationCoordinator.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/CapabilityExtensibilityTests.swift`

**Interfaces:**
- Produces `CapabilityIdentifier`, `CapabilityState`, `CapabilityRequirement`, `LegacyCapabilityAdapter`.
- `RuntimeHandshake.capabilityStates` preserves unknown identifiers; legacy capability maps remain accepted through overload/adapters.

- [x] Write tests for unknown capability round-trip, unknown optional preservation, unknown required incompatibility, legacy migration, stable standard namespaces.
- [x] Run focused tests and confirm RED because open capability types do not exist.
- [x] Implement open identifier/state/requirement models and legacy adapter.
- [x] Upgrade handshake schema additively, keeping protocol V1 decoding and legacy initializer.
- [x] Upgrade compatibility profile and integration coordinator to consume capability requirements.
- [x] Run focused tests and existing runtime/compatibility tests to GREEN.

### Task 2: Runtime-aware App Composition and Neutral Presentation

**Files:**
- Create: `Packages/PrismCore/Sources/PrismUIBridge/RuntimeCompositionResolver.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/RuntimePresentationDescriptor.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/PrismProviderComposition.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/Presentation.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/PackageServiceSession.swift`
- Modify: `App/AppContainer.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/AppCompositionTests.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/PresentationNeutralityTests.swift`

**Interfaces:**
- Produces `ProviderPreference.modernFirst`, `PrismRuntimeCompositionResolver`, `RuntimePresentationDescriptor`.
- App uses resolver-backed client construction; no default `.hybrid` or `compatibilityFactory` in application code.

- [x] Write tests for modern preference, legacy fallback, read-only/degraded state, provider-policy selection, reconnect recomposition, descriptor display name, no product-name branching.
- [x] Run focused tests and static searches to confirm RED.
- [x] Implement runtime composition resolver using ProviderRegistry → DefaultProviderResolver → ProviderPolicy.
- [x] Add runtime presentation descriptor derived from runtime/environment capability state, never product-name string matching.
- [x] Update AppContainer and PrismClientFacade to resolve/re-resolve composition on connect/reconnect.
- [x] Run focused tests and presentation/provider tests to GREEN.

### Task 3: Repository Provider Resolution, Probe, Timeout and Isolation

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismRepositories/RepositoryProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismRepositories/APTRepositoryProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismRepositories/RelaxinModernRepositoryProvider.swift`
- Modify: `Packages/PrismCore/Sources/PrismRepositories/PrismNativeRepositoryProvider.swift`
- Create: `Packages/PrismCore/Sources/PrismUIBridge/RepositoryProviderResolver.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/RepositoryCatalogClient.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RepositoryResolutionTests.swift`

**Interfaces:**
- Produces `RepositoryProviderProbing`, `RepositoryProbeResult`, `ProviderOperationContext`, `RepositoryProviderResolver`.
- `RepositoryCatalogClient` accepts a provider resolver and never owns `SileoRepositoryProvider` directly.

- [x] Write tests for APT/modern/native selection, unsupported source, policy ranking, failure isolation, timeout and cancellation.
- [x] Run focused tests and static search for direct Sileo ownership to confirm RED.
- [x] Implement provider probes and operation context with deadline/cancellation checks.
- [x] Implement repository provider registry/resolver and per-source isolated loading.
- [x] Rework catalog client to consume normalized provider snapshots and preserve icon/commerce metadata from Prism models.
- [x] Run repository provider, Sources 2.0, visuals and commerce tests to GREEN.

### Task 4: Architecture Gate 4.0 and Release Regression

**Files:**
- Create: `Scripts/VerifyFutureWiring.command`
- Modify: `Scripts/VerifyPrismCoreFreeze.command`
- Modify: `Scripts/VerifyArchitecture.command`
- Modify: `README.md`
- Modify: `Prism.xcodeproj/project.pbxproj`

**Interfaces:**
- Gate rejects application default `compatibilityFactory`, application `.hybrid`, UI direct `SileoRepositoryProvider()`, and product-name behavior branching.

- [x] Add static gate and verify it fails on pre-fix wiring patterns.
- [x] Update build number to 49 and release notes.
- [x] Run `swift test` and `./Scripts/VerifyPrismCoreFreeze.command` from a clean `.build`.
- [x] Confirm transaction/journal/recovery/schema-migration/ownership/runtime-installer/legacy-DEB tests remain green.
- [x] Package a clean Build 49 source ZIP excluding `.build`, `dist`, DerivedData, and VCS metadata.
