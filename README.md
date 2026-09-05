# Prism

<p align="center">
  <a href="README.en.md"><strong>English</strong></a>
  ·
  <a href="README.zh-CN.md"><strong>简体中文</strong></a>
</p>

**A modern iOS package manager and runtime frontend for jailbreak and advanced system environments.**  
**一个面向越狱与高级系统环境的现代 iOS 软件包管理器与 Runtime 前端。**

Prism is a provider-driven iOS package platform with repository management, package discovery and dependency resolution, transaction-backed install/update/remove flows, recovery, Runtime Service Bridge integration, application management, diagnostics, and Debian/APT/Sileo/Zebra compatibility.

Prism 是一个 Provider 驱动的 iOS 软件包平台，已实现软件源管理、软件包发现、依赖解析、基于 Transaction 的安装/更新/删除、Recovery、Runtime Service Bridge、应用管理、诊断，以及 Debian/APT/Sileo/Zebra 兼容能力。

**Current release / 当前版本:** `0.4.1`  
**License / 许可证:** `Apache-2.0`

## Choose a Language / 选择语言

- [English documentation / English README](README.en.md)
- [简体中文文档 / 中文 README](README.zh-CN.md)

## Why Prism / 为什么选择 Prism

- **No mandatory basebin dependency in Modern mode / Modern 模式不强制依赖 basebin** — Prism Core does not require `basebin`, APT, dpkg, `prismd`, `/var/jb`, or a fixed bootstrap layout when a Modern Runtime provides native services. / 当 Modern Runtime 提供原生服务时，Prism Core 不把 `basebin`、APT、dpkg、`prismd`、`/var/jb` 或固定 bootstrap 目录作为强制依赖。
- **Provider-driven / Provider 驱动** — runtime, repository, package, and application services are replaceable providers instead of product-name branches. / Runtime、软件源、Package Service、Application Service 均通过 Provider 接入，而不是围绕某个产品名写死。
- **Modern-first, legacy-compatible / Modern-first，同时兼容旧生态** — native Runtime services can be primary while Debian/APT/Sileo/Zebra compatibility remains available when needed. / 原生 Runtime 服务可以作为主线，需要时仍可兼容 Debian/APT/Sileo/Zebra 生态。
- **Transaction-safe / 事务安全** — package and app writes use Plan → Transaction → Journal → Reconcile/Recovery with actual-state verification. / 软件包和应用写操作统一经过 Plan → Transaction → Journal → Reconcile/Recovery，并检查真实状态。
- **Runtime-independent core / Core 不被单一 Runtime 绑死** — capability-based selection allows Prism to adapt to different authorized environments without redesigning package-management logic. / 通过 Capability 选择能力，让 Prism 能适配不同已授权环境，而不需要重写包管理核心。
- **Built-in recovery and diagnostics / 内建恢复与诊断** — interrupted work can enter Reconcile, Rollback, Safe Abort, Needs Review, diagnostics, and reconnect flows where supported. / 在 Provider 支持时，中断任务可进入 Reconcile、Rollback、Safe Abort、Needs Review、诊断和重连流程。

## Highlights / 核心能力

- Featured / Packages / Sources / Apps / Activity five-tab store experience
- Debian/APT repository support with Sileo/Zebra-compatible metadata
- Dependency resolution, conflict detection, install/update/remove/purge planning
- Transaction → Journal → Reconcile / Recovery safety model
- Runtime Service Bridge and provider registry/resolver architecture
- `prismd` compatibility service for traditional environments
- Runtime/helper connection monitoring and reconnect handling
- Runtime-backed application registration, repair, removal, and installation entry points
- Diagnostics, global logging, and English/Simplified Chinese localization

## Documentation / 文档

- [`docs/USAGE.md`](docs/USAGE.md) — usage guide / 使用指南
- [`docs/FEATURES.md`](docs/FEATURES.md) — complete feature reference / 完整功能说明
- [`docs/RUNTIME-INTEGRATION.md`](docs/RUNTIME-INTEGRATION.md) — Runtime/provider integration / Runtime 与 Provider 集成

Each public guide includes **English / 简体中文** switching.

所有公开文档均提供 **English / 简体中文** 切换。

## Architecture / 架构

```text
Prism UI
   ↓
Prism Core
   ↓
Provider Registry / Resolver
   ↓
Runtime Service Bridge / Compatibility Provider
   ↓
Authorized Runtime Environment
```

> **The runtime provides capabilities. Prism organizes capabilities.**  
> **Runtime 负责提供能力，Prism 负责组织能力。**

## License / 许可证

Copyright © 2026 Allen-ux-dev.

Licensed under the **Apache License, Version 2.0**. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
