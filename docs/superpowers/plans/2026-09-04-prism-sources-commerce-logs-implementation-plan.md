# Prism Sources / Commerce / Global Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Build 48 with Sources 2.0, repository-scoped search, package visuals everywhere, architecture-neutral app-management copy, bounded global logging, and source-owned paid-package contracts.

**Architecture:** Keep PrismCore provider-driven. Repository detail/search and commerce normalization live in PrismUIBridge/PrismDomain; AppContainer coordinates user actions and global logs; SwiftUI only renders normalized states. Payments remain source-owned adapters, while all installation/removal continues through existing transaction planning/execution.

**Tech Stack:** Swift 6, SwiftUI/UIKit, Swift Package Manager, Xcode project resources, existing PrismCore modules.

**Spec:** `docs/superpowers/specs/2026-09-04-prism-sources-commerce-logs-design.md`

## Global Constraints
- Phone navigation remains exactly five root tabs.
- iOS deployment target remains 15.0.
- No card/payment credentials stored by Prism.
- App install/injection remains capability-gated.
- No user-facing TrollStore/TrollFools/White-Troll naming.

---

### Task 1: Sources 2.0 repository scoping
**Files:** modify `PrismUIBridge/Presentation.swift`, `RepositoryCatalogClient.swift`, `App/AppContainer.swift`, `App/Navigation/PrismRootView.swift`; test `RepositoryVisualPresentationTests.swift` plus a new `RepositoryScopeTests.swift`.
- [ ] Add failing tests for repository identifier on package rows and filtering packages by repository.
- [ ] Run tests and confirm RED.
- [ ] Add normalized repository identity/source URL to `PrismPackageRow` and repository-scoped filtering helper.
- [ ] Run focused tests GREEN.
- [ ] Add source-detail UI with local search and destructive remove confirmation.

### Task 2: Package icons across all package surfaces
**Files:** modify `PrismRootView.swift`; add static UI gate `Scripts/VerifyPackageVisualCoverage.command`.
- [ ] Add failing gate requiring `PrismRemoteIcon` in global package list, source detail list, package detail, and featured package cards.
- [ ] Run gate RED if any surface is missing.
- [ ] Reuse the existing cached remote icon component on every package surface.
- [ ] Run gate GREEN.

### Task 3: Architecture-neutral app management copy
**Files:** modify `PrismRootView.swift`, localization files; add `Scripts/VerifyModernAppManagementCopy.command`.
- [ ] Add failing gate forbidding user-facing `White-Troll`, `TrollFools`, and `TrollStore` strings in App/Localization.
- [ ] Run gate RED.
- [ ] Rename UI to Application Installation / Application Injection / Simulation Environment and clarify capability-gated real actions.
- [ ] Run gate GREEN.

### Task 4: Bounded global log
**Files:** create `Packages/PrismCore/Sources/PrismUIBridge/GlobalLog.swift`, tests `GlobalLogTests.swift`; modify AppContainer, PrismRootView.
- [ ] Add failing tests for bounded retention, level/category filtering, text export, and redaction of token/password-like metadata.
- [ ] Run tests RED.
- [ ] Implement `PrismLogEntry`, `PrismLogStore`, `PrismLogLevel`, `PrismLogCategory`.
- [ ] Run tests GREEN.
- [ ] Wire source/package/install/remove/simulation/reconnect events into AppContainer.
- [ ] Add Activity log section and diagnostics log viewer/export text.

### Task 5: Commerce contracts and normalized entitlement state
**Files:** create `PrismDomain/CommerceModels.swift`, `PrismUIBridge/CommerceProvider.swift`; tests `CommerceProviderTests.swift`.
- [ ] Add failing tests for free/paid/owned/sign-in-required/unavailable states and provider-owned purchase flow.
- [ ] Run RED.
- [ ] Implement normalized product/entitlement models and source-owned provider protocols plus in-memory conformance provider.
- [ ] Run GREEN.

### Task 6: Paid package presentation and install handoff
**Files:** modify `Presentation.swift`, `RepositoryCatalogClient.swift`, AppContainer, PrismRootView, localizations.
- [ ] Add failing tests that parse `Price`, `Currency`, `Paid`, and source commerce metadata into presentation rows.
- [ ] Run RED.
- [ ] Add `PrismCommercePresentation` to `PrismPackageRow`; display price/ownership in rows/detail.
- [ ] Add sign-in/purchase action that updates entitlement only; owned packages continue through existing `preparePackageInstall`.
- [ ] Run focused tests GREEN.

### Task 7: Build 48 gates and release verification
**Files:** modify Xcode build number, README, `VerifyPrismCoreFreeze.command`, Build.command expectations; add all new gates.
- [ ] Set build number 48 and update release notes/checks.
- [ ] Run complete `Scripts/VerifyPrismCoreFreeze.command`.
- [ ] Verify no PBX duplicate IDs and no old user-facing architecture names.
- [ ] Package clean source ZIP excluding `.build`, `dist`, `.git`, and DerivedData.
