# Prism 设计规范 v1.0（中文版）

**状态：** 已批准，可以进入实现  
**产品：** Prism  
**日期：** 2026-09-03

## 1. 产品定义

Prism 是一个原生 iOS 越狱软件包管理器与软件分发平台。

它不是 Sileo/Zebra 的换皮，也不是直接把 APT/dpkg 套上一层 GUI。Prism 自己持有并理解：

- Package
- Repository
- Version
- Dependency
- Environment Capability
- BuildPlan
- InstallPlan
- Transaction
- Queue
- Recovery State

现有 Sileo/APT/DEB 生态通过 Compatibility Provider 接入 Prism。

Prism 必须同时支持：

1. 当前越狱软件包生态；
2. 未来的源码分发 / 本机构建工作流。

因此 Prism Native Core **不能假设 APT、dpkg、DEB 或传统 bootstrap 永远存在**。

---

## 2. 总体架构

```text
Prism UI
   ↓
Application Services
   ↓
Prism Domain Core
   ├─ Package
   ├─ Repository
   ├─ Version
   ├─ Dependency
   ├─ Environment
   ├─ Capability
   ├─ BuildPlan
   ├─ InstallPlan
   └─ Transaction
   ↓
Provider / Backend Layer
   ├─ SileoCompatibilityProvider
   ├─ DebianAPTProvider
   ├─ PrismNativeProvider
   ├─ SourcePackageBackend
   └─ LegacyPackageBackend
   ↓
Privileged Transaction Service
   ↓
prismd
   ├─ TransactionExecutor
   ├─ TransactionJournal
   ├─ TransactionReconciler
   ├─ PackageBackend
   └─ EnvironmentProbe
```

UI 永远不能直接调用 APT/dpkg，也不能直接执行高权限文件系统操作。

---

## 3. Domain Core

### PrismPackage

统一的软件包模型：

- identity
- name
- version
- architecture
- author
- description
- repository
- dependencies
- conflicts
- requirements
- distribution (`deb`, `source`, `native`)
- installationState
- metadata

### Repository

Repository 是领域对象，而不是一个 URL 字符串。

它负责：

- identity
- base URL
- metadata
- provider identity
- packages
- refresh state
- trust state
- last refresh

### Version

版本比较必须实现 Debian / package-aware 语义。

禁止通过普通字符串比较包版本顺序。

### Dependency

依赖必须结构化为：

- package identifier
- relation
- required version

原始依赖字符串只允许在 Compatibility Boundary 中解析。

---

## 4. Environment 与 Capability

`PrismEnvironment` 管理：

- bootstrap identity
- root style：`rootless` / `rootful` / `custom`
- root prefix
- architecture
- package database
- capabilities

### EnvironmentCapability

包括：

- backgroundService
- packageInstall
- apt
- dpkg
- sourceBuild
- compiler
- systemHookRuntime
- tweakRuntime
- repositoryManagement

软件包 Requirement 与 Environment Capability 进行匹配。

业务层不能根据某个越狱产品名称进行逻辑分支。

`/var/jb` 等环境路径只能由 Environment Provider 返回，不能散落写死在业务源码中。

初始 Provider：

- StandardRootlessEnvironment
- RootfulEnvironment
- DopamineEnvironment
- RootHideEnvironment
- FutureEnvironment

---

## 5. Sileo / APT 兼容

Sileo/APT Repository 必须转换成 Prism 自己的 Repository / Package 对象。

Compatibility Parser 至少理解：

- `Package`
- `Version`
- `Architecture`
- `Depends`
- `Conflicts`
- `Filename`
- `Size`
- `SHA256`
- `Description`
- `Icon`
- `SileoDepiction`

Sileo 是 Prism 支持的生态之一，**不是 Prism 内部数据模型**。

---

## 6. Source Package

源码包可以包含：

- Manifest
- Source Reference
- Dependencies
- Environment Requirements
- Build Requirements
- Build Recipe
- Artifact Description

流程：

```text
SourcePackage
  ↓
CapabilityResolver
  ↓
DependencyResolver
  ↓
BuildPlan
  ↓
Local Build
  ↓
Artifact
  ↓
InstallPlan
  ↓
Transaction
```

`BuildPlan` 回答：

> 源码如何变成 Artifact。

`InstallPlan` 回答：

> Artifact 将如何修改设备状态。

两者必须分离。

---

## 7. InstallPlan 与 Transaction

任何系统修改之前，都必须先经过：

```text
User Intent
↓
Dependency Resolution
↓
Version Resolution
↓
Conflict Resolution
↓
Capability Resolution
↓
InstallPlan
```

`InstallPlan` 包含：

- requested packages
- installs
- upgrades
- removals
- dependencies
- conflicts
- environment requirements
- estimated changes

用户确认以后才创建 `Transaction`。

Transaction 是 Prism 中**唯一代表真实系统修改的执行单位**。

状态生命周期：

```text
Created
→ Preparing
→ Resolving
→ Ready
→ Executing
→ Reconciling
→ Completed
```

异常状态：

- Failed
- Cancelled
- NeedsRecovery
- NeedsReview

Queue 是 Transaction 集合，而不是简单下载列表。

---

## 8. 高权限架构

`Prism.app` 不直接持有 root 权限。

```text
Prism.app
    ↓
PrismPrivilegedClient
    ↓
typed IPC
    ↓
prismd
```

`prismd` 只运行在**已经获得授权的 jailbreak/bootstrap 环境**中。

Prism 本身不负责额外获取系统权限，也不加入额外提权逻辑。

Privileged IPC 必须：

- 类型化；
- 白名单化；
- 有明确的数据结构；
- 不允许任意 shell 命令。

禁止：

```text
runShell(...)
runAnyCommand(...)
executeArbitraryCommand(...)
```

允许的协议族例如：

- queryCapabilities
- queryTransactions
- submitTransaction
- cancelTransaction
- queryPackageState
- refreshRepositories
- reconcileState

---

## 9. 后台事务与恢复保证

Transaction 一旦被用户确认，其生命周期必须独立于 Prism UI 生命周期。

以下情况不能自动视为 Transaction 失败：

- App 进入后台
- App 被挂起
- UI 被结束
- IPC 临时断开
- UI 进程重启

启动 / 重连流程：

```text
EnvironmentProbe
→ Jailbreak/Bootstrap Detection
→ PrivilegedSessionManager
→ prismd Handshake
→ Capability Negotiation
→ Transaction Reconciliation
→ Package State Reconciliation
→ Ready
```

### TransactionJournal

必须持久化：

- transaction ID
- install plan
- current phase
- completed operations
- pending operations
- state before
- state after
- timestamps
- backend state
- result

### TransactionReconciler

重启或断线之后先比较：

```text
Prism Expected State
        ↕
Actual Package/System State
```

绝不能在 daemon 重启后无脑重复旧事务。

---

## 10. Settings

重要系统功能集中在 Settings。

### Background Service

- Status
- Connect / Reconnect
- Auto Reconnect
- Restart
- Repair
- Version

### Jailbreak Environment

- Bootstrap
- Root Style
- Root Prefix
- Architecture
- Capabilities

### Transaction Recovery

- Unfinished Transactions
- Recovery History
- Journal Health
- Reconcile

### Package Compatibility

- Sileo
- Debian/APT
- Source Package
- Depictions

### Sources & Cache

- Refresh All
- Rebuild Index
- Clear Metadata Cache

### Diagnostics

- Prism Core
- prismd
- IPC
- Package Backend
- Export Diagnostics

`PrivilegedSession` 只表示 Prism 与 `prismd` 的连接会话。

UI 应显示：

```text
Privileged Service
Connected / Recovering / Offline
```

不要显示：

```text
Root Access: ON
```

---

## 11. UI 信息架构

V1 主导航：

- Featured
- Packages
- Sources
- Installed
- Updates
- Queue

Settings 是系统管理入口。

Package Detail 显示：

- icon
- name
- description
- screenshots
- version
- author
- repository
- compatibility
- dependencies
- installation state
- install / update / remove actions

具体视觉样式暂时保持可调整。

---

## 12. 正式 App Icon

Prism 正式图标已经确定。

要求：

- 只使用三种主色；
- 中央为竖直、居中的多面棱镜 / 水晶；
- 背景为全局青蓝到深蓝的圆角方形渐变；
- 顶部顶点到图标顶部的留白，与最底部点到底部的留白等距；
- 整体拥有现代 iOS package manager 气质；
- 可以参考 Sileo 的视觉气质，但不能复制其图形。

标准素材：

`Branding/Prism-AppIcon.png`

---

## 13. Architecture Contract

以下规则不可破坏：

1. UI 永远不能直接调用 APT/dpkg。
2. UI 永远不能直接执行高权限文件操作。
3. Package 和 Repository 必须是 Domain Object。
4. Version 比较必须 package-aware。
5. Dependency 必须结构化。
6. jailbreak 路径只能来自 Environment Provider。
7. 每次安装/修改都必须先有 InstallPlan。
8. Source Build 必须使用独立 BuildPlan。
9. InstallPlan 与 Transaction 必须分开。
10. Queue 展示 Transaction。
11. 用户确认后的 Transaction 必须独立于 UI 生命周期。
12. UI 断线不等于 Transaction 失败。
13. Transaction 必须写入 Journal。
14. Recovery 必须先 Reconcile，再决定是否继续执行。
15. Privileged API 必须类型化并限制在白名单中。
16. Prism Native Core 不依赖 Sileo 内部实现。
17. Prism Native Core 不假设 APT/dpkg/DEB 永远存在。
18. Sileo/APT 属于 Compatibility Provider。
19. Distribution Format 与 Runtime Capability 必须解耦。
20. Installed、Updates、Search 共用统一 Package State。
21. 新 jailbreak 环境优先增加 Provider，不允许在 View 中散落条件判断。
22. `prismd` 使用已有 jailbreak/bootstrap 权限，不负责利用系统获得新权限。
23. 高权限只属于 Transaction Executor，不属于 UI。

---

## 14. V1 成功标准

V1 必须做到：

- Sileo-compatible Repository 可以转换成 Prism Repository / Package。
- UI 不需要知道一个包来自 DEB 还是 Source。
- Dependency 可以生成结构化 InstallPlan。
- Source Package 可以生成 BuildPlan。
- Environment 能通过 Capability 描述环境，而不是按越狱名称写死逻辑。
- Rootless / Rootful 路径不会泄漏到业务层。
- 用户确认后的 Transaction 在 UI 重启、断线后仍能恢复。
- Journal + Reconciler 可以恢复 Transaction 与 Queue 状态。
- Settings 可以查看后台连接、Environment、Recovery 和 Diagnostics。
- Sileo/APT Backend 将来可以被替换，而不需要重做 UI。
- Prism Core 关键模块拥有单元测试。
- Mock Backend 能跑通：

```text
Repository
→ Package
→ Resolve
→ InstallPlan
→ Confirm
→ Transaction
→ Journal
→ Reconcile
→ Completed
```

---

## 15. 产品原则

**Prism 应该理解 Package、Environment 和 Transaction，而不只是理解“要执行哪条命令”。**

Prism 真正需要理解的是：

```text
软件是什么
它需要什么
当前环境有什么
系统实际需要改变什么
改变执行到了哪里
失败以后如何恢复
```
