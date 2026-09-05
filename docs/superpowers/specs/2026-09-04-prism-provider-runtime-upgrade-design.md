# Prism 0.4.0 Provider Runtime Upgrade Design

**Status:** Implemented in Prism 0.4.0 Provider Runtime Upgrade (Build 40)  
**Product:** Prism / RELAXIN-X Package Platform  
**Target version:** Prism 0.4.0 Provider Runtime Upgrade (Build 40)  
**Date:** 2026-09-04  
**Baseline:** Prism 0.3.0 Future-Ready (Build 30), commit `d27a489`, branch `feature/prism-v1`  
**Previous spec:** `docs/superpowers/specs/2026-09-04-prism-future-ready-package-platform-design.md`

## 1. Purpose

Prism 0.3.0 already removed the biggest global legacy assumptions: PackageVersion is scheme-driven, package formats are open identifiers, RepositoryProvider is abstracted, Environment can be modern without bootstrap/rootPrefix, PackageServiceProtocol exists, prismd is a provider instead of the Core, and Modern/Hybrid/Legacy modes exist.

Prism 0.4.0 is therefore not a rewrite. It is a **gap-driven runtime-provider upgrade** whose purpose is to make the provider model dynamic enough to serve as the stable first-party package platform for RELAXIN-X.

The governing principles remain:

- **Modern-first** — RELAXIN-X runtime/provider is preferred whenever healthy and compatible.
- **Legacy-compatible** — prismd/APT/dpkg remain available as compatibility providers.
- **Provider-driven** — runtime, repository, package service and compatibility evolution happens by registering providers, not by editing UI/Core switches.
- **Transaction-safe** — all writes remain Plan → Transaction → Journal → Reconcile/Recovery.
- **Quiet-by-default** — runtime/package components remain idle unless required; ordinary UI does not expose implementation details.
- **No silent fallback for writes** — provider selection is pinned for a transaction and recovery never replays a write through a different provider.

---

## 2. Baseline Gap Analysis

The following are already present and must be retained rather than reimplemented:

```text
PackageVersion + VersionScheme                    ✓
PackageFormatIdentifier                           ✓
RepositoryProvider 2.0                            ✓
PrismEnvironment 2.0                              ✓
CapabilityStatus four-state model                 ✓
ProviderRegistry                                  ✓
PackageServiceProtocol                            ✓
PrismDaemonProvider                               ✓
RelaxinRuntimeProvider                            ✓
Modern / Hybrid / Legacy modes                    ✓
Transaction / Journal / Reconcile                 ✓
Provider-aware recovery metadata                  ✓
Runtime isolation / quiet mode                    ✓
Mock TrollStore-style / TrollFools-style flows    ✓
```

Current code still has six important gaps:

1. `ProviderRegistry` mainly selects from registration-time descriptors; it is not yet a live health/capability registry.
2. `RelaxinRuntimeProvider` has a transport abstraction but no formal bridge handshake/descriptor contract suitable for long-term RELAXIN-X protocol evolution.
3. `PackageServiceProtocol` allows write-capable providers whose recovery methods can remain unsupported defaults; safe recovery is not validated before selection.
4. Mock providers exercise success paths but are not yet a systematic fault-injection platform for interrupted/degraded/rollback scenarios.
5. `PackageServiceBootstrap.compatibilityFallback(...)` still directly constructs `PrismDaemonProvider`, leaking a legacy fallback decision into application bootstrap.
6. UI is provider-aware at a high level, but diagnostics and status propagation do not yet model dynamic provider health changes as first-class observable state.

---

## 3. Target Architecture

```text
Prism UI
   │
   ▼
Application Layer
   │
   ▼
ProviderRegistry 2.0
   ├── Runtime/Service Providers
   ├── Repository Providers
   └── App/Injection Providers
   │
   ├──────── PackageServiceSession ────────┐
   │                                       │
   │                              Service Provider
   │                          ┌────────────┼────────────┐
   │                          ▼            ▼            ▼
   │                   RELAXIN-X       prismd        Mock
   │                     Modern        Legacy      Validation
   │                          │
   │                    Relaxin Bridge
   │                          │
   │                RELAXIN-X Package Runtime
   │
   └──────── Repository Provider API ──────┐
                                            │
                                Relaxin / Prism / APT

Transaction Core
   ├── Plan
   ├── Transaction
   ├── Journal
   ├── Reconcile
   ├── Rollback
   └── SafeAbort
```

Application code chooses **capabilities + health + mode**. It does not construct a concrete daemon/provider directly.

---

## 4. ProviderRegistry 2.0

### 4.1 Responsibilities

`ProviderRegistry` becomes a live runtime registry, not just a registration table.

Required operations:

```text
register(provider)
unregister(providerID)
refreshHealth(providerID?)
resolveCapabilities(providerID)
select(kind, mode, requirements)
observeChanges()
diagnosticsSnapshot()
```

### 4.2 Dynamic descriptor

Provider descriptor must distinguish stable identity from live state:

```text
ProviderIdentity
├── providerID
├── providerKind
├── providerVersion
└── protocolVersion

ProviderRuntimeState
├── health
├── capabilityReport
├── supportedFormats
├── supportedVersionSchemes
├── recoveryStrategies
├── lastHealthChange
└── diagnosticSummary
```

`health` must support at least:

```text
healthy
degraded(reason)
unavailable(reason)
unknown
```

### 4.3 Selection rules

Provider selection is deterministic.

Modern mode:

```text
RELAXIN-X modern provider
→ other explicitly modern providers
→ fail visibly
```

Hybrid mode:

```text
RELAXIN-X modern provider preferred
→ compatibility provider allowed when request requires legacy capability/format
```

Legacy mode:

```text
PrismDaemonProvider / legacy provider
```

A write transaction pins the selected provider ID/version at plan confirmation time.

A provider health change after confirmation may cause:

```text
continue safely
pause/interrupted
reconcile
rollback
safe abort
```

but never silent provider replacement.

---

## 5. RELAXIN-X Bridge Contract

### 5.1 Goal

Prism must talk to RELAXIN-X through a stable protocol contract instead of knowing internal runtime components.

### 5.2 Handshake

```text
Prism
↓
RelaxinBridgeHandshake
↓
Protocol Negotiation
↓
Runtime Descriptor
↓
Package Service Descriptor
↓
Capability Negotiation
↓
PackageServiceSession
```

### 5.3 RuntimeDescriptor

```text
RuntimeDescriptor
├── runtimeIdentity
├── runtimeVersion
├── architecture
├── socFamily
├── osVersion
├── osBuild
├── environmentState
├── compatibilityLayers
└── runtimeCapabilities
```

No field requires a bootstrap, root prefix, basebin path or package database.

### 5.4 PackageServiceDescriptor

```text
PackageServiceDescriptor
├── serviceIdentity
├── serviceVersion
├── protocolVersion
├── capabilityReport
├── supportedPackageFormats
├── supportedVersionSchemes
├── recoveryStrategies
└── sessionBehavior
```

`sessionBehavior` can describe persistent/ephemeral sessions without exposing an implementation-specific socket path to Prism UI.

### 5.5 Compatibility rules

A bridge protocol mismatch must surface as a structured Provider health state:

```text
unavailable("Unsupported bridge protocol")
```

It must not silently fall back to Legacy for a write already planned for the modern provider.

---

## 6. Recovery Contract Enforcement

### 6.1 Required recovery strategy

Every provider capable of mutating package/app/runtime state must advertise at least one safe recovery strategy:

```text
reconcile
rollback
safeAbort
```

A read-only provider may advertise none.

### 6.2 Registry validation

If a provider advertises write capabilities such as:

```text
packageInstall
packageRemove
packageUpgrade
appInstall
appInjection
```

and advertises no recovery strategy, ProviderRegistry marks it unavailable for write selection:

```text
unavailable("Write provider has no safe recovery strategy")
```

### 6.3 Transaction pinning

Journal records must include:

```text
providerID
providerVersion
providerProtocolVersion
selectedRecoveryStrategy
providerRecoveryToken?
```

Recovery order:

```text
inspect actual state
→ use original provider if available
→ reconcile / rollback / safeAbort according to recorded contract
→ NeedsReview if safe continuation cannot be proven
```

---

## 7. Modern Mock Fault-Injection Platform

The mock provider becomes a reusable validation environment for RELAXIN-X integration.

Required fault modes:

```text
normal
failBeforeExecution
failAfterOperation(index)
interruptAfterOperation(index)
degradedBeforeExecution
degradedDuringExecution
rollbackSucceeds
rollbackFails
safeAbortSucceeds
safeAbortFails
reconcileAlreadyApplied
reconcilePartiallyApplied
```

Each fault mode must be deterministic and test-controlled.

Required test flows:

```text
Plan → Transaction → success
Plan → Transaction → failure → rollback
Plan → Transaction → interruption → reconnect → reconcile
Plan → Transaction → provider degraded → pause/recovery
Plan → Transaction → safeAbort
```

The same fault harness should be reusable by Mock TrollStore-style and Mock TrollFools-style providers so App/Injection transactions receive the same recovery guarantees.

---

## 8. Bootstrap and Service Session Refactor

### 8.1 Remove direct legacy construction from application bootstrap

The application layer must stop doing this conceptually:

```text
compatibilityFallback()
→ create PrismDaemonProvider directly
```

New flow:

```text
App Launch
↓
Environment / Mode
↓
ProviderRegistry
↓
Selection Requirements
↓
PackageServiceSessionFactory
↓
Selected Provider Session
```

### 8.2 PackageServiceSession

Introduce an application-facing session wrapper:

```text
PackageServiceSession
├── providerIdentity
├── runtimeState
├── service
├── refreshProviderState()
├── reconnectIfSupported()
└── diagnosticsSnapshot()
```

UI talks to a session/facade, not a daemon/socket or concrete RELAXIN-X transport.

---

## 9. Repository/Service Coordination

Repository and execution providers remain independently replaceable, but selection must understand compatibility.

Example Hybrid request:

```text
.deb package from APTRepositoryProvider
↓
requires org.debian.deb + legacyDebCompatibility
↓
ProviderRegistry selects a service supporting those requirements
```

Modern native request:

```text
dev.relaxin.package
↓
RelaxinModernRepositoryProvider
↓
RelaxinRuntimeProvider
```

Application code must not contain a special-case switch for `.deb` or RELAXIN-X package IDs.

---

## 10. Runtime Isolation and Daily Experience

This section concerns **low-interference runtime design**, not evasion of third-party security checks.

### 10.1 Quiet default

Normal device use:

```text
Core Runtime              minimal required state
Package Service           idle/on-demand
Legacy Compatibility      off unless needed
Build Service             off unless needed
Injection Service         off unless needed
Diagnostics               passive
```

### 10.2 Lazy activation

Opening Prism or confirming a transaction activates only the providers required by that operation.

When work completes and there are no pending transactions, compatible providers return to idle according to their declared lifecycle policy.

### 10.3 Failure containment

A degraded repository, app injection provider or legacy compatibility provider must not make unrelated package browsing unusable.

A provider failure should degrade the smallest possible capability surface.

### 10.4 No implementation-detail leakage in normal UI

Normal Settings must not show:

```text
/var/jb
apt/dpkg paths
package database paths
basebin paths
socket paths
launch/service implementation names
```

Advanced Diagnostics may show provider IDs, versions and sanitized legacy metadata needed for debugging.

---

## 11. UI Design and Layout Contract

### 11.1 iPhone navigation

Keep exactly five primary tabs:

```text
Featured
Packages
Sources
Apps
Activity
```

`Installed` and `Updates` remain under Packages. Queue/history remain under Activity. Settings remains a toolbar/navigation destination.

No sixth primary tab may be added for Providers or Runtime.

### 11.2 Provider-aware status

Normal Settings uses task-level language:

```text
Runtime             RELAXIN-X / Compatibility / Unknown
Package Service     Ready / Degraded / Offline
Compatibility       Modern / Hybrid / Legacy
Background          Idle / Active / Recovering
```

When degraded, show a concise reason and affected operation types.

### 11.3 Advanced Diagnostics

May show:

```text
Provider ID
Provider Version
Protocol Version
Health State
Supported Formats
Capability Report
Recovery Strategies
Last Health Change
Last Transaction
Sanitized legacy details
```

### 11.4 Layout constraints

UI verification must cover:

- compact iPhone width;
- regular iPhone width;
- iPad/sidebar layout;
- Dynamic Type at accessibility sizes;
- long degraded/unavailable reason text;
- offline / unknown provider state;
- no hard-coded content width for reusable cards;
- no horizontal overflow in settings/provider diagnostics;
- capability rows wrap instead of clipping;
- toolbar controls remain tappable when titles wrap.

Featured metric cards must remain adaptive rather than a fixed horizontal row.

---

## 12. Mock TrollStore-Style and TrollFools-Style Simulation

The existing safe simulation architecture remains non-destructive.

### 12.1 Mock TrollStore-style

Must simulate:

```text
IPA inspection
→ AppInstallPlan
→ Transaction
→ Mock installed app state
→ Journal
→ Reconcile / rollback / safeAbort fault modes
```

### 12.2 Mock TrollFools-style

Must simulate:

```text
Select mock installed app
→ select dylib/framework/bundle artifact
→ InjectionPlan
→ Transaction
→ Mock injection state
→ Journal
→ Reconcile / rollback / safeAbort fault modes
```

Simulation must be clearly labeled in UI and must never modify a real application bundle.

---

## 13. Error Model

Add/standardize structured errors:

```text
ProviderRegistryError
├── noCompatibleProvider
├── providerUnavailable
├── providerDegradedForRequest
├── missingRecoveryStrategy
└── protocolMismatch

BridgeError
├── handshakeFailed
├── unsupportedProtocol
├── invalidDescriptor
└── sessionUnavailable

RecoveryError
├── originalProviderUnavailable
├── recoveryStrategyUnavailable
├── rollbackFailed
├── safeAbortFailed
└── reconcileInconclusive
```

UI maps them to user actions:

```text
Retry
Reconnect
Use Compatibility Mode (before planning only)
Review Transaction
Open Diagnostics
```

No user-facing error should instruct users to manually run apt/dpkg commands.

---

## 14. Testing Strategy

### 14.1 TDD requirements

Every production behavior change follows RED → GREEN → REFACTOR.

### 14.2 Core tests

Required additions:

- live ProviderRegistry health refresh;
- provider selection changes for future plans after health changes;
- provider pinning for confirmed transactions;
- no provider swap during recovery;
- write provider without recovery strategy is rejected;
- RELAXIN-X bridge handshake/protocol mismatch;
- repository/service format compatibility selection;
- mock fault injection for interruption/rollback/safeAbort;
- PackageServiceSession reconnect/health refresh;
- legacy bootstrap construction no longer exists in App bootstrap.

### 14.3 UI presentation tests

Required additions:

- five-tab contract remains fixed;
- Modern/Hybrid/Legacy presentation;
- healthy/degraded/unavailable/unknown provider presentation;
- long reason text uses wrap-safe presentation data;
- Advanced Diagnostics receives provider identity/protocol/recovery data;
- normal settings does not receive raw legacy path fields.

### 14.4 Architecture gates

Static checks must fail if ordinary App/UI code contains:

```text
/var/jb
apt-get
dpkg-query
prismd.sock
runShell
runAnyCommand
executeArbitraryCommand
```

The daemon/legacy provider may own legacy paths/tools behind its typed implementation boundary.

### 14.5 Build gates

Linux/container gate:

```text
swift test
swift build --product prismd
architecture/static UI gates
AppIcon checks
Xcode project structure checks
```

macOS/Xcode gate:

```text
xcodebuild -project Prism.xcodeproj -scheme Prism -sdk iphonesimulator build
```

A release cannot be called Apple-SDK-verified until the Xcode build runs successfully on macOS.

---

## 15. Migration Phases

### Phase 1 — Registry Runtime State

- separate Provider identity from runtime health/capabilities;
- add dynamic refresh and snapshots;
- keep existing selection behavior passing.

### Phase 2 — Recovery Contract

- add RecoveryStrategy descriptor;
- reject unsafe write providers;
- pin provider/recovery contract into Journal.

### Phase 3 — RELAXIN-X Bridge

- add bridge handshake DTOs;
- add protocol negotiation;
- migrate RelaxinRuntimeProvider to the formal bridge contract.

### Phase 4 — Service Session and Bootstrap

- add PackageServiceSession;
- remove direct `compatibilityFallback()` construction from UI bridge startup;
- select through ProviderRegistry.

### Phase 5 — Fault Injection and Simulation

- expand Modern Mock provider;
- route Mock TrollStore/TrollFools transactions through the same fault/recovery harness.

### Phase 6 — UI/Diagnostics and Release Gates

- dynamic provider status in Settings;
- Advanced Diagnostics provider details;
- compact/iPad/Dynamic Type checks;
- final architecture and build gates;
- version 0.4.0 Build 40 packaging.

---

## 16. Architecture Contract Additions

The following rules are added to the existing Prism contract:

1. App bootstrap must not construct a concrete package service provider directly.
2. ProviderRegistry is the only normal selection authority for package service providers.
3. Provider identity and provider runtime health are separate concepts.
4. Provider health/capabilities may change without restarting Prism.
5. A confirmed write transaction pins provider identity/version/protocol.
6. Recovery never silently changes the provider used for a write.
7. Every write-capable provider must advertise at least one safe recovery strategy.
8. RELAXIN-X integration occurs through a versioned bridge contract, not internal runtime implementation details.
9. Repository/provider compatibility is resolved by identifiers/capabilities, not App-layer format switches.
10. Normal UI never exposes implementation paths or daemon/socket details.
11. Mock app/injection flows remain non-destructive but must exercise the real Prism transaction/recovery architecture.
12. A provider failure degrades only the capabilities it owns whenever technically possible.

---

## 17. Definition of Done

Prism 0.4.0 Provider Runtime Upgrade is complete when all of the following are true:

1. ProviderRegistry can refresh provider health/capabilities at runtime.
2. A future plan may select a different provider after health changes, while an already-confirmed transaction remains pinned to its original provider.
3. Write-capable providers without reconcile/rollback/safeAbort are rejected before execution.
4. RelaxinRuntimeProvider uses the formal bridge handshake/descriptor contract.
5. App startup obtains PackageService through ProviderRegistry/PackageServiceSession instead of constructing PrismDaemonProvider directly.
6. Mock provider can deterministically simulate success, failure, interruption, rollback and safeAbort.
7. Mock TrollStore-style and TrollFools-style workflows use the same recovery/fault infrastructure.
8. Modern/Hybrid/Legacy UI states react to live provider health.
9. Advanced Diagnostics shows provider protocol/version/recovery data without exposing raw legacy implementation details in normal Settings.
10. iPhone remains at five primary tabs and UI gates detect overflow-prone/fixed-width regressions.
11. Full Swift tests pass.
12. `prismd` builds successfully in the available Swift environment.
13. Static architecture/UI/AppIcon/Xcode-structure gates pass.
14. On macOS, the final iOS Simulator `xcodebuild` passes before claiming Apple-SDK verification.

---

## 18. Out of Scope

This upgrade does not:

- implement a new kernel exploit or privilege escalation path;
- attempt to hide runtime state from third-party security/anti-cheat detection;
- make Prism UI execute arbitrary shell commands;
- hard-code private implementation details of a future RELAXIN-X runtime;
- replace already-working Debian/APT compatibility logic unless required by the provider boundary;
- convert the safe TrollStore/TrollFools simulations into destructive real-app modification paths in this phase.
