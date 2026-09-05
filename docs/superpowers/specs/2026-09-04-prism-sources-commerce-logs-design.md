# Prism Sources 2.0 / Commerce / Global Log Design

## Goal
Complete the remaining Prism 0.4.1 UX/platform work without changing the five-tab phone navigation or weakening transaction/runtime safety.

## Scope
1. Sources 2.0: source detail, source-local search, remove-source confirmation, and package navigation scoped to the selected repository.
2. Package visuals: use package `Icon` metadata everywhere a package is presented and preserve cached/fallback image behavior.
3. App management terminology: use architecture-neutral Application Installation, Application Injection, and Simulation Environment language. No TrollStore/TrollFools/White-Troll branding in user-facing UI.
4. Global log: one in-memory bounded log store for UI/runtime/source/package/simulation/commerce events, viewable from Activity and Diagnostics, copyable as plain text, with no secrets/tokens persisted.
5. Commerce contracts: source-owned account/purchase systems behind Prism `PurchaseProvider` and `EntitlementProvider` adapters. Prism stores only normalized product/entitlement state and never card data.
6. Paid package UI: Free/Paid/Owned/Sign-in-required/Unavailable states. Purchase action is only enabled when a source commerce provider is available. After entitlement becomes owned, installation goes through the existing InstallPlan/Transaction pipeline.
7. Existing Package Removal 2.0 remains unchanged.

## Boundaries
- No real payment processor is embedded in Prism 0.4.1. The default provider is a safe in-memory/demo adapter for conformance and UI state; third-party repositories implement adapters later.
- No bypass of App Store, signing, jailbreak, or runtime protections. Real app install/injection actions remain capability-gated.
- Global logs must redact obvious credential/token fields and remain bounded to avoid unbounded memory growth.
- Phone root navigation remains Featured / Packages / Sources / Apps / Activity exactly.
