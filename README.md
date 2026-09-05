# Prism 0.4.1 Core Contract Freeze — Build 52

Prism 是面向 **RELAXIN-X 下一代模块化 runtime** 的原生 iOS Package Platform。

它不再把 APT、dpkg、DEB、传统 bootstrap 或 `prismd` 当作全局前提。Prism Core 负责包模型、Repository abstraction、依赖解析、Plan、Transaction、Journal、Reconcile、Recovery 与 UI；实际 Runtime / Repository / Package Service 通过 Provider 接入。

核心原则：

- **Modern-first** — RELAXIN-X Modern Runtime 是主线。
- **Legacy-compatible** — Debian/APT/Sileo/Zebra/DEB 与旧 bootstrap 保留为兼容 Provider。
- **Provider-driven** — 新格式、新 runtime、新 package service 通过注册 Provider 扩展，不改 Core enum。
- **Transaction-safe** — 所有写操作必须经过 Plan → Transaction → Journal → Reconcile/Recovery。
- **Quiet-by-default** — 平时保持低干扰；不需要的兼容组件保持 Idle。

> 高权限或系统修改 Provider 只运行在已经获得授权的 jailbreak/runtime 环境中。Prism 不负责额外获得系统权限，也不向 UI/IPC 暴露任意 shell/任意命令接口。
>
> “Runtime Isolation / 环境隔离”用于减少日常使用干扰、隐藏无关实现细节和隔离 Provider 故障，不用于规避第三方安全检测。







## Build 52 — Complete Store

Build 52 completes Prism's provider-neutral store product layer without rewriting the frozen runtime/package cores. Featured now derives recommendations, categories, installed/update/source counts and recent activity from normalized store data. Packages gains combined search/category/source/install/commerce filters, deterministic sort, technical package details, dependency/conflict/requirement presentation and existing transaction-backed install/update/remove flows. Sources gains provider-neutral detail/status/trust/compatibility/search/refresh/removal. Apps is real-runtime-first: application state comes from the typed privileged bridge and Register / Repair / Remove submit normal Prism transactions; Simulation remains Advanced/Lab only. Activity is grouped into Pending / Running / Needs Review-Recovery / Failed / Completed.

The IPA import entry is capability-gated. Prism still does not contain a signing-bypass, privilege-acquisition, arbitrary shell, or arbitrary process-injection path; real artifact staging and platform execution are supplied by the RELAXIN-X Runtime Service Host contract.

## Build 51 — Runtime Application Service Bridge

Build 51 connects Build 50's application/injection provider model to a versioned typed Runtime Service Bridge. `prismd` can discover an already-authorized runtime service, negotiate protocol/capabilities, register remote application and injection providers, and recompose the backend/environment for the next transaction after an explicit reconnect. Runtime-native providers remain preferred and compatibility adapters remain fallback only.

The Settings UI adds an explicit **Runtime Background Service** switch. It is enabled only when the runtime advertises both `background-execution` and `privileged-service`; disabling it releases Prism's requested background session. Runtime disconnect/reconnect and background state changes are surfaced through typed status and the global log. Prism still does not implement jailbreak, privilege escalation, signature bypass, shell execution, raw process injection, or exploit chains.


## Build 50 — Application Runtime Wiring

Build 50 wires Prism application installation and injection into the Future-first runtime composition without changing the frozen package transaction core. Runtime-native application services are preferred, while TrollStore-style installation and TrollFools-style injection are compatibility adapters over already-authorized typed runtime services. Prism does not embed exploit, signing-bypass, shell, arbitrary-path, or raw-process logic. Application lifecycle operations now include install, replace, remove, register/refresh, and typed injection apply/remove, with existing Transaction → Journal → Reconcile semantics verifying actual application state.

## Build 49 — Future Wiring Pass

Build 49 hardens Prism's application wiring without redesigning the frozen package/transaction core. App startup is now runtime-aware and modern-first, legacy package service is an explicit compatibility fallback, repository loading resolves through provider probe/policy instead of directly owning a Sileo parser, presentation consumes runtime descriptors rather than product-name string checks, and the long-term capability contract uses open `CapabilityIdentifier` values with V1 enum adapters. Provider timeout/cancellation and repository failure isolation keep the catalog responsive, while transaction provider pinning and no-silent-write-fallback semantics remain unchanged.

Architecture Gate 4.0 rejects regressions such as default `compatibilityFactory`, hard-coded `.hybrid` startup, direct `SileoRepositoryProvider()` ownership in application catalog wiring, and runtime behavior decisions based on product-name strings.

## Build 48 — Sources 2.0 / Global Log / Commerce Contracts

Build 48 completes the current Prism UI/platform pass: repository detail pages with source-local search and confirmed removal, package icons across package surfaces, architecture-neutral Application Installation / Application Injection simulation copy, a bounded redacting global log, and source-owned commerce/entitlement contracts. Prism does not store card data or implement a wallet; paid repositories supply their own adapters, and owned packages still install through the normal InstallPlan → Transaction → Journal → Reconcile pipeline. Package Removal 2.0 from Build 47 remains unchanged.

## 0.4.1 Core Contract Freeze

0.4.1 completes the long-lived Prism/RELAXIN-X integration contracts before the Core freeze. The release adds runtime installation and ownership contracts, runtime integration/lifecycle state, protocol-range negotiation, Provider Registry/Resolver/Policy separation, decomposed package-service capabilities, package trust/provenance, non-destructive persistent schema migration, transaction-safe Prism/provider updates, provider/bridge conformance suites, and Architecture Gates 3.0.

Key guarantees:

- RELAXIN-X owns Runtime lifecycle; Prism owns the package ecosystem.
- Runtime-managed ownership blocks independent Prism self-replacement; updates are delegated to the owning runtime contract.
- Compatibility is multi-level (compatible / partial / degraded / unsupported / unknown), not a binary flag.
- Prism declares capabilities and never acquires system privilege by itself.
- Runtime-managed Prism updates are coordinated by the runtime installer contract.
- Write transactions pin provider identity/version/protocol and never silently switch providers.
- Update activation waits for a write-safe point and rolls back on activation/handshake/health failure.
- Persistent migration failures preserve old bytes and enter NeedsReview instead of clearing state.
- Unknown future runtime capabilities are ignored safely during handshake decoding.
- Provider failure is contained to that provider family; unrelated services remain usable.
- Ordinary UI remains implementation-detail free and keeps exactly five iPhone primary tabs.

## 0.4.0 Provider Runtime Upgrade

0.4.0 在 0.3.0 Future-Ready 基础上强化运行时 Provider 层，而不是重写 Package Core：

- `ProviderRegistry 2.0` 支持运行时 health/capability 刷新与诊断快照。
- RELAXIN-X 通过版本化 `RelaxinBridgeHandshake`、Runtime Descriptor 和 Package Service Descriptor 建立 Session。
- 写 Provider 必须声明至少一种安全恢复策略：`reconcile` / `rollback` / `safeAbort`。
- `PackageServiceSession` 负责锁定选中的 Provider；已确认事务不会因为 health 变化静默迁移到其他 Provider。
- Repository/Package format requirements 参与 Provider 选择；Modern 包不会偷偷回落到 Legacy daemon。
- Mock Package / Application Installation / Application Injection 模拟共用确定性的 fault/recovery harness，可复现失败、中断、degraded、rollback、safeAbort 和 reconcile。
- Settings 使用实时 Provider 状态；普通界面只显示任务相关状态，Advanced Diagnostics 才显示经过整理的 Provider ID、版本、协议、格式和 Recovery 信息。
- iPhone 仍严格保持 5 个一级入口，长状态文本采用纵向自适应布局。

## Future-Ready 架构

```text
Prism UI
   ↓
Application Layer
   ↓
Prism Domain
   ├── Package / PackageVersion / VersionScheme
   ├── PackageFormatIdentifier
   ├── Repository Abstraction
   ├── Resolver / BuildPlan / InstallPlan
   ├── Transaction / Journal
   └── Reconcile / Recovery
   │
   ├──── RepositoryProvider ──── ProviderRegistry
   │       ├── RelaxinModernRepositoryProvider
   │       ├── PrismNativeRepositoryProvider
   │       └── APTRepositoryProvider
   │
   └──── PackageServiceProtocol ── Service Provider
           ├── RelaxinRuntimeProvider        ← Modern
           ├── PrismDaemonProvider           ← Hybrid / Legacy
           └── MockPackageServiceProvider    ← Test / Simulation
```

### Prism Core 不再假设

- `.deb` 是唯一 package format
- `DebianVersion` 是唯一版本体系
- Repository 一定存在 `Release / Packages`
- `/var/jb` 一定存在
- bootstrap/root prefix/package DB 是 Environment 必填字段
- `prismd` 必须运行
- APT/dpkg 一定可用

## Package Model 2.0

### PackageVersion / VersionScheme

`PrismPackage.version` 使用开放的 `PackageVersion`：

```text
PackageVersion
└── VersionScheme
    ├── DebianVersionScheme
    ├── SemanticVersionScheme
    └── NativeVersionScheme
```

未知 VersionScheme 不会静默退化成普通字符串比较。

### PackageFormatIdentifier

Package format 使用开放字符串标识：

```text
org.debian.deb
dev.prism.source
dev.prism.native
dev.relaxin.package
```

未来增加格式无需修改 Prism Core enum。

## Repository Provider 2.0

统一 Provider 能力：

```text
refresh()
catalog()
package(id)
metadata()
health()
```

APT 特有逻辑完全下沉到 `APTRepositoryProvider`，包括：

- `Release`
- `Packages`
- `Packages.gz`
- Debian/Sileo metadata normalization
- 多行 Description
- Depends / Conflicts
- SileoDepiction / Icon
- Alternative Dependency `A | B`
- Last-known-good catalog snapshot

Prism Native / RELAXIN-X Modern Repository 不需要伪装成 APT 文件结构。

## Environment 2.0

Modern Environment 可以完全没有传统 bootstrap：

```text
PrismEnvironment
├── runtimeIdentity
├── runtimeVersion
├── architecture
├── osVersion / osBuild
├── capabilityReport
├── storageNamespace?
├── packageStore?
├── compatibilityLayers
└── legacy?
    ├── bootstrapIdentifier?
    ├── rootPrefix?
    └── packageDatabase?
```

Capability 使用四态：

```text
available
degraded(reason)
unavailable
unknown(reason?)
```

UI 不通过 jailbreak 产品名或 `/var/jb` 判断功能是否可用。

## 三种运行模式

### Modern — 默认主线

```text
RELAXIN-X Modern Runtime
+
Modern Repository / Package Service Provider
+
Prism
```

无需独立 `prismd` 或传统 APT/bootstrap 才能成为合法 Prism 环境。

### Hybrid — 生态迁移

```text
RELAXIN-X Modern Runtime
+
Legacy DEB/APT Compatibility Provider（按需）
+
Prism
```

兼容层只有需要时才激活。

### Legacy — 兼容模式

```text
Legacy Runtime / Bootstrap
+
PrismDaemonProvider
+
prismd
+
APT / dpkg
```

仍受支持，但 UI 不把它作为推荐主线。

## PackageServiceProtocol

Prism Application Layer 面向统一服务契约：

```text
activate / deactivate
queryEnvironment
queryCapabilities
inspectPackageState
inspectApplicationState
resolve
prepare
execute
reconcile
rollback
safeAbort
syncRepositorySources
```

`prismd` 只是 `PrismDaemonProvider` 的实现细节，不再是 Prism Core 的中心。

## Transaction 2.0

主要状态：

```text
Created
→ Preparing
→ Resolving
→ Ready
→ Executing
→ Reconciling
→ Completed
```

恢复相关状态：

```text
Interrupted
NeedsRecovery
RollingBack
RolledBack
NeedsReview
Failed
Cancelled
```

规则：

- 所有写操作进入 Transaction。
- Provider identity/version 写入 Journal。
- Recovery token 对 Prism Core 保持 opaque。
- runtime/App 重启后先读取 Journal。
- Recovery 必须先 inspect actual state。
- Provider 不匹配时进入 NeedsReview，不静默切换 Provider 重放旧操作。
- 已完成 Operation 不重复执行。

## Runtime Isolation / Daily Experience

正常设置只显示：

```text
Runtime
Package Service
Compatibility
Background
```

普通 UI 不显示：

- root prefix
- package database path
- daemon socket path
- apt/dpkg tool path
- bootstrap 实现细节

Advanced Diagnostics 可以读取这些 Provider-private 信息用于诊断，但路径会脱敏。

Modern 模式默认：

- Legacy compatibility：Idle
- Source build：Idle
- Injection service：Idle
- Diagnostics：Idle

只有真实任务需要时才激活相应组件。

## Apps / 白巨魔类 / TrollFools 类能力

Prism 已有统一 Domain：

- `PrismInstalledApp`
- `IPAInspectionSnapshot`
- `AppInstallPlan`
- `InjectionArtifact`
- `InjectionPlan`
- typed App/Injection Transaction Operation
- Journal / Reconcile / Recovery

### Safe Simulation Lab

V0.3 内置两个**非破坏性模拟 Provider**：

- `MockTrollStoreStyleProvider`
- `MockTrollFoolsStyleProvider`

Apps → **Safe Simulation Lab** 可以实际运行：

```text
模拟 IPA 安装
→ AppInstallPlan
→ Transaction
→ Journal
→ Reconcile
→ Mock Installed App

模拟 dylib 注入
→ InjectionPlan
→ Transaction
→ Journal
→ Reconcile
→ Mock Injection State

模拟移除
→ Transaction
→ Reconcile
```

它们使用真实 Prism Transaction 架构，但只修改隔离的 Mock App State，**不会修改真实 App Bundle**。

真实 RELAXIN-X App Installer / Injection Provider 将来可以替换 Mock Provider，而不需要重写 UI 或 Transaction Core。

## UI 信息架构

### iPhone

一级 Tab 永久限制为 5 个：

```text
Featured
Packages
Sources
Apps
Activity
```

- Installed / Updates → Packages 内部
- Queue / Transaction History → Activity
- Settings → Toolbar

### iPad / Regular Width

Sidebar：

- Featured
- Packages
- Sources
- Apps
- Installed
- Updates
- Activity
- Settings

### 布局原则

- 指标卡使用 adaptive grid，不固定大宽度。
- 长状态与 Capability reason 允许多行。
- 重要按钮最小 44pt 交互高度。
- 普通状态与 Advanced Diagnostics 分层。
- Deployment Target 锁定 iOS 15.0；禁止无保护引入较新 Navigation API。

## 软件源兼容

当前已实现：

- Debian/APT Packages metadata
- Sileo 常见扩展字段
- Sileo/Zebra 常见 APT Repository 数据模式
- `Packages`
- `Packages.gz`
- Last-known-good catalog
- Alternative Dependency

Legacy Repository 进入 Prism 后会归一化成 Prism Domain；UI 不直接消费 APT 原始字段。

## 构建与验证

完整门禁：

```bash
./Scripts/VerifyPrismProviderRuntime.command
```

它会检查：

- Swift Core / Integration tests
- `prismd` compatibility executable build
- hard-coded jailbreak root boundary
- typed privileged API boundary
- Future-Ready Provider architecture
- iPhone 5-tab UI contract
- legacy implementation detail leak
- iOS 15 source/API gate
- large fixed-width UI gate
- AppIcon catalog dimensions
- Xcode project version / package linkage / shared scheme
- 在 macOS + Xcode 环境自动执行 iOS Simulator `xcodebuild`

当前工程：

```text
Prism.xcodeproj
Scheme: Prism
Deployment Target: iOS 15.0
Version: 0.4.1
Build: 52
```

本仓库执行环境若没有 Xcode/iOS SDK，只能验证 Swift Core、`prismd`、SwiftUI syntax/static gates 和 Xcode project structure；Apple SDK 最终编译必须在 macOS/Xcode 环境再跑同一个 gate。

## 设计与实施文档

- `docs/superpowers/specs/2026-09-04-prism-provider-runtime-upgrade-design.md`
- `docs/superpowers/plans/2026-09-04-prism-provider-runtime-upgrade-implementation-plan.md`
- `docs/superpowers/specs/2026-09-04-prism-future-ready-package-platform-design.md`
- `docs/superpowers/plans/2026-09-04-prism-future-ready-implementation-plan.md`
- 旧 V1 设计/计划继续保留用于迁移历史。

## 一键编译

macOS 上解压源码后，可以直接双击项目根目录的：

```text
Build.command
```

也可以在终端运行：

```bash
./Build.command
```

脚本会按顺序：

1. 检查完整 Xcode 环境；
2. 运行 `Scripts/VerifyPrismCoreFreeze.command`；
3. 编译 Release iPhoneOS `Prism.app`；
4. 打包未签名 IPA；
5. 编译 Release iOS Simulator `Prism.app`；
6. 只有全部成功后才原子更新 `dist/latest`。

成功产物位于：

```text
dist/latest/
├── Prism-<version>-Build<build>-unsigned.ipa
├── Prism-device.app
├── Prism-simulator.app
└── BUILD-INFO.txt
```

`Build.command` 不写死 Apple Team ID，也不会自动使用个人签名身份。IPA 会保持未签名状态，方便在你自己的已授权签名/测试环境中继续处理。

如果编译失败，`dist/latest` 会继续指向上一次成功构建；失败日志保存在 `dist/logs/`。


## Build 42 — Xcode 26.6 Darwin compatibility fix

Build 42 fixes the Darwin Swift import of `posix_spawn_file_actions_t` in `PosixSpawnPackageToolRunner`. Darwin uses an opaque optional handle while Glibc exposes a directly initializable value. The runner now uses a platform-specific declaration and keeps the shared typed execution path unchanged. `VerifyDarwinPosixSpawn.command` is included in the Core Freeze release gate so this platform mismatch cannot silently regress.

## Build 43 — Xcode 26.6 Simulator destination/link fix

Build 43 fixes the Xcode verification step choosing `My Mac` while compiling the Prism app with the iPhone Simulator SDK. `VerifyXcodeProject.command` now uses the explicit destination `generic/platform=iOS Simulator` and a disposable DerivedData directory. This keeps Swift Package products and the app target in the same `Debug-iphonesimulator` build graph and prevents the linker from looking for package object files in `Build/Products/Debug`. `VerifyXcodeDestination.command` is included in the Core Freeze gate to prevent this regression.


## Build 47 — Package Removal 2.0

Build 47 adds a transaction-safe package removal pipeline with two explicit modes: **Remove** keeps package-manager-managed persistent configuration where applicable, while **Complete Removal** uses the provider's purge path and re-checks package state after execution. The removal planner previews every package scheduled for removal, preserves shared or unproven dependencies by default, surfaces unavailable capabilities before execution, and records purge operations as typed transaction operations with journal schema version 3. The iPhone package detail view now exposes Remove / Complete Removal with a dedicated review sheet and bilingual warnings before confirmation.
