# Prism Build 52 Complete Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver a complete provider-neutral Prism store experience on top of the frozen Build 51 runtime/package cores and produce the consolidated RELAXIN-X upgrade specification required to make all real runtime capabilities available.

**Architecture:** Add a normalized store presentation/query layer to PrismUIBridge and a typed application-management controller over the existing privileged transaction protocol. Split store UI pages out of PrismRootView while keeping the five-root-tab contract and existing AppContainer coordination. No exploit/signing-bypass/high-risk privilege logic is added to Prism.

**Tech Stack:** Swift 6, SwiftUI (iOS 15+), Swift Package Manager, existing PrismDomain/PrismUIBridge/PrismTransactions/PrismPrivilegedProtocol.

**Spec:** `docs/superpowers/specs/2026-09-04-complete-store-design.md`

## Global Constraints
- Five iPhone root tabs exactly: Featured / Packages / Sources / Apps / Activity.
- Settings is not a root tab.
- Modern First / Legacy On Demand / No Silent Write Fallback.
- Native runtime provider preferred over compatibility provider.
- No provider change during an active transaction.
- Simulation is Advanced/Lab only.
- No exploit/signing-bypass/arbitrary shell/PID/kernel/raw privileged-path APIs in Prism.
- iOS deployment target remains 15.0.
- English and Simplified Chinese remain supported.

---

### Task 1: Store presentation/query domain
**Files:**
- Create: `Packages/PrismCore/Sources/PrismUIBridge/StorePresentation.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/StorePresentationTests.swift`

**Interfaces:**
- Consumes: `PrismPackageRow`, `PrismSourceRow`, `PrismTransactionRow`, commerce presentation.
- Produces: `PrismStoreQuery`, `PrismStorePresentationBuilder`, category/filter/sort/detail/activity models.

- [x] Write tests proving category derivation, combined filters, deterministic sort, source detail, package detail, featured/update counts and activity bucketing.
- [x] Run targeted tests and verify RED because store types do not exist.
- [x] Implement the minimal normalized store models/builder.
- [x] Re-run targeted tests and verify GREEN.

### Task 2: Real application management controller
**Files:**
- Create: `Packages/PrismCore/Sources/PrismUIBridge/ApplicationManagementController.swift`
- Create: `Packages/PrismCore/Tests/PrismCoreTests/ApplicationManagementControllerTests.swift`

**Interfaces:**
- Consumes: `PrivilegedSessionManager`, `queryApplicationState`, `submitTransaction`, `ApplicationStateSnapshot`.
- Produces: typed `snapshot`, `register`, `refresh`, `remove` operations and normalized `PrismAppRow` mapping.

- [x] Write tests proving actual application-state mapping and typed transaction submission for register/refresh/remove.
- [x] Run targeted tests and verify RED because controller is absent.
- [x] Implement the controller using only existing typed privileged protocol operations.
- [x] Re-run targeted tests and verify GREEN.

### Task 3: Complete Store AppContainer state
**Files:**
- Modify: `App/AppContainer.swift`
- Test: `Scripts/VerifyCompleteStore.command` (static contract added in Task 5).

**Interfaces:**
- Consumes: store builder/query and application controller.
- Produces: store query state, filtered packages, featured data, selected filters, runtime app refresh/actions, activity buckets.

- [x] Add store state derived from the normalized builder without changing package transaction semantics.
- [x] Add runtime application refresh/register/repair/remove methods with global-log reporting.
- [x] Keep simulation actions but expose them only for Advanced/Lab UI.

### Task 4: Split and complete Store UI
**Files:**
- Modify: `App/Navigation/PrismRootView.swift`
- Create: `App/Store/StoreSharedViews.swift`
- Create: `App/Store/FeaturedView.swift`
- Create: `App/Store/PackagesView.swift`
- Create: `App/Store/SourcesView.swift`
- Create: `App/Store/AppsView.swift`
- Create: `App/Store/ActivityView.swift`
- Create: `App/Store/SettingsView.swift`
- Modify: `Prism.xcodeproj/project.pbxproj`

**Interfaces:**
- Root view owns navigation only.
- Store pages consume `AppContainer` and normalized PrismUIBridge models.

- [x] Move existing page implementations into Store files while preserving behavior.
- [x] Add Featured recommendations/categories/update/activity summaries.
- [x] Add package filters/sort/detail metadata/commerce/install-update-remove actions.
- [x] Add source detail status/search/refresh/remove confirmation.
- [x] Make Apps runtime-first with real register/repair/remove and capability-gated IPA import messaging; place simulation under Advanced/Lab.
- [x] Add Activity status buckets and recovery-oriented copy.
- [x] Add unique Xcode PBX references/build-file IDs for every new Swift file.

### Task 5: Localization, release gate and Build 52 version
**Files:**
- Modify: `App/en.lproj/Localizable.strings`
- Modify: `App/zh-Hans.lproj/Localizable.strings`
- Create: `Scripts/VerifyCompleteStore.command`
- Modify: `Scripts/VerifyPrismCoreFreeze.command`
- Modify: `Scripts/VerifyXcodeProject.command`
- Modify: `Prism.xcodeproj/project.pbxproj`
- Modify: `README.md`

**Interfaces:**
- Produces: Architecture Gate 5.0 for complete store and version 52 contract.

- [x] Add static gate assertions for all Build 52 product requirements.
- [x] Verify the gate fails against missing/version-old state before final wiring.
- [x] Set CURRENT_PROJECT_VERSION to 52 and update release docs/gates.
- [x] Run Complete Store gate and existing Core Freeze gate.

### Task 6: RELAXIN-X consolidated upgrade specification
**Files:**
- Create: `docs/RELAXIN-X-Full-Upgrade-Spec-Prism-Store-Runtime.md`
- Copy deliverable to `/mnt/data/RELAXIN-X-Full-Upgrade-Spec-Prism-Store-Runtime.md`.

**Interfaces:**
- Consolidates Build 49 Future Wiring, Build 50 Application Runtime Wiring, Build 51 Runtime Service Bridge, TrollStore architecture mapping, TrollFools-style compatibility, Package/Repository/Commerce/Store contracts and runtime host requirements.

- [x] Write one implementation-grade specification with module map, interfaces, capability IDs, handshake/service contracts, compatibility matrix, migration order, test matrix and Definition of Done.
- [x] Explicitly keep exploit/signing-bypass/arbitrary privileged primitives inside the runtime implementation boundary and out of Prism-facing APIs.

### Task 7: Fresh verification and clean delivery
**Files:** no production changes.

- [x] Delete `Packages/PrismCore/.build`.
- [x] Run `swift test` from a clean build.
- [x] Run `./Scripts/VerifyPrismCoreFreeze.command`.
- [x] Confirm Xcode project structural gates; do not claim Apple SDK build success where xcodebuild is unavailable.
- [x] Create clean Build 52 ZIP excluding `.build`, `dist`, `DerivedData`, `.git`.
- [x] Validate ZIP contents and SHA-256.