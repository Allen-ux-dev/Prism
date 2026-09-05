# Prism

[English](README.en.md) | [简体中文](README.zh-CN.md)

**A modern iOS package manager and runtime frontend for jailbreak and advanced system environments.**

Prism uses a provider-driven architecture. The core owns package models, repository abstractions, dependency resolution, plans, transactions, journals, reconciliation, recovery, and presentation. Repository formats and runtime services are supplied through providers.

**Current release:** `0.4.1`  
**License:** `Apache-2.0`

> Prism organizes capabilities exposed by an already-authorized runtime. It does not itself acquire jailbreak or system privileges, and its public service boundary does not expose arbitrary shell, kernel primitives, or unrestricted process-control interfaces.

## Why Prism

### No mandatory basebin dependency in Modern mode

When a Modern Runtime provides native services, Prism Core does not require `basebin`, APT, dpkg, `prismd`, `/var/jb`, or a fixed bootstrap layout as mandatory dependencies.

Traditional components remain available through compatibility providers when a source, package, or environment actually needs the Debian/APT ecosystem.

### Provider-driven instead of product-driven

Runtime, repository, package, and application services are selected through capabilities and providers instead of hard-coded jailbreak product names or filesystem assumptions.

### Modern-first, legacy-compatible

Native Runtime services can remain the primary path while Debian/APT repositories and common Sileo/Zebra metadata conventions remain supported through compatibility providers.

### Transaction-safe writes

Package and application writes use:

```text
Plan
→ Transaction
→ Journal
→ Execute
→ Inspect Actual State
→ Reconcile
→ Commit / Recovery / Needs Review
```

This gives Prism a consistent recovery boundary and prevents an active write transaction from silently migrating to another provider.

### Runtime-independent package core

The package model, resolver, transaction system, recovery model, and presentation layer do not depend on one specific Runtime implementation.

### Built-in diagnostics and reconnect handling

Runtime/helper health, provider state, transaction history, recovery state, global logs, and reconnect flows are part of the product rather than separate ad-hoc tools.

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

### Runtime Service Bridge

Prism supports a typed, versioned Runtime Service Bridge for already-authorized runtimes. The bridge can expose runtime descriptors, capabilities, package services, application services, artifact staging, background runtime services, health, reconnect state, and typed compatibility services.

`prismd` remains available as a compatibility service for environments that use a traditional daemon/package-service model. Modern environments can provide runtime-native services without making `basebin`, `prismd`, APT, dpkg, or a fixed bootstrap layout mandatory.

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

Prism includes runtime-backed application models and typed application transactions for application discovery, registration / refresh, repair, removal, runtime-managed installation requests, artifact staging capability checks, application-state verification, and transaction/recovery integration.

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

Runtime-native providers supply repository, package, and application services directly. `basebin`, APT, dpkg, `prismd`, `/var/jb`, and a traditional bootstrap are not mandatory Prism Core dependencies.

### Hybrid

A Modern Runtime remains primary while Debian/APT compatibility is activated only when required.

### Legacy

Traditional bootstrap environments can use `prismd`, APT/dpkg, and related components through compatibility providers.

## Building

Prism is a native Swift/SwiftUI project with a Swift Package based core.

```bash
./Build.command
```

## Documentation

- [`docs/USAGE.en.md`](docs/USAGE.en.md) — usage guide
- [`docs/FEATURES.en.md`](docs/FEATURES.en.md) — complete feature reference
- [`docs/RUNTIME-INTEGRATION.en.md`](docs/RUNTIME-INTEGRATION.en.md) — Runtime/provider integration overview

Every public guide also includes a link to its Simplified Chinese counterpart.

## License

Copyright © 2026 Allen-ux-dev.

Licensed under the **Apache License, Version 2.0**. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
