# Prism

[English](README.en.md) | [简体中文](README.zh-CN.md)

**A modern iOS package manager and runtime frontend for jailbreak and advanced system environments.**

Prism uses a provider-driven architecture. The core owns package models, repository abstractions, dependency resolution, plans, transactions, journals, reconciliation, recovery, and presentation. Repository formats and runtime services are supplied through providers.

**Current release:** `0.4.1`  
**License:** `Apache-2.0`

> Prism organizes capabilities exposed by an already-authorized runtime. It does not itself acquire jailbreak or system privileges, and its public service boundary does not expose arbitrary shell, kernel primitives, or unrestricted process-control interfaces.

## Core Principles

- **Modern-first** — RELAXIN-X Modern Runtime is the primary integration path.
- **Legacy-compatible** — Debian/APT/Sileo/Zebra/DEB and traditional bootstrap environments remain available through compatibility providers.
- **Provider-driven** — runtimes, repositories, package services, and application services are replaceable providers instead of hard-coded product branches.
- **Transaction-safe** — write operations follow Plan → Transaction → Journal → Execute → Reconcile/Recovery.
- **Capability-based** — Prism uses runtime capabilities instead of product-name checks or fixed filesystem assumptions.
- **Quiet-by-default** — compatibility services stay idle until a task actually requires them.

## Implemented Features

### Store Experience

Prism provides five primary iPhone destinations:

- **Featured** — recommendations, categories, installed/update/source counts, and recent activity.
- **Packages** — browsing, search, category/source/install-state/commerce filters, sorting, and package details.
- **Sources** — repository status, trust, compatibility, refresh, source-local search, and removal.
- **Apps** — runtime-backed application state, registration, repair, removal, and runtime-managed installation entry points.
- **Activity** — pending, running, recovery-needed, failed, and completed transactions.

### Repository Compatibility

Implemented repository support includes:

- Debian/APT repository metadata
- Sileo-compatible repository fields
- Zebra-compatible APT repository layouts
- `Packages` and `Packages.gz`
- package and repository icons
- multi-line descriptions
- architecture metadata
- hashes and technical package metadata
- dependencies, alternative dependencies, and conflicts
- last-known-good catalog snapshots
- provider health and compatibility status

Legacy repository metadata is normalized into Prism domain models before it reaches the UI.

### Package Management

Prism implements:

- package discovery and search
- package details and technical metadata
- dependency resolution
- conflict detection
- install and update planning
- remove and purge planning
- installed-state inspection
- transaction-backed install/update/remove flows
- real package-state verification after execution
- repository-aware package selection
- provider pinning during active write transactions

In compatible legacy environments, package execution can use the existing APT/dpkg toolchain through a compatibility provider while keeping those implementation details out of the UI.

### Transaction, Journal, and Recovery

Every write operation follows the same safety pipeline:

```text
Plan
  ↓
Transaction
  ↓
Journal
  ↓
Provider / Runtime execution
  ↓
Actual-state inspection
  ↓
Reconcile
  ↓
Commit / Recovery / Needs Review
```

Recovery capabilities include:

- reconcile
- rollback when supported
- safe abort when supported
- interrupted transaction recovery
- needs-review state
- actual-state inspection before recovery
- prevention of silent provider switching during an active transaction

### Runtime Service Bridge

Prism supports a typed, versioned Runtime Service Bridge for already-authorized runtimes.

The bridge can expose:

- runtime descriptor
- capability registry
- package service
- application service
- artifact staging service
- background runtime service
- health and reconnect state
- optional typed compatibility services

`prismd` remains available as a compatibility service for environments that use a traditional daemon/package-service model. Modern environments can provide runtime-native services without making `prismd`, APT, dpkg, or a fixed bootstrap layout mandatory.

### Runtime Connectivity

Prism includes managed runtime/helper connectivity:

- startup initialization
- connection-state monitoring
- runtime health reporting
- reconnect handling
- explicit manual reconnect
- background-service capability checks
- diagnostics and global logging
- provider recomposition after reconnect when appropriate

### Application Management

Prism includes runtime-backed application models and typed application transactions for:

- application discovery
- registration / refresh
- repair
- removal
- runtime-managed installation requests
- artifact staging capability checks
- application-state verification
- transaction and recovery integration

### Commerce Contracts

- repositories own account/payment flows
- Prism consumes normalized entitlement results
- Prism does not store raw payment-card credentials
- owned packages still install through the standard transaction pipeline

### Diagnostics and Logging

- provider status
- runtime bridge status
- capability status
- transaction history
- recovery state
- global logs
- redaction-oriented diagnostics for implementation-sensitive paths

### Localization

- English
- Simplified Chinese

## Architecture

```text
Prism Store UI
      │
      ▼
Presentation / Coordinator
      │
      ▼
Prism Core
 ├─ Package Domain
 ├─ Repository Abstraction
 ├─ Dependency Resolver
 ├─ Plan / Transaction / Journal
 ├─ Reconcile / Recovery
 ├─ Commerce Contracts
 └─ Runtime Service Bridge
      │
      ▼
Provider Registry / Resolver
 ├─ Modern Runtime Providers
 ├─ Repository Providers
 ├─ Package Service Providers
 └─ Compatibility Providers
      │
      ▼
Authorized Runtime Environment
```

> **The runtime provides capabilities. Prism organizes capabilities.**

## Runtime Modes

### Modern

A runtime-native provider supplies repository, package, and application services directly. Traditional APT/bootstrap components are not mandatory.

### Hybrid

A modern runtime is primary, while legacy Debian/APT compatibility is activated only when required.

### Legacy

Traditional bootstrap environments can use `prismd` plus APT/dpkg compatibility providers.

## Project Structure

```text
App/                         Native iOS SwiftUI application
Packages/PrismCore/          Core Swift package
Scripts/                     Verification and architecture gates
docs/FEATURES.md             Detailed feature reference
docs/RUNTIME-INTEGRATION.md  Runtime/provider integration overview
Prism.xcodeproj/             Xcode project
Build.command                macOS build entry
```

## Building

Prism is a native Swift/SwiftUI project with a Swift Package based core.

```bash
./Build.command
```

## Documentation

- [`docs/FEATURES.md`](docs/FEATURES.md) — complete feature reference
- [`docs/RUNTIME-INTEGRATION.md`](docs/RUNTIME-INTEGRATION.md) — runtime/provider integration overview

## License

Copyright © 2026 Allen-ux-dev.

Licensed under the **Apache License, Version 2.0**. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
