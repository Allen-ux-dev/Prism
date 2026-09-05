# Prism Features

This document describes Prism's current public feature set. It intentionally focuses on implemented capabilities rather than internal development chronology.

本文档描述 Prism 当前公开功能，只关注已经实现的能力，不记录内部开发阶段或迭代过程。

## Package & Repository

- Provider-neutral package domain
- Debian/APT repository compatibility
- Sileo-compatible metadata normalization
- Zebra-compatible APT repository layouts
- `Packages` and `Packages.gz`
- Package/repository icons
- Package search and filtering
- Category/source/install-state filters
- Deterministic sorting
- Package technical details
- Architecture and hash metadata
- Dependencies
- Alternative dependencies
- Conflicts
- Last-known-good repository snapshots
- Repository status, health, trust and compatibility
- Source refresh, search and removal

## Package Operations

- Install plans
- Update plans
- Remove plans
- Purge plans
- Dependency resolution
- Conflict detection
- Installed-state inspection
- Provider selection
- Provider pinning during active transactions
- Real-state verification after execution
- Compatibility execution through APT/dpkg where supported by the environment

## Transaction Safety

All package and application writes use a shared transaction model.

```text
Plan
→ Transaction
→ Journal
→ Execute
→ Inspect Actual State
→ Reconcile
→ Commit / Recovery / Needs Review
```

Implemented recovery behavior includes:

- interruption tracking
- reconcile
- rollback when the provider supports it
- safe abort when the provider supports it
- needs-review state
- provider identity/version journaling
- no silent provider migration for an active write transaction
- completed-operation replay prevention

## Store UI

### Featured

- recommendation surfaces
- category entry points
- installed/update/source counts
- recent activity

### Packages

- package browsing
- search
- filters
- sorting
- package details
- dependency/conflict presentation
- install/update/remove actions

### Sources

- source list
- status
- trust/compatibility state
- refresh
- source-local search
- removal

### Apps

- runtime-backed application list
- application details
- registration / refresh
- repair
- removal
- runtime-managed installation entry
- artifact staging capability checks

### Activity

Transactions are grouped into:

- Pending
- Running
- Needs Review / Recovery
- Failed
- Completed

## Runtime & Provider System

Prism uses a provider registry/resolver model instead of a single hard-coded runtime backend.

Supported concepts include:

- runtime descriptors
- capability identifiers
- repository providers
- package-service providers
- application-service providers
- provider health
- provider compatibility
- provider diagnostics
- provider lifecycle
- reconnect-aware provider recomposition

## Runtime Service Bridge

The typed Runtime Service Bridge can connect Prism to an already-authorized runtime service and expose:

- runtime descriptor
- capability registry
- package service
- application service
- artifact staging service
- background runtime service
- health state
- reconnect state
- optional typed compatibility services

## Runtime Connectivity

Prism includes connection management for runtime/helper services:

- startup initialization
- continuous state observation
- health reporting
- reconnect handling
- manual reconnect
- background-service capability checks
- diagnostics
- global logging

## Compatibility Modes

### Modern

Runtime-native services are primary. Traditional bootstrap/APT assumptions are optional.

### Hybrid

Modern runtime services remain primary while Debian/APT compatibility can be activated when required.

### Legacy

Traditional environments can use `prismd` and APT/dpkg compatibility providers.

## Application Domain

Implemented application-side domain and service concepts include:

- installed application model
- application inspection state
- installation planning
- registration/refresh
- repair
- removal
- runtime-managed artifact staging
- application transaction operations
- application-state verification
- journal/reconcile/recovery integration

## Commerce

Prism includes repository-owned commerce and entitlement contracts:

- repository-controlled account/payment flow
- normalized entitlement state
- no raw payment-card credential storage in Prism
- owned-package installation through the normal transaction pipeline

## Diagnostics

- runtime bridge status
- provider status
- capability state
- transaction history
- recovery state
- global logs
- redaction-oriented diagnostics for sensitive implementation paths

## Localization

- English
- Simplified Chinese / 简体中文

## Security Model

Prism does not acquire jailbreak/system privileges by itself.

Public privileged boundaries are typed and allowlisted rather than arbitrary command interfaces. Runtime-specific privileged implementation details remain inside the runtime/provider boundary.
