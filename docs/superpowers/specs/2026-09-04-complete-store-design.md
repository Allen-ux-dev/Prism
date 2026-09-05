# Prism Build 52 — Complete Store Design

## Goal
Turn Prism Build 51 from a runtime/package-management shell into a complete store product layer without rewriting the frozen provider, transaction, journal, recovery, runtime bridge, package identity, or repository cores.

## Product Contract
- iPhone root navigation remains exactly five destinations: Featured / Packages / Sources / Apps / Activity.
- Settings remains presented from navigation chrome, never a sixth root tab.
- Modern First / Legacy On Demand / No Silent Write Fallback remain mandatory.
- Runtime-native providers outrank compatibility providers; active transactions remain provider-pinned.
- Simulation stays available only as an Advanced/Lab tool and is never presented as real device capability.
- All real application actions remain typed runtime operations; Prism does not embed privilege acquisition, exploit, signing-bypass, arbitrary shell, arbitrary PID injection, or unrestricted raw privileged filesystem APIs.
- Store UI consumes normalized presentation models, not APT/Sileo/Zebra/RELAXIN-X-specific repository implementation details.
- iOS 15 remains the deployment floor and English / Simplified Chinese remain first-class.

## Store Domain
Add a normalized store presentation layer in PrismUIBridge:
- PrismStoreCategory
- PrismPackageFilter
- PrismPackageSort
- PrismPackageDetailPresentation
- PrismSourceDetailPresentation
- PrismStoreOverview
- PrismActivityBucket
- PrismActivityItem
- PrismStoreQuery
- PrismStorePresentationBuilder

The builder derives browse/search/filter/sort/category/detail/featured/update/activity state from existing PrismPackageRow, PrismSourceRow, PrismTransactionRow, commerce metadata, and environment presentation.

## Featured
Featured is a real dashboard with:
- runtime/service health
- update count
- installed count
- source count
- recommended/latest package rows derived from normalized catalog metadata
- category shortcuts
- recent operation/activity summary
No hardcoded repository implementation or product-name branching.

## Packages
Packages supports:
- full-text search
- category filter
- source filter
- installation-state filter
- commerce-state filter
- sort by name / newest metadata / installed / updates
- package detail showing identity, author, version, architecture, source, distribution/trust metadata, dependencies, conflicts, requirements, commerce state and action availability
- install/update plan review and remove/purge review continue to use existing PackageService/Transaction paths

## Sources
Sources supports:
- source list with icon/name/package count
- source detail with provider-neutral status, trust, compatibility, last refresh, commerce provider and package list
- source-local search
- refresh
- removal confirmation
- add-source validation before mutation

## Apps
Apps becomes real-runtime-first:
- current runtime bridge status/provider identity/capability summary
- installed application list from privileged `queryApplicationState`
- typed Register / Refresh-Repair / Remove actions submitted as PrismTransaction
- typed app transaction result refreshes actual application state
- IPA import entry is capability-gated and explicitly reports that artifact staging requires the runtime service host when unavailable
- injection capability is shown only when runtime reports it
- Simulation Environment moves under an Advanced/Lab section

Build 52 does not add exploit/signing-bypass logic. Real IPA staging/execution is fulfilled by the RELAXIN-X Runtime Service Host described by the companion upgrade specification.

## Activity
Activity is bucketed into:
- Pending
- Running
- Completed
- Failed
- Needs Review / Recovery
Each transaction has normalized status/progress/recovery messaging. Global Log remains separately searchable/filterable.

## Commerce
Continue the Build 48 repository-owned commerce contract:
- Free
- Paid
- Owned
- Sign In Required
- Unavailable
Prism never stores card/CVV data. Owned/authorized packages still enter normal InstallPlan/Transaction/Journal/Reconcile.

## App Structure
Keep PrismRootView as root routing/chrome, but move store page implementations into `App/Store/` files:
- StoreSharedViews.swift
- FeaturedView.swift
- PackagesView.swift
- SourcesView.swift
- AppsView.swift
- ActivityView.swift
- SettingsView.swift
The Xcode project explicitly includes these files and preserves unique PBX object IDs.

## Verification
- SwiftPM store-domain TDD tests.
- Static Complete Store gate verifies the five-tab contract, split store files, real-runtime-first Apps copy, Simulation under Lab/Advanced, package filters/categories/detail, source detail, activity buckets, localization keys, and Build 52 version.
- Existing Core Freeze gates remain mandatory.
