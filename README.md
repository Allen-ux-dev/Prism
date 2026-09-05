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

完整功能说明请进入对应语言 README，或查看：

- [`docs/FEATURES.md`](docs/FEATURES.md)
- [`docs/RUNTIME-INTEGRATION.md`](docs/RUNTIME-INTEGRATION.md)

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
