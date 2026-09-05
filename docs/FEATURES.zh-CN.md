# Prism 功能

[English](FEATURES.en.md) | [简体中文](FEATURES.zh-CN.md)

本文档介绍 Prism 当前已经实现的公开能力，重点描述现在能做什么，不记录内部开发阶段或迭代过程。

## 为什么选择 Prism

Prism 的核心设计目标之一，就是让软件包管理器不被某一种越狱目录结构或传统工具链绑死。

### Modern 模式不强制依赖 basebin

在 Modern Runtime 环境中，Prism **不把** `basebin`、APT、dpkg、`prismd`、`/var/jb` 或固定 bootstrap 目录作为 Prism Core 的强制依赖。Runtime 可以通过 typed Provider 直接向 Prism 提供软件包、软件源和应用管理服务。

传统环境依然兼容：只有当真实任务需要 Debian/APT 生态时，Prism 才可以启用基于传统工具链的兼容 Provider。

### Provider 驱动，而不是产品名驱动

Prism 依据 Runtime Descriptor、Capability 与 Provider 选择功能，不通过某个越狱产品名或固定文件路径硬编码行为。

### 更安全的写入模型

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

这样可以让中断后的操作进入恢复流程，并避免一个已经开始的写事务静默切换到其他 Provider。

### Modern-first，同时兼容旧生态

Prism 可以优先使用 Runtime 原生服务，同时继续兼容 Debian/APT 软件源以及常见的 Sileo/Zebra metadata 约定。

## 软件包与软件源

- Provider-neutral 软件包 Domain
- Debian/APT 软件源兼容
- Sileo metadata 归一化
- Zebra 常见 APT 软件源布局兼容
- `Packages` 与 `Packages.gz`
- 软件包和软件源图标
- 软件包搜索与筛选
- 分类 / 软件源 / 安装状态筛选
- 确定性排序
- 软件包技术信息
- 架构与 Hash metadata
- Depends
- Alternative Dependencies
- Conflicts
- Last-known-good 软件源快照
- 软件源状态、Health、Trust 与 Compatibility
- 软件源刷新、源内搜索与删除

## 软件包操作

- Install Plan
- Update Plan
- Remove Plan
- Purge Plan
- 依赖解析
- 冲突检测
- 已安装状态检查
- Provider 选择
- 活跃写事务 Provider Pinning
- 执行后真实状态校验
- 在兼容环境中通过 APT/dpkg Provider 执行传统包管理操作

## Store 界面

Prism 在 iPhone 上提供五个一级入口：

- **Featured** — 推荐、分类、已安装/更新/软件源数量与近期活动
- **Packages** — 浏览、搜索、筛选、排序、技术详情与软件包操作
- **Sources** — 软件源状态、Trust、Compatibility、刷新、搜索和删除
- **Apps** — Runtime 提供的应用状态、注册、修复、删除和 Runtime 管理的安装入口
- **Activity** — Pending、Running、Needs Review / Recovery、Failed、Completed

## Runtime 与 Provider 系统

Prism 使用 Provider Registry / Resolver，而不是只有一个写死的后端。

已支持的核心概念包括：

- Runtime Descriptor
- 开放 Capability Identifier
- Repository Provider
- Package Service Provider
- Application Service Provider
- Provider Health
- Compatibility State
- Diagnostics
- Provider Lifecycle
- 重连后的 Provider recomposition

## Runtime Service Bridge

Typed Runtime Service Bridge 可以连接已经获得授权的 Runtime，并向 Prism 提供：

- Runtime Descriptor
- Capability Registry
- Package Service
- Application Service
- Artifact Staging Service
- Background Runtime Service
- Health 与 Reconnect 状态
- 可选的 typed compatibility service

## Runtime 连接管理

- 启动时初始化
- 持续连接状态观察
- Health 状态报告
- 自动/状态驱动的重连处理
- 手动重连
- 后台服务 Capability 检查
- Diagnostics
- Global Log

## 兼容模式

### Modern

Runtime 原生服务优先。传统 basebin / bootstrap / APT 假设是可选兼容能力，而不是 Prism Core 的强制要求。

### Hybrid

Modern Runtime 保持主线，需要传统 Debian/APT 生态的任务再按需启用兼容层。

### Legacy

传统越狱环境可以通过兼容 Provider 使用 `prismd`、APT/dpkg 以及相关 bootstrap 组件。

## 应用管理

- 已安装应用模型
- 应用状态检查
- Registration / Refresh
- Repair
- Removal
- Runtime 管理的安装入口
- Artifact Staging Capability 检查
- Application Transaction Operation
- 应用真实状态校验
- Journal / Reconcile / Recovery 集成

## Commerce

Prism 提供由软件源自己管理的 Commerce / Entitlement Contract：

- 账号与支付流程由 Repository 负责
- Prism 只消费归一化授权状态
- Prism 不保存原始银行卡凭据
- 已拥有的软件包仍经过标准 Transaction 流程安装

## 诊断

- Runtime Bridge 状态
- Provider 状态
- Capability 状态
- Transaction History
- Recovery State
- Global Log
- 对实现敏感路径进行脱敏的 Diagnostics

## 本地化

- English
- 简体中文

## 安全模型

Prism 本身不负责获取越狱或系统权限。Prism 对外的高权限边界采用 typed、allowlisted 接口，而不是任意命令执行接口。
