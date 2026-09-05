# Prism Runtime 集成

[English](RUNTIME-INTEGRATION.en.md) | [简体中文](RUNTIME-INTEGRATION.zh-CN.md)

Prism 将软件包管理逻辑与 Runtime 侧的高权限执行分离。Prism Core 负责模型、解析、事务、恢复与界面；已经获得授权的 Runtime Provider 负责提供具体执行能力。

## 集成模型

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

公开集成协议采用 Capability 驱动并进行版本化。

## 一个重要优势：Modern 模式不强制依赖 basebin

在 **Modern** 模式下，一个合法的 Prism 环境不要求 Prism Core 必须依赖 `basebin`、APT、dpkg、`prismd`、`/var/jb` 或固定 bootstrap 目录。

Runtime 可以通过 typed Provider 直接提供原生的软件源、软件包、应用和 Artifact 服务。

传统组件并没有被删除：当当前环境或任务确实需要 Debian/APT 生态时，Prism 可以通过兼容 Provider 使用这些传统组件。这样既保留旧生态兼容，又不会让旧目录结构成为 Core 的全局前提。

## Runtime Descriptor

Runtime 集成可以描述：

- Runtime Identity
- Runtime Version
- 平台架构
- OS Version
- Compatibility Level
- available / degraded / unavailable Capability
- Service Protocol Range
- 可选 Storage / Package Namespace

## Capability Registry

Capability 使用开放标识，而不是依赖产品名判断行为。

典型能力包括：

- Package Query
- Package Write
- Repository Sync
- Application Query
- Application Management
- Artifact Staging
- Background Execution
- Privileged Service
- Health Reporting
- Reconcile
- Rollback
- Safe Abort

未来出现的未知可选 Capability，可以被旧版 Prism 安全忽略。

## Package Service

Package Service 可以提供 typed operation，例如：

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

真实后端既可以是 Runtime 原生服务，也可以是兼容 Provider。

## Application Service

Typed Application Operation 可以包括：

- 检查应用状态
- Register / Refresh
- Repair
- Remove
- 提交 Runtime 管理的安装请求
- 校验最终应用状态

应用操作与软件包操作共用 Transaction / Journal / Recovery 模型。

## Artifact Staging

Artifact Staging 是独立 Capability。只有连接的 Runtime 真正声明所需的 Staging / Application Capability 时，Prism 才提供 Runtime 管理的安装入口。

## Background Runtime Service

后台运行同样由 Capability 控制。只有 Runtime 提供所需的 background 与 privileged-service Capability 时，Prism 才会请求后台 Session。

## Health 与重连

Prism 会跟踪：

- Connection State
- Service Health
- 已协商 Capability
- Runtime Identity
- Reconnect State
- Provider Availability
- Background Service State

连接中断不会允许 Prism 把已经开始的写事务静默迁移到另一个 Provider。

## Provider 选择

Provider 选择会考虑：

- Runtime Compatibility
- 所需 Capability
- Package / Repository Format 要求
- Provider Health
- Service Protocol Compatibility
- Transaction Ownership

一个写事务开始后，其 Provider 会被 Pin 到该事务。

## Runtime 模式

### Modern

Runtime 原生服务优先。`basebin`、APT、dpkg、`prismd`、`/var/jb` 和传统 bootstrap 都不是 Prism Core 的强制依赖。

### Hybrid

Modern Runtime 保持主线，只有需要 Debian/APT 生态的任务才启用兼容层。

### Legacy

传统环境可以通过兼容 Provider 使用 `prismd`、APT/dpkg 以及相关 bootstrap 组件。

## `prismd`

`prismd` 是兼容服务，而不是 Prism Core 的强制依赖。对于传统 daemon/bootstrap 环境，它可以提供 typed Package Service 边界。

## Repository Provider

Repository Provider 会把不同软件源的原始 metadata 归一化成 Prism Domain。当前兼容 Debian/APT 布局以及常见 Sileo/Zebra metadata 模式。

## Transaction 边界

```text
Plan
→ Transaction
→ Journal
→ Runtime / Provider Execute
→ Inspect Actual State
→ Reconcile
→ Commit / Recovery / Needs Review
```

Runtime 执行不会绕过这一模型。

## 安全边界

Prism 不请求通用的任意高权限执行。公开 Runtime 边界采用 typed、allowlisted Operation；任意 Shell、内核原语和不受限制的进程控制接口不属于 Prism-facing API。

## Diagnostics

Advanced Diagnostics 可以显示 Provider ID、协议兼容性、Capability State、连接 Health 与 Recovery 状态。实现敏感路径在显示或导出前应进行脱敏。
