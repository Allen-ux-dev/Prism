# Prism Runtime Integration

[English](RUNTIME-INTEGRATION.en.md) | [简体中文](RUNTIME-INTEGRATION.zh-CN.md)

Prism separates package-management logic from runtime-specific privileged execution. Prism Core owns models, resolution, transactions, recovery and presentation; an authorized Runtime Provider supplies concrete execution capabilities.

## Integration Model

```text
Prism UI
   ↓
Prism Core
   ↓
Provider Registry / Resolver
   ↓
Runtime Service Bridge
   ↓
Authorized Runtime Provider
```

The public integration contract is capability-based and versioned.

## A key design advantage: no mandatory basebin dependency

In **Modern** mode, Prism Core does not require `basebin`, APT, dpkg, `prismd`, `/var/jb`, or a fixed bootstrap directory in order to be a valid Prism environment.

A runtime can provide native repository, package, application and artifact services directly through typed providers.

Traditional components remain available through compatibility providers when the selected environment or workload actually needs them. This keeps legacy ecosystem compatibility without making legacy layout assumptions part of Prism Core.

## Runtime Descriptor

A runtime integration can describe:

- runtime identity
- runtime version
- platform architecture
- OS version
- compatibility level
- available / degraded / unavailable capabilities
- service protocol range
- optional storage/package namespaces

## Capability Registry

Capabilities use open identifiers instead of product-name checks.

Typical capability families include:

- package query
- package write
- repository sync
- application query
- application management
- artifact staging
- background execution
- privileged service
- health reporting
- reconcile
- rollback
- safe abort

Unknown optional future capabilities can be ignored safely by older Prism clients.

## Package Service

A package service can expose typed operations such as:

```text
activate
deactivate
queryEnvironment
queryCapabilities
inspectPackageState
resolve
prepare
execute
reconcile
rollback
safeAbort
syncRepositorySources
```

The backend may be runtime-native or a compatibility provider.

## Application Service

Typed application operations can include:

- inspect application state
- register / refresh
- repair
- remove
- submit runtime-managed installation requests
- verify final application state

Application operations use the same transaction and recovery model as package operations.

## Artifact Staging

Artifact staging is a separate capability. Prism presents runtime-managed installation entry points only when the connected runtime advertises the required staging/application capabilities.

## Background Runtime Service

Background operation is capability-gated. Prism requests a background session only when the connected runtime advertises the required background and privileged-service capabilities.

## Health & Reconnect

Prism tracks:

- connection state
- service health
- negotiated capabilities
- runtime identity
- reconnect state
- provider availability
- background-service state

A lost connection does not authorize Prism to silently move an active write transaction to another provider.

## Provider Selection

Provider selection considers:

- runtime compatibility
- required capabilities
- package/repository format requirements
- provider health
- service protocol compatibility
- transaction ownership

Once a write transaction begins, the selected provider is pinned for that transaction.

## Runtime Modes

### Modern

Runtime-native services are primary. `basebin`, APT, dpkg, `prismd`, `/var/jb`, and a traditional bootstrap are not mandatory Prism Core dependencies.

### Hybrid

Modern runtime services remain primary while Debian/APT compatibility is activated only for tasks that need it.

### Legacy

Traditional environments can use `prismd`, APT/dpkg and related bootstrap components through compatibility providers.

## `prismd`

`prismd` is a compatibility service rather than a mandatory Prism Core dependency. It provides a typed package-service boundary for environments that use a traditional daemon/bootstrap model.

## Repository Providers

Repository providers normalize source-specific metadata into Prism domain objects. Current compatibility includes Debian/APT layouts and common Sileo/Zebra metadata patterns.

## Transaction Boundary

```text
Plan
→ Transaction
→ Journal
→ Runtime / Provider Execute
→ Inspect Actual State
→ Reconcile
→ Commit / Recovery / Needs Review
```

Runtime execution does not bypass this model.

## Security Boundary

Prism does not request generic privileged execution. The public runtime boundary is built around typed, allowlisted operations; arbitrary shell, kernel primitives and unrestricted process-control interfaces remain outside the Prism-facing API.

## Diagnostics

Advanced diagnostics can expose provider identifiers, protocol compatibility, capability state, connection health and recovery status. Implementation-sensitive paths should be redacted before display or export.
