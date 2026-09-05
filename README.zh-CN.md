# Prism

[English](README.en.md) | [简体中文](README.zh-CN.md)

**一个面向越狱与高级系统环境的现代 iOS 软件包管理器与 Runtime 前端。**

Prism 采用 Provider 驱动架构。核心负责软件包模型、Repository 抽象、依赖解析、Plan、Transaction、Journal、Reconcile、Recovery 与界面层；具体的软件源格式和 Runtime 服务通过 Provider 接入。

**当前版本：** `0.4.1`  
**许可证：** `Apache-2.0`

> Prism 负责组织已授权 Runtime 提供的能力；它本身不负责获取越狱或系统权限，公开服务边界也不提供任意 Shell、内核原语或不受限制的进程控制接口。

## 为什么选择 Prism

### Modern 模式不强制依赖 basebin

当 Modern Runtime 能够提供原生服务时，Prism Core 不把 `basebin`、APT、dpkg、`prismd`、`/var/jb` 或固定 bootstrap 目录作为强制依赖。

传统组件依然保留：只有当软件源、软件包或当前环境确实需要 Debian/APT 生态时，Prism 才通过兼容 Provider 使用相关传统工具链。

### Provider 驱动，而不是产品名驱动

Runtime、软件源、Package Service 与 Application Service 都根据 Capability 和 Provider 选择，不围绕某个越狱产品名或固定文件路径硬编码逻辑。

### Modern-first，同时兼容旧生态

Runtime 原生服务可以作为主线，同时继续通过兼容 Provider 支持 Debian/APT 软件源以及常见 Sileo/Zebra metadata 约定。

### 统一的事务安全模型

软件包与应用写操作统一经过：

```text
Plan
→ Transaction
→ Journal
→ Execute
→ Inspect Actual State
→ Reconcile
→ Commit / Recovery / Needs Review
```

这样 Prism 可以统一处理恢复，并避免已经开始的写事务静默迁移到其他 Provider。

### Core 不被单一 Runtime 绑死

软件包模型、依赖解析、Transaction、Recovery 与界面层都不依赖某一种具体 Runtime 实现。

### 内建 Diagnostics 与重连

Runtime/helper Health、Provider 状态、Transaction History、Recovery、Global Log 与 Reconnect 都属于 Prism 自身产品能力，而不是额外拼接的工具。

## 核心原则

- **Modern-first** — 以 RELAXIN-X Modern Runtime 为主要集成路线。
- **Legacy-compatible** — 通过兼容 Provider 保留 Debian/APT/Sileo/Zebra/DEB 与传统 bootstrap 生态。
- **Provider-driven** — Runtime、软件源、Package Service 与 Application Service 都通过 Provider 接入，而不是写死产品分支。
- **Transaction-safe** — 写操作统一经过 Plan → Transaction → Journal → Execute → Reconcile/Recovery。
- **Capability-based** — Prism 根据 Runtime Capability 工作，而不是依赖产品名或固定文件系统路径。
- **Quiet-by-default** — 不需要的兼容服务默认保持 Idle，只有真实任务需要时才激活。

## 已实现功能

### 商店体验

Prism 在 iPhone 上提供五个一级入口：

- **Featured** — 推荐、分类、已安装/更新/软件源数量与近期活动。
- **Packages** — 软件包浏览、搜索、分类/来源/安装状态/Commerce 筛选、排序与详情。
- **Sources** — 软件源状态、信任、兼容性、刷新、源内搜索与移除。
- **Apps** — Runtime 提供的应用状态、注册、修复、移除与 Runtime 管理的安装入口。
- **Activity** — Pending、Running、Needs Review / Recovery、Failed、Completed 事务状态。

### 软件源兼容

当前已实现：

- Debian/APT Repository metadata
- Sileo 常见扩展字段兼容
- Zebra 常见 APT Repository 布局兼容
- `Packages` 与 `Packages.gz`
- 软件包与软件源图标
- 多行 Description
- Architecture metadata
- Hash 与技术元数据
- Depends、Alternative Dependencies 与 Conflicts
- Last-known-good catalog snapshot
- Provider Health 与 Compatibility 状态

Legacy Repository 数据会先归一化成 Prism Domain，再交给 UI 使用。

### 软件包管理

Prism 已实现：

- 软件包发现与搜索
- 软件包详情与技术信息
- 依赖解析
- 冲突检测
- 安装与更新计划
- Remove 与 Purge 计划
- 已安装状态检查
- 基于 Transaction 的安装/更新/删除流程
- 执行后真实软件包状态验证
- 基于 Repository 的包选择
- 活跃写事务中的 Provider Pinning

在兼容的 Legacy 环境中，Package Service 可以通过兼容 Provider 使用现有 APT/dpkg 工具链，同时不把这些底层实现细节暴露给普通 UI。

### Runtime Service Bridge

Prism 支持面向已授权 Runtime 的 typed、versioned Runtime Service Bridge。Bridge 可以暴露 Runtime Descriptor、Capability Registry、Package Service、Application Service、Artifact Staging、Background Runtime Service、Health、Reconnect State 与 typed Compatibility Service。

`prismd` 继续作为传统 daemon/package-service 环境的兼容服务。Modern Runtime 可以直接提供原生服务，不强制依赖 `basebin`、`prismd`、APT、dpkg 或固定 bootstrap 布局。

### Runtime 连接管理

Prism 已实现 Runtime/helper 连接管理：

- 启动时自动初始化
- 连接状态持续监测
- Runtime Health 状态
- 断线重连
- 手动重连
- Background Service Capability 检查
- Diagnostics 与 Global Log
- 重连后按情况重新组合 Provider

### 应用管理

Prism 已包含 Runtime-backed 应用模型与 typed application transaction，用于应用发现、Register / Refresh、Repair、Remove、Runtime-managed installation request、Artifact Staging Capability 检查、应用真实状态验证，以及 Transaction / Recovery 集成。

## 架构

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

> **Runtime 负责提供能力，Prism 负责组织能力。**

## Runtime 模式

### Modern

Runtime-native Provider 直接提供 Repository、Package 与 Application Service。`basebin`、APT、dpkg、`prismd`、`/var/jb` 和传统 bootstrap 都不是 Prism Core 的强制依赖。

### Hybrid

Modern Runtime 作为主线，只在需要时启用 Debian/APT Legacy Compatibility。

### Legacy

传统 bootstrap 环境可以通过兼容 Provider 使用 `prismd`、APT/dpkg 以及相关组件。

## 构建

Prism 是原生 Swift / SwiftUI 项目，核心使用 Swift Package。

```bash
./Build.command
```

## 文档

- [`docs/USAGE.zh-CN.md`](docs/USAGE.zh-CN.md) — 使用指南
- [`docs/FEATURES.zh-CN.md`](docs/FEATURES.zh-CN.md) — 完整功能说明
- [`docs/RUNTIME-INTEGRATION.zh-CN.md`](docs/RUNTIME-INTEGRATION.zh-CN.md) — Runtime / Provider 接入说明

所有公开文档都提供对应英文版本的跳转入口。

## 许可证

Copyright © 2026 Allen-ux-dev.

本项目采用 **Apache License 2.0** 开源许可证，完整条款见 [`LICENSE`](LICENSE) 与 [`NOTICE`](NOTICE)。
