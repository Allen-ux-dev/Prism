# Prism

**A modern iOS package manager and runtime frontend for jailbreak and advanced system environments.**  
**一个面向越狱与高级系统环境的现代 iOS 软件包管理器与 Runtime 前端。**

Prism is designed around a provider-driven architecture. The core owns package models, repository abstractions, dependency resolution, plans, transactions, journals, reconciliation, recovery, and presentation. Actual repository formats and runtime services are supplied by providers.

Prism 采用 Provider 驱动架构。核心负责软件包模型、Repository 抽象、依赖解析、Plan、Transaction、Journal、Reconcile、Recovery 与界面层；具体的软件源格式和 Runtime 服务通过 Provider 接入。

**Current release / 当前版本:** `0.4.1`  
**License / 许可证:** `Apache-2.0`

> Prism organizes capabilities exposed by an already-authorized runtime. It does not itself acquire jailbreak/system privileges, and its public service boundary does not expose arbitrary shell, kernel primitives, or arbitrary process-control interfaces.
>
> Prism 负责组织已授权 Runtime 提供的能力；它本身不负责获取越狱/系统权限，公开服务边界也不提供任意 Shell、内核原语或任意进程控制接口。

## Core Principles / 核心原则

- **Modern-first** — RELAXIN-X Modern Runtime is the primary integration path. / 以 RELAXIN-X Modern Runtime 为主要集成路线。
- **Legacy-compatible** — Debian/APT/Sileo/Zebra/DEB and traditional bootstrap environments remain supported through compatibility providers. / 通过兼容 Provider 保留 Debian/APT/Sileo/Zebra/DEB 与传统 bootstrap 生态。
- **Provider-driven** — runtimes, repositories, package services and application services are replaceable providers instead of hard-coded product branches. / Runtime、软件源、Package Service 与 Application Service 均通过 Provider 接入。
- **Transaction-safe** — write operations follow Plan → Transaction → Journal → Execute → Reconcile/Recovery. / 写操作统一经过 Plan → Transaction → Journal → Execute → Reconcile/Recovery。
- **Capability-based** — the UI and core use runtime capabilities instead of product-name checks or fixed filesystem assumptions. / UI 与 Core 依据 Runtime capability 工作，而不是依赖产品名或固定路径。
- **Quiet-by-default** — compatibility services remain idle until a task actually needs them. / 不需要的兼容服务默认保持 Idle。

## What Prism Implements / 已实现功能

### Store Experience / 商店体验

Prism provides five primary iPhone destinations:

- **Featured** — recommendations, categories, installed/update/source counts and recent activity.
- **Packages** — package browsing, search, category/source/install-state/commerce filters, sorting and package details.
- **Sources** — repository status, trust, compatibility, refresh, source-local search and removal.
- **Apps** — runtime-backed application state, registration, repair, removal and runtime-managed installation entry points.
- **Activity** — pending, running, recovery-needed, failed and completed transactions.

Prism 在 iPhone 上提供五个一级入口：Featured、Packages、Sources、Apps、Activity，覆盖软件包浏览、软件源管理、应用管理、事务状态与恢复。

### Repository Compatibility / 软件源兼容

Implemented repository support includes:

- Debian/APT repository metadata
- Sileo-compatible repository fields
- Zebra-compatible APT repository layouts
- `Packages` and `Packages.gz`
- package and repository icons
- multi-line descriptions
- architecture metadata
- hashes and technical package metadata
- dependencies, alternative dependencies and conflicts
- last-known-good catalog snapshots
- provider health and compatibility status

Legacy repository metadata is normalized into Prism domain models before reaching the UI.

### Package Management / 软件包管理

Prism implements:

- package discovery and search
- package detail and technical metadata
- dependency resolution
- conflict detection
- install planning
- update planning
- remove and purge planning
- installed-state inspection
- transaction-backed install/update/remove flows
- real package-state verification after execution
- repository-aware package selection
- provider pinning during active write transactions

In compatible legacy environments, the package service can use the existing APT/dpkg toolchain through the compatibility provider while keeping those implementation details out of the UI.

### Transactions, Journal & Recovery / 事务、日志与恢复

Every write operation uses the same safety pipeline:

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

Prism records provider identity and transaction state so interrupted operations can be reconciled instead of silently replayed through another provider.

Recovery capabilities include:

- reconcile
- rollback when supported
- safe abort when supported
- needs-review state
- interrupted transaction recovery
- actual-state inspection before recovery
- prevention of silent provider switching during an active transaction

### Runtime Service Bridge / Runtime 服务桥

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

`prismd` remains available as a compatibility service for environments that use a traditional daemon/package-service model. Modern environments can provide runtime-native services without making `prismd`, APT, dpkg or a fixed bootstrap layout mandatory.

### Runtime Connectivity / Runtime 连接

Runtime connectivity is treated as a managed system service rather than a one-shot connection.

Prism supports:

- startup initialization
- connection-state monitoring
- runtime health reporting
- reconnect handling
- explicit manual reconnect
- background-service capability checks
- diagnostics and global logging
- provider recomposition after reconnect when appropriate

### Application Management / 应用管理

Prism includes runtime-backed application models and typed application transactions for:

- application discovery
- registration / refresh
- repair
- removal
- runtime-managed installation requests
- artifact staging capability checks
- application-state verification
- transaction and recovery integration

Application operations remain behind typed runtime services; Prism does not expose arbitrary privileged process-control primitives.

### Commerce Contracts / Commerce 接口

Prism defines normalized repository-owned commerce and entitlement contracts.

- repositories own account/payment flows
- Prism consumes normalized entitlement results
- Prism does not store raw payment-card credentials
- owned packages still install through the standard transaction pipeline

### Diagnostics & Logging / 诊断与日志

Prism includes:

- provider status
- runtime bridge status
- capability status
- transaction history
- recovery state
- global logs
- redaction-oriented diagnostics for implementation-sensitive paths

Normal UI remains focused on user-relevant state; lower-level provider details stay in diagnostics.

### Localization / 本地化

Prism includes:

- English
- Simplified Chinese / 简体中文

## Architecture / 架构

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

The guiding rule is:

> **The runtime provides capabilities. Prism organizes capabilities.**

核心原则：

> **Runtime 负责提供能力，Prism 负责组织能力。**

## Runtime Modes / Runtime 模式

### Modern

A runtime-native provider supplies repository/package/application services directly. Traditional APT/bootstrap components are not mandatory.

### Hybrid

A modern runtime is primary, while legacy Debian/APT compatibility is activated only when required.

### Legacy

Traditional bootstrap environments can use `prismd` plus APT/dpkg compatibility providers.

## Project Structure / 项目结构

```text
App/                         Native iOS SwiftUI application
Packages/PrismCore/          Core Swift package
Scripts/                     Verification and architecture gates
docs/FEATURES.md             Detailed feature reference
docs/RUNTIME-INTEGRATION.md  Runtime/provider integration overview
Prism.xcodeproj/             Xcode project
Build.command                macOS build entry
```

## Building / 构建

Prism is a native Swift/SwiftUI project with a Swift Package based core.

On a supported macOS + Xcode environment:

```bash
./Build.command
```

The repository also contains verification scripts for core architecture and integration boundaries.

## Security Boundary / 安全边界

Prism-facing privileged contracts are typed and allowlisted. Prism intentionally does not turn runtime access into a generic privileged command interface.

Prism 公共高权限接口采用 typed / allowlisted contract，不把 Runtime 内部能力包装成任意高权限命令接口。

## Documentation / 文档

- [`docs/FEATURES.md`](docs/FEATURES.md) — complete feature reference / 完整功能说明
- [`docs/RUNTIME-INTEGRATION.md`](docs/RUNTIME-INTEGRATION.md) — runtime/provider integration / Runtime 与 Provider 接入说明

## License / 许可证

Copyright © 2026 Allen-ux-dev.

Licensed under the **Apache License, Version 2.0**. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

本项目采用 **Apache License 2.0** 开源许可证，完整条款见 [`LICENSE`](LICENSE) 与 [`NOTICE`](NOTICE)。
