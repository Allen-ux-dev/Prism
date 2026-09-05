# Prism Future-Ready Package Platform Design

**Status:** Approved and implemented in Prism 0.3.0 Future-Ready (Build 30)  
**Product:** Prism / RELAXIN-X Package Platform  
**Date:** 2026-09-04  
**Baseline:** Prism 0.2.0 V1, branch `feature/prism-v1`

## 1. Goal

Upgrade Prism from a package manager centered on traditional jailbreak assumptions into the first-party package platform for the next-generation RELAXIN-X modular runtime.

The governing principles are:

- **Modern-first** — RELAXIN-X modern runtime is the primary path.
- **Legacy-compatible** — APT, dpkg, DEB, Sileo/Zebra repositories, legacy bootstrap and `prismd` remain supported through compatibility providers.
- **Provider-driven** — new runtimes, repositories, version schemes, package formats, app installers and injection implementations are added through providers instead of Core edits.
- **Transaction-safe** — every write operation uses Plan → Transaction → Journal → Reconcile/Recovery.
- **Quiet-by-default** — runtime components stay idle unless required and implementation details remain out of normal UI.

Prism should become:

> **RELAXIN-X Package Platform**

rather than another Sileo/Zebra-style frontend.

---

## 2. Baseline Problems to Remove

Prism V1 intentionally proved a working package-management transaction chain, but several public Core types still encode legacy assumptions:

- `PrismPackage.version` is globally `DebianVersion`.
- `PackageDistribution` is a fixed enum (`deb`, `source`, `native`).
- `RepositoryProvider` accepts APT-shaped `metadata + packagesIndex + baseURL`.
- `PrismEnvironment` requires `rootStyle`, `rootPrefix` and other bootstrap-oriented fields.
- `EnvironmentCapability` is binary presence/absence instead of availability state.
- `prismd` and privileged IPC are currently the central service path.
- package execution ultimately assumes the `PackageExecutionBackend` model.
- the UI exposes legacy environment labels such as root style in ordinary Settings.

These are valid Legacy Provider details but must not remain global Prism assumptions.

---

## 3. Target Architecture

```text
Prism UI
   │
   ▼
Application Layer
   │
   ▼
Prism Domain
   ├── Package
   ├── PackageVersion / VersionScheme
   ├── PackageFormatIdentifier
   ├── Repository Abstractions
   ├── Resolver
   ├── Plans
   ├── Transaction
   ├── Journal
   └── Reconcile / Recovery
   │
   ├──────────── Repository Provider API ─────────────┐
   │                                                  │
   │                                    ProviderRegistry
   │                                                  │
   │          ┌─────────────────┬─────────────────────┘
   │          ▼                 ▼
   │     APT Legacy        Prism/Relaxin Modern
   │     Repository         Repository Providers
   │
   └──────────── PackageServiceProtocol ──────────────┐
                                                      │
                                               ServiceProvider
                                                      │
                                  ┌───────────────────┴──────────────────┐
                                  ▼                                      ▼
                       PrismDaemonProvider                    RelaxinRuntimeProvider
                           Legacy/Hybrid                           Modern/default
                                  │                                      │
                               prismd                         RELAXIN-X Package Service
                                  │
                              apt / dpkg
```

Prism Core owns semantics and state. Providers own implementation details.

Prism Core must not contain knowledge of:

- kernel backend implementation;
- concrete system hooks;
- concrete bootstrap layout;
- APT/dpkg command paths;
- a mandatory `.deb` format;
- a mandatory `/var/jb` root;
- a mandatory `prismd` daemon.

---

## 4. Package Version Abstraction

### 4.1 New core types

`DebianVersion` remains implemented but stops being Prism's global version type.

```text
PackageVersion
├── rawValue
└── schemeIdentifier

VersionScheme
├── identifier
├── normalize(version)
├── compare(a, b)
└── satisfies(version, constraint)
```

Initial schemes:

```text
org.debian.version
org.semver.version
org.prism.native-version
```

Implementations:

- `DebianVersionScheme`
- `SemanticVersionScheme`
- `NativeVersionScheme`

### 4.2 Registry

`VersionSchemeRegistry` resolves a scheme by identifier.

Package comparison always uses the package's declared scheme. Unsupported schemes produce an explicit compatibility state instead of falling back to lexical comparison.

### 4.3 Migration

Existing V1 DEB packages migrate from:

```swift
version: DebianVersion
```

to a `PackageVersion` with scheme `org.debian.version`.

The existing Debian comparison implementation is retained inside `DebianVersionScheme`; it is not rewritten needlessly.

---

## 5. Open Package Format Identifiers

Replace fixed `PackageDistribution` as the extension point.

```text
PackageFormatIdentifier(rawValue: String)
```

Initial identifiers:

```text
org.debian.deb
dev.prism.source
dev.prism.native
dev.relaxin.package
```

Providers register supported formats.

Adding a future RELAXIN-X format must require:

1. registering a provider/format handler;
2. optionally adding presentation metadata;
3. no modification to a Core enum or switch exhaustive over all formats.

The Domain may provide well-known constants for convenience, but the underlying type remains open/string-backed.

---

## 6. Repository Provider 2.0

### 6.1 Core interface

The Core repository API must stop taking APT-shaped inputs.

```text
RepositoryProvider
├── identity
├── supportedSchemes / sourceKinds
├── refresh(context)
├── catalog(repositoryID)
├── package(id, repositoryID)
├── metadata(repositoryID)
└── health(repositoryID)
```

A provider returns normalized Prism domain snapshots.

### 6.2 Implementations

```text
APTRepositoryProvider
PrismNativeRepositoryProvider
RelaxinModernRepositoryProvider
```

`APTRepositoryProvider` alone owns knowledge of:

- `Release`
- `Packages`
- `Packages.gz`
- compressed APT indexes
- Debian control paragraphs
- Sileo extension metadata
- source-list synchronization

Prism Core never branches on these filenames.

### 6.3 Last-known-good behavior

Repository refresh stays snapshot based:

```text
fetch → validate → normalize → build candidate snapshot → atomic replace
```

A failed refresh keeps the previous healthy snapshot.

`health()` reports provider-specific details normalized to Prism health states.

---

## 7. PrismEnvironment 2.0

A valid modern environment must not require a bootstrap or root prefix.

```text
PrismEnvironment
├── runtimeIdentity
├── runtimeVersion
├── architecture
├── osVersion
├── osBuild
├── capabilities
├── storageNamespace?
├── packageStore?
├── compatibilityLayers
└── legacy?
    ├── bootstrapIdentity?
    ├── rootStyle?
    ├── rootPrefix?
    ├── packageDatabase?
    └── toolPaths?
```

### Core invariants

- missing `/var/jb` does not make an environment invalid;
- missing dpkg database does not make an environment invalid;
- missing bootstrap identity does not make an environment invalid;
- legacy filesystem/tool details stay under the optional `legacy` namespace;
- normal application services depend on capabilities and service providers, not legacy fields.

The existing Rootless/Rootful providers become Legacy/Compatibility Environment Providers rather than the global environment model.

---

## 8. Capability Contract 2.0

Capability is no longer only a `Set` membership check.

```text
CapabilityStatus
├── available
├── unavailable
├── degraded(reason)
└── unknown(reason?)
```

Core package-service capabilities:

```text
packageInstall
packageRemove
packageUpgrade
dependencyResolution
repositoryRefresh
transactionRollback
transactionReconcile
safeAbort
serviceRestart
userspaceRestart
runtimeHookSupport
legacyDebCompatibility
sourceBuild
appInstall
appRegistration
appInjection
```

Providers publish a capability report.

UI rules:

- `available` → normal action;
- `degraded` → action may be offered with an explicit warning when safe;
- `unavailable` → disabled with reason;
- `unknown` → no destructive action until resolved.

Prism must not ask routine business logic questions such as:

```text
Is this Dopamine?
Is this Relaxin?
Does /var/jb exist?
```

Instead it asks whether the required capability is available.

---

## 9. Provider Registry

Introduce a single `ProviderRegistry` for discovery and selection.

Responsibilities:

```text
register(provider)
unregister(identifier)
providers(kind)
select(kind, environment, requirements)
health()
```

Provider kinds include:

```text
repository
packageService
environment
versionScheme
packageFormat
appInstallation
appInjection
```

### Selection order

Selection is deterministic:

1. explicit user/provider override for diagnostics/testing;
2. healthy Modern provider matching the environment;
3. healthy Hybrid-compatible provider;
4. Legacy provider when compatibility is enabled;
5. unavailable result with diagnostics.

No silent fallback from a failed Modern transaction to a Legacy write operation. Fallback is decided **before** execution during planning/provider selection.

### Provider metadata

Every provider exposes:

- stable identifier;
- provider kind;
- version;
- priority;
- supported requirements/formats;
- health;
- capability report;
- human-readable diagnostics metadata.

---

## 10. PackageServiceProtocol

All package state mutation goes through one abstract service contract.

```text
PackageServiceProtocol
├── inspectState()
├── queryCapabilities()
├── resolve(request)
├── prepare(plan)
├── execute(operation)
├── reconcile(transaction)
├── rollback(transaction)
└── safeAbort(transaction)
```

Exact implementation methods may be split into focused protocols in Swift, but Application/Core code consumes the abstract package service rather than `prismd`.

### Required rule

A concrete provider must support at least one safe recovery mechanism:

- reconcile;
- rollback;
- safe abort.

Providers declare which are available.

### Prohibited Core calls

Outside provider implementation boundaries, Prism may not invoke or encode direct assumptions about:

- `apt`
- `apt-get`
- `dpkg`
- `dpkg-query`
- `launchctl`
- `jbctl`
- `/basebin/*`

Static architecture gates enforce this.

---

## 11. prismd Becomes a Legacy/Hybrid Service Provider

Current V1:

```text
Prism → privileged transport → prismd → backend
```

Future architecture:

```text
Prism → PackageServiceProtocol → ServiceProvider
```

Providers:

```text
RelaxinRuntimeProvider       Modern/default
PrismDaemonProvider          Hybrid/Legacy
MockPackageServiceProvider   development/tests
```

### Legacy path

```text
Prism
→ PrismDaemonProvider
→ typed IPC
→ prismd
→ typed Legacy Package Backend
→ apt/dpkg
```

### Modern path

```text
Prism
→ RelaxinRuntimeProvider
→ RELAXIN-X Package Service
```

Modern runtime can therefore operate with no independent `prismd` process.

`prismd` remains maintained for compatibility and migration but must never become a new mandatory basebin.

---

## 12. Modern / Hybrid / Legacy Operating Modes

### Modern — default and recommended

```text
RELAXIN-X Modern Runtime
+ RelaxinRuntimeProvider
+ Modern Repository/Format Providers
+ Prism
```

No traditional bootstrap requirement.

### Hybrid — migration

```text
RELAXIN-X Modern Runtime
+ Modern Package Service
+ Legacy DEB/APT compatibility providers when needed
+ Prism
```

Legacy compatibility activates lazily.

### Legacy — compatibility only

```text
Legacy Runtime / bootstrap
+ PrismDaemonProvider
+ apt/dpkg
+ Prism
```

UI labels Legacy as compatibility mode, not the recommended setup.

---

## 13. Transaction Engine 2.0

The existing V1 Transaction/Journal/Reconcile model is preserved and strengthened rather than replaced.

Recommended phases:

```text
Created
→ Preparing
→ Resolving
→ Ready
→ Executing
→ Reconciling
→ Completed
```

Exceptional/recovery phases:

```text
Failed
Interrupted
NeedsRecovery
RollingBack
RolledBack
NeedsReview
Cancelled
```

### Rules

1. every write action produces a Plan before Transaction creation;
2. UI never calls provider execution directly;
3. provider identity and version used by a transaction are journaled;
4. interruption always triggers actual-state inspection;
5. completed operations are never blindly replayed;
6. recovery may migrate to a compatible provider only through an explicit reconciliation decision, never silently mid-transaction;
7. provider-specific opaque recovery tokens may be journaled but remain opaque to Prism Core;
8. destructive rollback is only offered when the provider reports rollback capability;
9. when neither continuation nor rollback is safe, phase becomes `NeedsReview`.

---

## 14. Runtime Isolation & Daily Experience

This requirement exists to reduce normal-use interference, not to evade third-party security detection.

### 14.1 Quiet-by-default runtime

Normal daily state:

```text
Core Runtime                 minimal / necessary
Required System Hooks        only required hooks
Package Service              idle or on-demand
Legacy APT Layer             off
Source Build Service         off
Injection Service            off
Advanced Diagnostics         off
```

Services activate only when a requested operation needs them.

### 14.2 Lazy activation

Example package install:

```text
Open Prism
→ ProviderRegistry selects service
→ activate Package Service if required
→ Plan / Transaction
→ Reconcile
→ provider returns to idle when safe
```

Legacy compatibility does not stay active merely because it is installed.

### 14.3 Implementation-detail isolation

Normal UI and ordinary logs do not expose:

- `/var/jb`
- root prefixes
- dpkg database paths
- daemon socket paths
- concrete package tool paths
- bootstrap internals

These remain available only in Advanced Diagnostics when relevant.

### 14.4 Storage namespace

Modern providers use `storageNamespace` / provider-owned storage abstraction rather than assuming a global jailbreak root.

Legacy filesystem paths remain provider-private.

### 14.5 Failure containment

A failed provider/module must not invalidate unrelated Prism functionality.

Examples:

- APT compatibility unhealthy → Modern repositories still browse/install.
- Injection provider unavailable → Apps remain browseable and package management remains operational.
- build provider unhealthy → binary packages still work.

### 14.6 Low-interference user mode

Default mode is “Daily / Automatic” behavior:

- unnecessary services idle;
- compatibility providers activate only when selected;
- repeated health warnings are coalesced;
- non-actionable implementation messages stay out of normal UI;
- user attention is requested only for actions that require review or intervention.

Advanced users may open Environment Doctor for full provider diagnostics.

---

## 15. Application Installation and Injection Provider Model

Existing App/Injection Plan and Transaction abstractions remain, but their execution providers are formally registered through `ProviderRegistry`.

### 15.1 App installation providers

```text
AppInstallationProvider
├── RelaxinAppInstallationProvider      future modern
├── TrollStoreStyleProvider             compatibility implementation
├── MockTrollStoreLiteProvider          simulation/test
└── FutureProvider
```

### 15.2 Injection providers

```text
AppInjectionProvider
├── RelaxinInjectionProvider            future modern
├── TrollFoolsCompatibilityProvider     compatibility implementation
├── MockTrollFoolsProvider              simulation/test
└── FutureProvider
```

No provider exposes arbitrary command execution to UI or IPC.

---

## 16. Mock “White Troll” / TrollStore-Style Experience

The requested simulation is a complete Prism workflow without changing real system apps.

`MockTrollStoreLiteProvider` supports:

```text
Import IPA
→ Inspect metadata
→ AppInstallPlan
→ User review
→ Transaction
→ simulated installation
→ simulated registration
→ installed-app state
→ remove / reinstall
→ Journal / reconnect / Reconcile
```

It persists deterministic mock application state in Prism's test/development storage namespace so app relaunch and transaction recovery can be tested realistically.

It must cover:

- supported/unsupported architecture state;
- install capability status;
- registration capability status;
- duplicate/reinstall behavior;
- interrupted install recovery;
- remove flow;
- provider health diagnostics.

The production UI is the same UI used by future real providers; there is no special mock-only screen.

---

## 17. Mock TrollFools-Style Injection Experience

`MockTrollFoolsProvider` simulates the complete safe transaction model without modifying real application bundles.

Workflow:

```text
Installed App
→ choose dylib/framework/bundle artifact
→ compatibility inspection
→ InjectionPlan
→ review expected changes
→ Transaction
→ simulated apply/remove
→ injection state/history
→ Journal / reconnect / Reconcile
```

It must cover:

- target application selection;
- artifact identity/type;
- architecture compatibility;
- duplicate injection prevention;
- apply/remove;
- active injection list;
- interrupted operation recovery;
- provider health/capability state.

Simulation validates Prism's UX, provider routing, transaction safety and recovery model. It does not implement arbitrary real-app injection or privilege acquisition.

---

## 18. UI Information Architecture 2.0

The existing anti-clutter navigation decision remains.

### iPhone

Exactly five primary tabs:

```text
Featured
Packages
Sources
Apps
Activity
```

- Installed and Updates live inside Packages.
- Queue and transaction history live inside Activity.
- Settings remains a toolbar/sheet destination, not a sixth tab.

### iPad / regular width

Sidebar may expose:

```text
Featured
Packages
Sources
Apps
Installed
Updates
Activity
Settings
```

### Modern-first presentation

Featured/Settings show an abstract runtime status, not legacy implementation internals.

Normal Settings top-level presentation:

```text
Runtime              Healthy / Needs Attention
Package Service      Ready / Idle / Recovering
Mode                 Modern / Hybrid / Legacy
Compatibility        Available / Active / Off
Transactions         Healthy / Recovery Needed
```

Advanced Diagnostics contains:

- provider identifiers/versions;
- legacy root style and root prefix if applicable;
- daemon/socket state if the selected provider uses it;
- APT/dpkg tool state;
- repository provider details;
- recovery/journal details.

### Layout constraints

To prevent UI displacement/regression:

1. shared spacing/radius metrics live in one `PrismLayoutMetrics` definition;
2. rows never assume fixed English text width;
3. status value columns use adaptive trailing alignment, not hard-coded offsets;
4. phone views avoid horizontally packed multi-action controls that overflow at large Dynamic Type;
5. navigation ownership is singular — a feature view does not create nested root `NavigationView`s when hosted by a root navigation container;
6. sheets use predictable content sizing and do not duplicate Settings/navigation roots;
7. Empty, loading, degraded, offline and ready states are all explicitly rendered;
8. provider implementation details cannot change page hierarchy.

### Daily experience

Unavailable compatibility features do not create persistent red warning banners unless user action is required. A provider may be “Off” by design and still be healthy.

---

## 19. Application Layer Changes

`AppContainer` must stop directly constructing a fixed `PrismClientFacade(socketPath: ...)` as the global backend choice.

Target composition:

```text
PrismApplicationContext
├── ProviderRegistry
├── EnvironmentCoordinator
├── PackageServiceCoordinator
├── RepositoryCoordinator
├── TransactionCoordinator
├── AppManagementCoordinator
└── PresentationStore
```

The UI consumes presentation snapshots and sends intents.

Examples:

```text
install(packageID)
refresh(repositoryID)
importIPA(...)
prepareInjection(...)
reconnectSelectedProvider()
```

Coordinators resolve providers and produce Plans/Transactions.

---

## 20. Compatibility Migration Strategy

Migration is incremental; Prism 0.2.0 functionality must stay usable during refactoring.

### Stage A — open Domain types

- add `PackageVersion` + schemes;
- add `PackageFormatIdentifier`;
- adapt current DEB data without changing behavior.

### Stage B — provider registries

- add `ProviderRegistry`;
- move current Sileo/APT repository path behind `APTRepositoryProvider`;
- move current rootless/rootful discovery into compatibility environment providers.

### Stage C — package service abstraction

- define `PackageServiceProtocol`;
- wrap current IPC/prismd chain in `PrismDaemonProvider`;
- App no longer depends directly on Unix socket details.

### Stage D — RELAXIN-X modern provider

- introduce `RelaxinRuntimeProvider` contract and mock implementation first;
- make Modern mode the preferred selection path when capabilities are available.

### Stage E — runtime isolation

- lazy provider activation;
- normal/advanced diagnostic split;
- provider-specific storage namespaces;
- idle state and health reporting.

### Stage F — app/injection simulations

- implement `MockTrollStoreLiteProvider`;
- implement `MockTrollFoolsProvider`;
- run real UI through the simulated provider workflows.

### Stage G — cleanup

Only after all migrated tests pass:

- remove direct V1 assumptions from Application/Core;
- keep Legacy implementation in dedicated compatibility modules;
- retain migration decoding for existing persisted state where needed.

---

## 21. Error and Health Model

Introduce normalized provider health:

```text
ProviderHealth
├── healthy
├── idle
├── degraded(reason)
├── unavailable(reason)
└── failed(reason)
```

Distinguish “Off by design” from “Broken”.

Examples:

- Legacy APT provider off in Modern mode → `idle`, not error.
- Relaxin package service temporarily disconnected → `degraded` or `unavailable` depending recoverability.
- transaction journal corruption → transaction `NeedsReview`; provider health remains separate.

Normal UI uses concise messages; Advanced Diagnostics carries technical error context.

---

## 22. Build and Architecture Gates

The Future-Ready upgrade is not accepted based on Core unit tests alone.

Required gates:

### Core tests

- version-scheme behavior;
- provider selection;
- repository normalization;
- capability status semantics;
- package service routing;
- Modern/Hybrid/Legacy mode selection;
- transaction/recovery behavior;
- app installation mock recovery;
- injection mock recovery.

### Static architecture gates

Fail when non-provider Core/UI contains forbidden implementation assumptions:

```text
/var/jb
apt-get
dpkg-query
/basebin/
launchctl
jbctl
prismd.sock
```

Approved Legacy Provider files/test fixtures are explicitly allowlisted.

### Swift build gates

On every development environment:

```bash
swift build
swift test
```

### Xcode gate on macOS

```bash
xcodebuild -project Prism.xcodeproj -scheme Prism -sdk iphonesimulator build
```

The implementation cannot be declared compile-clean until this succeeds on a Mac with the configured Apple SDK.

### UI structure gate

Static test verifies:

- exactly five phone tabs;
- Installed/Updates not duplicated as phone root tabs;
- Settings not duplicated as phone root tab;
- no nested root navigation ownership regressions;
- no direct legacy backend calls from View/App code;
- minimum iOS API contract remains valid.

### Visual QA checklist on macOS/iOS simulator

At minimum verify:

- compact iPhone width;
- regular iPhone width;
- iPad regular width;
- English long labels;
- large Dynamic Type;
- offline/recovering/idle/degraded provider states;
- InstallPlan sheet;
- App install plan sheet;
- Injection plan sheet;
- Settings/Advanced Diagnostics transitions.

No fixed-offset layout workaround may be accepted for a general alignment issue.

---

## 23. Architecture Contract 2.0

The following rules are mandatory:

1. UI never executes package/runtime implementation operations directly.
2. Prism Domain does not depend on APT, dpkg, DEB, Sileo, `/var/jb`, a bootstrap, or `prismd`.
3. package versions are resolved by registered version schemes.
4. package formats use open identifiers, not a closed global enum.
5. APT file/index structures remain inside `APTRepositoryProvider`.
6. an environment without bootstrap/root prefix is valid.
7. capability status supports available/unavailable/degraded/unknown.
8. provider selection is deterministic and observable.
9. no mid-transaction silent provider fallback.
10. `PackageServiceProtocol` is the package execution entry point.
11. `prismd` is a provider implementation, never a mandatory Core dependency.
12. RELAXIN-X Modern Runtime may provide package service directly.
13. every write operation uses Plan → Transaction.
14. every interrupted transaction reconciles actual state before continuation.
15. completed operations are never blindly replayed.
16. providers declare rollback/reconcile/safe-abort support.
17. legacy compatibility can remain completely idle in Modern mode.
18. normal UI does not expose provider-specific filesystem/tool details.
19. implementation-detail isolation is for reliability/usability, not third-party detection evasion.
20. App installation and injection use provider contracts and the same transaction/recovery foundation.
21. mock TrollStore-style and TrollFools-style providers use production UI paths and persistent mock state.
22. arbitrary shell/command execution is never added to public provider/IPC APIs.
23. phone navigation remains five primary tabs unless a later design spec explicitly changes it.
24. UI layout must adapt to width and Dynamic Type without fixed-offset hacks.
25. a release is not compile-verified until both Swift gates and the macOS Xcode gate have passed.

---

## 24. Success Criteria

The upgrade is complete when all of the following are demonstrated:

1. a non-Debian `PackageVersion` can exist without Domain edits;
2. a new package-format identifier can register without Core enum modification;
3. APT repositories still work through `APTRepositoryProvider`;
4. a mock Modern repository works through the same UI;
5. a `PrismEnvironment` with no bootstrap/rootPrefix is accepted;
6. ProviderRegistry selects Modern, Hybrid and Legacy paths deterministically;
7. the existing `prismd` chain works entirely through `PrismDaemonProvider`;
8. a mock `RelaxinRuntimeProvider` completes package transactions without prismd;
9. interrupt/relaunch recovery works under both service-provider paths;
10. Modern mode leaves Legacy compatibility idle;
11. normal Settings contain no mandatory root/jailbreak path vocabulary;
12. Advanced Diagnostics still makes provider-specific information available when needed;
13. mock TrollStore-style install supports install/remove/reinstall and recovery through production UI;
14. mock TrollFools-style injection supports apply/remove/history and recovery through production UI;
15. App/Injection provider failures do not break package browsing or package management;
16. static gates find no legacy implementation leakage into Core/UI;
17. `swift build` passes;
18. `swift test` passes;
19. macOS `xcodebuild` iOS Simulator build passes;
20. UI QA finds no navigation duplication, clipping, obvious alignment drift or state-driven layout jumps in the required device/state matrix.

---

## 25. Non-Goals for This Upgrade

This architecture upgrade does not itself implement:

- new kernel exploits or privilege acquisition;
- generic shell execution;
- bypassing third-party jailbreak/security detection;
- arbitrary injection into real apps through a public Prism interface;
- a requirement to replace all existing RELAXIN-X runtime internals immediately.

The purpose is to make Prism ready for a modular modern runtime while preserving a controlled compatibility path.



---

## 25. Implementation Status

The Future-Ready migration is implemented on `feature/prism-v1` as Prism 0.3.0 (Build 30). The 0.2.0 V1 transaction/package-management chain remains available through compatibility providers.

Implemented migration contracts:

- open PackageVersion / VersionScheme and PackageFormatIdentifier;
- Repository Provider 2.0 and ProviderRegistry;
- optional legacy namespace in PrismEnvironment 2.0;
- four-state CapabilityStatus;
- PackageServiceProtocol with RelaxinRuntimeProvider and PrismDaemonProvider;
- provider-aware Transaction/Journal/Recovery;
- Modern/Hybrid/Legacy runtime modes and quiet/lazy isolation;
- modern-first UI presentation and Advanced Diagnostics redaction;
- non-destructive TrollStore-style and TrollFools-style simulation providers using the real Prism transaction model.

The migration intentionally does not implement detection evasion or privilege acquisition. Real system-changing providers remain constrained to already-authorized runtime environments and typed operations.
