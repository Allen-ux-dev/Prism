# Prism

[English](README.en.md) | [简体中文](README.zh-CN.md)

**一个面向越狱与高级系统环境的现代 iOS 软件包管理器与 Runtime 前端。**

Prism 采用 Provider 驱动架构。核心负责软件包模型、Repository 抽象、依赖解析、Plan、Transaction、Journal、Reconcile、Recovery 与界面层；具体的软件源格式和 Runtime 服务通过 Provider 接入。

**当前版本：** `0.4.1`  
**许可证：** `Apache-2.0`

> Prism 负责组织已授权 Runtime 提供的能力；它本身不负责获取越狱或系统权限，公开服务边界也不提供任意 Shell、内核原语或不受限制的进程控制接口。

## 核心原则

- **Modern-first** — 以 RELAXIN-X Modern Runtime 为主要集成路线。
- **Legacy-compatible** — 通过兼容 Provider 保留 Debian/APT/Sileo/Zebra/DEB 与传统 bootstrap 生态。
- **Provider-driven** — Runtime、软件源、Package Service 与 Application Service 都通过 Provider 接入，而不是写死产品分支。
- **Transaction-safe** — 写操作统一经过 Plan → Transaction → Journal → Execute → Reconcile/Recovery。
- **Capability-based** — Prism 根据 Runtime capability 工作，而不是依赖产品名或固定文件系统路径。
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
- Provider health 与 compatibility 状态

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
- 活跃写事务中的 Provider pinning

在兼容的 Legacy 环境中，Package Service 可以通过兼容 Provider 使用现有 APT/dpkg 工具链，同时不把这些底层实现细节暴露给普通 UI。

### Transaction、Journal 与 Recovery

所有写操作统一经过：

```text
Plan
  ↓
Transaction
  ↓
Journal
  ↓
Provider / Runtime Execute
  ↓
检查真实状态
  ↓
Reconcile
  ↓
Commit / Recovery / Needs Review
```

恢复能力包括：

- reconcile
- Provider 支持时 rollback
- Provider 支持时 safe abort
- 中断事务恢复
- Needs Review 状态
- Recovery 前检查真实状态
- 防止活跃事务过程中静默切换 Provider

### Runtime Service Bridge

Prism 支持面向已授权 Runtime 的 typed、versioned Runtime Service Bridge。

Bridge 可以暴露：

- Runtime Descriptor
- Capability Registry
- Package Service
- Application Service
- Artifact Staging Service
- Background Runtime Service
- Health / Reconnect 状态
- 可选的 typed Compatibility Service

`prismd` 继续作为传统 daemon/package-service 环境的兼容服务。Modern Runtime 可以直接提供原生服务，不强制依赖 `prismd`、APT、dpkg 或固定 bootstrap 布局。

### Runtime 连接管理

Prism 已实现 Runtime/helper 连接管理：

- 启动时自动初始化
- 连接状态持续监测
- Runtime health 状态
- 断线重连
- 手动重连
- Background Service capability 检查
- Diagnostics 与 Global Log
- 重连后按情况重新组合 Provider

### 应用管理

Prism 已包含 Runtime-backed 应用模型与 typed application transaction，用于：

- 应用发现
- Register / Refresh
- Repair
- Remove
- Runtime-managed installation request
- Artifact staging capability 检查
- 应用真实状态验证
- Transaction / Recovery 集成

### Commerce 接口

- 软件源自己负责账号与付款流程
- Prism 只消费归一化的 entitlement 结果
- Prism 不保存原始银行卡信息
- 已购买软件包仍通过标准 Transaction 流程安装

### 诊断与日志

- Provider Status
- Runtime Bridge Status
- Capability Status
- Transaction History
- Recovery State
- Global Logs
- 对实现敏感路径进行脱敏的 Diagnostics

### 本地化

- English
- 简体中文

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

Runtime-native Provider 直接提供 Repository、Package 与 Application Service，传统 APT/bootstrap 组件不是必需条件。

### Hybrid

Modern Runtime 作为主线，只在需要时启用 Debian/APT Legacy Compatibility。

### Legacy

传统 bootstrap 环境可以使用 `prismd` + APT/dpkg Compatibility Provider。

## 项目结构

```text
App/                         原生 iOS SwiftUI 应用
Packages/PrismCore/          Core Swift Package
Scripts/                     验证脚本与架构门禁
docs/FEATURES.md             完整功能说明
docs/RUNTIME-INTEGRATION.md  Runtime / Provider 接入说明
Prism.xcodeproj/             Xcode 工程
Build.command                macOS 构建入口
```

## 构建

Prism 是原生 Swift / SwiftUI 项目，核心使用 Swift Package。

```bash
./Build.command
```

## 文档

- [`docs/FEATURES.md`](docs/FEATURES.md) — 完整功能说明
- [`docs/RUNTIME-INTEGRATION.md`](docs/RUNTIME-INTEGRATION.md) — Runtime / Provider 接入说明

## 许可证

Copyright © 2026 Allen-ux-dev.

本项目采用 **Apache License 2.0** 开源许可证，完整条款见 [`LICENSE`](LICENSE) 与 [`NOTICE`](NOTICE)。
