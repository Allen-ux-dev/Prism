# Application Runtime Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Build 49's hardcoded unavailable app execution providers with runtime-aware native and compatibility adapters while preserving Prism's typed transaction pipeline.

**Architecture:** Application and injection runtimes register typed services with descriptors. A resolver chooses runtime-native providers first, then compatibility adapters, and falls back to unavailable providers only when no authorized service is registered. Modern RELAXIN-X package-service transactions remain transport-driven and product-neutral.

**Tech Stack:** Swift 6, Swift Testing, PrismDomain, PrismEnvironment, PrismTransactions, PrismDaemonCore, PrismUIBridge.

**Spec:** `docs/superpowers/specs/2026-09-04-application-runtime-wiring-design.md`

## Global Constraints
- Do not add exploit, signature-bypass, stealth, raw shell, or arbitrary third-party injection logic.
- Keep Transaction / Journal / Reconcile / Recovery semantics unchanged.
- Runtime-native provider is preferred over compatibility adapters.
- TrollStore-style and TrollFools-style names are compatibility adapter identities only, never product-name behavior branches in App UI.
- No silent provider fallback after transaction execution begins.

---

### Task 1: Open application capability identifiers

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismDomain/CapabilityModels.swift`
- Modify: `Packages/PrismCore/Sources/PrismEnvironment/EnvironmentCapabilityAdapter.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/ApplicationRuntimeWiringTests.swift`

**Interfaces:**
- Produces: `CapabilityIdentifier.appInstall`, `appRegistration`, `appReplace`, `appRemoval`, `appRefresh`, `appInjection`, `dylibInjection`, `frameworkInjection`, `bundleInjection`.

- [ ] Write tests asserting stable identifier strings and V1 adapter mappings.
- [ ] Run the focused test and confirm failure for missing identifiers.
- [ ] Add the identifiers and mappings.
- [ ] Run the focused test and confirm pass.

### Task 2: Typed runtime application/injection service registry and adapters

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDaemonCore/RuntimeApplicationProviders.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/ApplicationRuntimeWiringTests.swift`

**Interfaces:**
- Produces: `RuntimeApplicationService`, `RuntimeInjectionService`, `RuntimeApplicationServiceRegistry`, `RuntimeApplicationProviderResolver`, `RuntimeNativeApplicationProvider`, `TrollStoreStyleApplicationAdapter`, `RuntimeNativeInjectionProvider`, `TrollFoolsStyleInjectionAdapter`.

- [ ] Write tests for native-first resolution, compatibility fallback, unavailable fallback, typed forwarding, and injection removal.
- [ ] Run focused tests and confirm they fail because the types do not exist.
- [ ] Implement minimal typed services, registry, adapters and resolver.
- [ ] Run focused tests and confirm pass.

### Task 3: Wire prismd composition and modern runtime requirements

**Files:**
- Modify: `Packages/PrismCore/Sources/prismd/main.swift`
- Modify: `Packages/PrismCore/Sources/PrismUIBridge/RelaxinRuntimeProvider.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/ApplicationRuntimeWiringTests.swift`

**Interfaces:**
- Consumes: `RuntimeApplicationProviderResolver`.
- Produces: runtime-aware application/injection provider composition in prismd and application requirements advertised by modern runtime provider.

- [ ] Write static/behavior tests that fail while prismd hardcodes unavailable providers and modern descriptor omits app requirements.
- [ ] Replace hardcoded unavailable construction with resolver composition.
- [ ] Add app requirements to modern runtime descriptor while runtime capability health still governs actual availability.
- [ ] Run focused tests.

### Task 4: Build 50 gates and release verification

**Files:**
- Create: `Scripts/VerifyApplicationRuntimeWiring.command`
- Modify: `Scripts/VerifyPrismCoreFreeze.command`
- Modify: `Prism.xcodeproj/project.pbxproj`
- Modify: `README.md`

**Interfaces:**
- Produces: static regression gate preventing reintroduction of hardcoded unavailable providers in prismd and raw execution surfaces in compatibility adapters.

- [ ] Add gate assertions and Build 50 version.
- [ ] Run focused gate.
- [ ] Run `TERM=xterm swift test` from a clean `.build` directory.
- [ ] Run `Scripts/VerifyPrismCoreFreeze.command`.
- [ ] Package a clean verified ZIP excluding `.build`, `dist`, `DerivedData` and VCS metadata.
