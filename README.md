# Prism

**A modern iOS package manager and runtime frontend for jailbreak and advanced system environments.**  
**一个面向越狱与高级系统环境的现代 iOS 软件包管理器与 Runtime 前端。**

Prism provides package sources, package and application management, transaction-safe operations, recovery, commerce contracts, and modern/legacy runtime compatibility.

Prism 提供软件源、软件包与应用管理、事务安全操作、恢复机制、Commerce 接口，以及现代与旧生态 Runtime 兼容层。

**Current release / 当前版本:** `0.4.1 · Build 52 — Complete Store`  
**License / 许可证:** `Apache-2.0`

> Prism organizes capabilities exposed by an already-authorized runtime. It does not itself acquire jailbreak/system privileges, and its public service boundary does not expose arbitrary shell, kernel primitives, or arbitrary process-control interfaces.
>
> Prism 负责组织已授权 Runtime 提供的能力；它本身不负责获取越狱/系统权限，公开服务边界也不提供任意 Shell、内核原语或任意进程控制接口。

## Highlights / 主要能力

- **Modern-first** — RELAXIN-X Modern Runtime is the primary integration path. / 以 RELAXIN-X Modern Runtime 为主要集成路线。
- **Legacy-compatible** — Debian/APT/Sileo/Zebra/DEB remain supported through compatibility providers. / 通过兼容 Provider 保留 Debian/APT/Sileo/Zebra/DEB 生态。
- **Provider-driven** — runtimes, repositories and package services are replaceable providers rather than hard-coded product branches. / Runtime、软件源和 Package Service 均通过 Provider 接入。
- **Transaction-safe** — write operations follow Plan → Transaction → Journal → Reconcile/Recovery. / 写入操作统一经过 Plan → Transaction → Journal → Reconcile/Recovery。
- **Runtime-first Apps** — application state and typed Install/Register/Replace/Remove/Refresh operations are supplied through the Runtime Service Bridge. / App 管理优先使用真实 Runtime Service Bridge。
- **Complete Store** — Featured, Packages, Sources, Apps and Activity form the five primary iPhone tabs. / Featured、Packages、Sources、Apps、Activity 构成完整五栏商店体验。
- **Recovery-aware** — failed or interrupted operations can be reconciled instead of silently switching providers. / 失败或中断操作进入 Reconcile/Recovery，而不是静默切换 Provider。
- **Bilingual UI** — Simplified Chinese and English. / 支持简体中文与英文。

## Architecture / 架构

```text
Prism Store UI
      │
      ▼
Presentation / Coordinator
      │
      ▼
Prism Core
 ├─ Repository Providers
 ├─ Package Service
 ├─ Transaction / Journal / Recovery
 ├─ Commerce Contracts
 └─ Runtime Service Bridge
      │
      ▼
Authorized Runtime Provider
(e.g. RELAXIN-X Runtime Service Host)
```

The core rule is simple:

> **RELAXIN-X provides capabilities. Prism organizes capabilities.**

核心原则：

> **RELAXIN-X 负责提供能力，Prism 负责组织能力。**

## Build 52 — Complete Store

Build 52 completes Prism's provider-neutral store product layer without rewriting the frozen runtime/package cores.

- Featured derives recommendations, categories, installed/update/source counts and recent activity from normalized store data.
- Packages supports combined search/category/source/install/commerce filters, deterministic sorting, technical details, dependency/conflict/requirement presentation and transaction-backed package actions.
- Sources provides provider-neutral status, trust, compatibility, refresh, search and removal.
- Apps is real-runtime-first; Register / Repair / Remove submit normal Prism transactions. Simulation remains under Advanced/Lab only.
- Activity groups transactions into Pending / Running / Needs Review & Recovery / Failed / Completed.
- Runtime Background Service is capability-gated and only operates when the connected runtime advertises the required capabilities.

Build 52 完成了 Prism 的完整商店产品层，同时不重写已经冻结的 Runtime/Package Core：

- Featured：推荐、分类、已安装/更新/软件源统计和最近活动。
- Packages：搜索、分类、来源、安装状态、Commerce 筛选、排序、依赖/冲突/Requirements 与事务化操作。
- Sources：Provider 状态、Trust、Compatibility、刷新、搜索与移除。
- Apps：Real Runtime First；Register / Repair / Remove 全部提交标准 Prism Transaction，Simulation 仅保留在 Advanced/Lab。
- Activity：Pending / Running / Needs Review & Recovery / Failed / Completed。
- Runtime Background Service：严格按 Runtime capability 决定是否可用。

## Runtime Integration / Runtime 集成

Prism Build 49–52 established the following long-lived contracts:

```text
Build 49  Future Wiring
Build 50  Application Runtime Wiring
Build 51  Runtime Service Bridge
Build 52  Complete Store
```

A real runtime integration should expose typed, versioned services such as:

```text
Runtime Descriptor
Capability Registry
Application Service
Artifact Staging Service
Package Service
Background Runtime Service
Health / Reconnect
Optional Injection Service
```

Prism does not require a runtime to expose its internal implementation details.

## Repository Compatibility / 软件源兼容

Prism keeps legacy ecosystem compatibility while allowing modern providers:

- APT-compatible repositories
- Sileo-compatible metadata
- Zebra-compatible repositories
- Debian packages (`.deb`)
- Modern provider-specific repository formats
- Package icons and repository icons
- Dependencies / Conflicts / Architecture / SHA256 / Depiction metadata

Future-first does **not** mean removing the existing ecosystem.

## Transactions & Recovery / 事务与恢复

```text
Plan
 ↓
Transaction
 ↓
Journal
 ↓
Runtime / Package Provider
 ↓
Actual-state verification
 ↓
Reconcile
 ↓
Commit / Recovery / Needs Review
```

An active transaction pins the selected provider. Runtime disconnects do not silently move the operation to a different provider.

## Commerce

Prism defines repository-owned commerce and entitlement contracts. Prism is **not** a wallet and does not store raw payment credentials. Once a package is owned, installation still follows the normal InstallPlan → Transaction → Journal → Reconcile pipeline.

## Project Structure / 项目结构

```text
App/                         iOS SwiftUI application
Packages/PrismCore/          Core Swift Package
Scripts/                     Verification and architecture gates
docs/                        Runtime integration specifications
Prism.xcodeproj/             Xcode project
Build.command                macOS build entry
```

## Building / 构建

The project targets native iOS and uses Swift / SwiftUI with a Swift Package based core. On a supported macOS + Xcode environment, use the repository's `Build.command` as the build entry point.

项目为原生 iOS Swift/SwiftUI 架构，核心使用 Swift Package。请在支持的 macOS + Xcode 环境中使用仓库根目录的 `Build.command` 作为构建入口。

## Security Boundary / 安全边界

Prism-facing contracts are typed and allowlisted. The public Prism service boundary is intentionally not an arbitrary privileged command interface.

Prism 公共接口采用 typed / allowlisted contract，不将 Runtime 内部能力转换成任意高权限命令接口。

## License / 许可证

Copyright © 2026 Allen-ux-dev.

Licensed under the **Apache License, Version 2.0**. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

本项目采用 **Apache License 2.0** 开源许可证，完整条款见 [`LICENSE`](LICENSE) 与 [`NOTICE`](NOTICE)。
