# Runtime Integration

Prism separates package-management logic from runtime-specific privileged execution.

Prism 将软件包管理逻辑与 Runtime 侧的高权限执行分离。Prism Core 负责模型、解析、事务、安全恢复与界面；Runtime Provider 负责在已经获得授权的环境中提供具体能力。

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

## Runtime Descriptor

A runtime integration can describe:

- runtime identity
- runtime version
- platform architecture
- OS version
- compatibility level
- available/degraded/unavailable capabilities
- service protocol range
- storage/package namespaces when applicable

Prism does not require a runtime to expose internal implementation details to the UI.

## Capability Registry

Capabilities are open identifiers rather than product-name checks.

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

Unknown future capabilities can be ignored safely by older Prism clients.

## Package Service

A package service may provide typed operations such as:

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

The exact backend can be runtime-native or a compatibility provider.

## Application Service

The application service can expose typed application operations such as:

- inspect application state
- register / refresh
- repair
- remove
- submit runtime-managed installation requests
- verify final application state

Application operations use the same transaction and recovery model as package operations.

## Artifact Staging

Artifact staging is a separate capability.

Prism can present an installation entry only when the connected runtime advertises the required staging/application capabilities. The runtime owns the privileged handling of the staged artifact.

## Background Runtime Service

Background operation is capability-gated.

Prism can request or release a background runtime session only when the connected runtime advertises the required background and privileged-service capabilities.

## Health & Reconnect

Runtime connectivity is not treated as a permanent one-time connection.

Prism tracks:

- connection state
- service health
- negotiated capabilities
- runtime identity
- reconnect state
- provider availability
- background-service state

When a connection is lost, Prism can surface the failure, preserve active transaction ownership, and reconnect without silently moving an active write operation to a different provider.

## Provider Selection

Provider selection considers:

- runtime compatibility
- required capabilities
- package/repository format requirements
- provider health
- service protocol compatibility
- transaction ownership

Once a write transaction begins, the selected provider is pinned for that transaction.

## Modern / Hybrid / Legacy

### Modern

The runtime supplies native repository/package/application services.

### Hybrid

The runtime remains primary, with legacy Debian/APT compatibility activated only for workloads that need it.

### Legacy

A traditional environment can use `prismd` and APT/dpkg compatibility providers.

## `prismd`

`prismd` is a compatibility service, not a mandatory Prism Core dependency.

It can provide a typed package-service boundary for environments that use a traditional daemon/bootstrap model.

## Repository Providers

Repository providers normalize source-specific metadata into Prism domain objects.

Current compatibility includes Debian/APT layouts and common Sileo/Zebra metadata patterns.

## Transaction Boundary

Runtime execution does not bypass Prism's transaction model.

```text
Plan
→ Transaction
→ Journal
→ Runtime/Provider Execute
→ Inspect Actual State
→ Reconcile
→ Commit / Recovery / Needs Review
```

## Security Boundary

Prism does not request generic privileged execution.

The public runtime boundary is designed around typed, allowlisted operations. Arbitrary shell, kernel primitives and unrestricted process-control interfaces are intentionally outside the Prism-facing API.

## Diagnostics

Advanced diagnostics may expose provider identifiers, protocol compatibility, capability state, connection health and recovery status. Implementation-sensitive paths should be redacted before display or export.
