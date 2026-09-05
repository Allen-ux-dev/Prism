# Prism Features

[English](FEATURES.en.md) | [简体中文](FEATURES.zh-CN.md)

This document describes Prism's current public capabilities. It focuses on what Prism implements today rather than internal development history.

## Why Prism

Prism is designed so the package-manager core is not tied to one jailbreak layout or one legacy toolchain.

### No mandatory basebin dependency in Modern mode

In a Modern runtime environment, Prism does **not** require `basebin`, APT, dpkg, `prismd`, `/var/jb`, or a fixed bootstrap layout as mandatory Core dependencies. A runtime can expose native package, repository, and application services through typed providers.

Legacy environments remain supported: when Debian/APT compatibility is actually needed, Prism can use compatibility providers backed by the traditional toolchain.

### Provider-driven instead of product-driven

Prism selects capabilities through providers and runtime descriptors instead of hard-coding behavior around a specific jailbreak product name or filesystem path.

### Safer write model

Package and application writes follow a shared safety pipeline:

```text
Plan
→ Transaction
→ Journal
→ Execute
→ Inspect Actual State
→ Reconcile
→ Commit / Recovery / Needs Review
```

This makes interrupted operations recoverable and prevents an active transaction from silently switching to a different provider.

### Modern-first, legacy-compatible

Prism can use runtime-native services first while still preserving compatibility with Debian/APT repositories and common Sileo/Zebra metadata conventions.

## Package & Repository

- Provider-neutral package domain
- Debian/APT repository compatibility
- Sileo-compatible metadata normalization
- Zebra-compatible APT repository layouts
- `Packages` and `Packages.gz`
- Package and repository icons
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
- Source refresh, source-local search and removal

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
- APT/dpkg compatibility execution when supported by the selected environment

## Store UI

Prism provides five primary iPhone destinations:

- **Featured** — recommendations, categories, installed/update/source counts and recent activity
- **Packages** — browsing, search, filters, sorting, technical details and package actions
- **Sources** — source status, trust, compatibility, refresh, search and removal
- **Apps** — runtime-backed app state, registration, repair, removal and runtime-managed install entry points
- **Activity** — Pending, Running, Needs Review / Recovery, Failed and Completed transactions

## Runtime & Provider System

Prism uses a provider registry/resolver model instead of one hard-coded backend.

Supported concepts include:

- runtime descriptors
- open capability identifiers
- repository providers
- package-service providers
- application-service providers
- provider health
- compatibility state
- diagnostics
- lifecycle and reconnect-aware provider recomposition

## Runtime Service Bridge

The typed Runtime Service Bridge can connect Prism to an already-authorized runtime service and expose:

- runtime descriptor
- capability registry
- package service
- application service
- artifact staging service
- background runtime service
- health and reconnect state
- optional typed compatibility services

## Runtime Connectivity

- startup initialization
- continuous connection-state observation
- health reporting
- reconnect handling
- manual reconnect
- background-service capability checks
- diagnostics
- global logging

## Compatibility Modes

### Modern

Runtime-native services are primary. Traditional basebin/bootstrap/APT assumptions are optional rather than mandatory Core requirements.

### Hybrid

Modern runtime services remain primary while Debian/APT compatibility can be activated for workloads that need it.

### Legacy

Traditional environments can use `prismd`, APT/dpkg and related bootstrap components through compatibility providers.

## Application Management

- installed application model
- application inspection state
- registration / refresh
- repair
- removal
- runtime-managed installation entry points
- artifact staging capability checks
- application transaction operations
- application-state verification
- journal / reconcile / recovery integration

## Commerce

Prism includes repository-owned commerce and entitlement contracts:

- repository-controlled account/payment flow
- normalized entitlement state
- no raw payment-card credential storage in Prism
- owned-package installation through the standard transaction pipeline

## Diagnostics

- runtime bridge status
- provider status
- capability state
- transaction history
- recovery state
- global logs
- redaction-oriented diagnostics for implementation-sensitive paths

## Localization

- English
- Simplified Chinese / 简体中文

## Security Model

Prism does not acquire jailbreak or system privileges by itself. Public privileged boundaries are typed and allowlisted rather than generic arbitrary-command interfaces.
