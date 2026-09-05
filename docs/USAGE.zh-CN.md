# Prism 使用指南

[English](USAGE.en.md) | [简体中文](USAGE.zh-CN.md)

本文档介绍 Prism 在受支持的开发、越狱或已经获得授权的 Runtime 环境中的正常使用方式。

> Prism 本身不负责获取越狱或系统权限。依赖 Runtime 的功能只有在当前环境已经提供对应 Capability 时才会启用。

## 1. 安装 Prism

选择与当前 Prism 版本对应的 Release IPA，并通过你的设备已经支持的开发、签名或 Runtime 工作流完成安装。

公开 Release 中的 IPA 可能是未签名版本；签名和安装方式取决于你本来就在使用的环境。

## 2. 首次启动

首次启动后，Prism 会初始化软件包与 Runtime 状态，并进入主商店界面。

iPhone 上有五个一级入口：

- **Featured**
- **Packages**
- **Sources**
- **Apps**
- **Activity**

Runtime、兼容模式和诊断相关设置集中在 Settings 中。

## 3. Runtime 连接

Prism 支持不同 Runtime 模式。

### Modern

Modern Runtime 可以通过 Runtime Service Bridge 直接向 Prism 提供原生的软件源、软件包和应用服务。

在这一模式下，Prism Core 不把 `basebin`、APT、dpkg、`prismd`、`/var/jb` 或固定 bootstrap 目录作为强制依赖。

### Hybrid

Modern Runtime 继续作为主线；只有当某个软件包或软件源确实需要 Debian/APT 兼容时，才启用兼容 Provider。

### Legacy

传统环境可以通过 `prismd` 与 APT/dpkg 兼容 Provider 提供软件包操作能力。

### 查看连接状态

Prism 会持续跟踪 Runtime/helper 的连接状态、Health 与 Capability。如果服务不可用，可以在 Settings 的 Runtime/连接区域查看状态并请求重新连接。

## 4. 添加和刷新软件源

进入 **Sources** 管理软件源。

常见流程：

1. 添加受支持的软件源 URL。
2. 刷新软件源。
3. 等待 metadata 归一化并更新 Catalog。
4. 打开软件源浏览或搜索软件包。

Prism 通过兼容 Provider 支持 Debian/APT 软件源布局以及常见 Sileo/Zebra metadata 模式。

## 5. 浏览和搜索软件包

进入 **Packages** 可以：

- 按软件包名称或 metadata 搜索
- 按 Category 筛选
- 按 Source 筛选
- 按 Installed / Update 状态筛选
- 查看版本、架构、依赖和冲突
- 查看当前选择的 Provider / Environment 状态

## 6. 安装或更新软件包

当你请求安装或更新时，Prism 会先生成 Plan，再进入写操作。

```text
Plan
→ Transaction
→ Journal
→ Execute
→ Inspect Actual State
→ Reconcile
→ Complete / Recovery / Needs Review
```

执行前应先查看依赖、冲突和最终动作。

真正的执行后端由当前 Runtime Provider 决定。Modern 环境可以使用 Runtime 原生 Package Service；兼容 Legacy 环境可以通过 Provider 使用 APT/dpkg。

## 7. 删除或 Purge 软件包

删除同样使用统一 Transaction 系统。

- **Remove**：按当前 Provider 的正常删除语义移除软件包。
- **Purge**：在后端支持时，还可以请求删除由该软件包管理的配置。

执行结束后 Prism 会检查真实状态并进行 Reconcile。

## 8. Apps

进入 **Apps** 可以查看由当前 Runtime 提供的应用状态。

根据 Runtime 实际声明的 Capability，Prism 可以提供：

- Register / Refresh
- Repair
- Remove
- Runtime 管理的安装请求
- Artifact Staging

如果 Runtime 没有提供某项能力，Prism 会保持该能力不可用，而不会把模拟行为伪装成真实设备操作。

## 9. Activity

进入 **Activity** 查看事务状态。

Prism 会把任务分组为：

- Pending
- Running
- Needs Review / Recovery
- Failed
- Completed

如果某个操作发生中断，应先查看对应 Activity 记录，再进行其他修复操作。

## 10. Recovery

Recovery 依据已记录的 Transaction 和设备真实状态进行。

在 Provider 支持时，Prism 可以使用：

- Reconcile
- Rollback
- Safe Abort
- Needs Review

Prism 不会把一个中断的写事务静默切换到另一个 Provider 重新执行。

## 11. Diagnostics

遇到以下问题时，可以进入 Settings / Diagnostics：

- Runtime Bridge 连接状态
- Provider Health
- Capability Availability
- Background Service 状态
- 软件源刷新失败
- Transaction / Recovery 状态
- Global Log

导出 Diagnostics 时，实现敏感路径应进行脱敏。

## 12. 语言

Prism 已提供：

- English
- 简体中文

## 相关文档

- [完整功能](FEATURES.zh-CN.md)
- [Runtime 集成](RUNTIME-INTEGRATION.zh-CN.md)
- [仓库 README](../README.zh-CN.md)
