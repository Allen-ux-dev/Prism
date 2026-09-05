# RELAXIN-X Full Upgrade Specification
## Prism Build 49 → Build 52 · Runtime / Store / Compatibility Integration

> Target: RELAXIN-X Runtime + Prism 0.4.1 Build 52+
>
> Purpose: 将此前 Future Wiring、Application Runtime Wiring、Runtime Service Bridge、TrollStore/TrollFools-style compatibility、Package/Repository/Commerce、Complete Store 的升级要求合并为一份最终实施规格。
>
> Core principle: **RELAXIN-X provides capabilities. Prism organizes capabilities.**
>
> Prism-facing API 不暴露 exploit chain、签名绕过实现、任意 shell、任意 PID/loader、任意内核操作或任意高权限文件写入接口。RELAXIN-X 已经拥有并授权的平台能力，只通过 allowlisted typed service 暴露给 Prism。

---


# 1. 版本演进总览

```text
Build 49  Future Wiring
  Open CapabilityIdentifier
  Runtime-aware composition
  Repository Provider Resolver
  Runtime-neutral Presentation

Build 50  Application Runtime Wiring
  Native / Compatibility Application Providers
  Typed Install / Register / Replace / Remove / Refresh
  Typed Injection compatibility
  Provider pinning

Build 51  Runtime Service Bridge
  Runtime Discovery
  Versioned Handshake
  Typed IPC
  Remote Provider Registration
  Disconnect / Reconnect
  Background Runtime Control

Build 52  Complete Store
  Full Featured / Packages / Sources / Apps / Activity
  Runtime-first Apps
  Real Register / Repair / Remove transactions
  Store filters/details
  Activity / Recovery product layer
```

RELAXIN-X 下一阶段的中心任务是实现真正的 `Runtime Service Host`，而不是要求 Prism 再增加产品名分支。

---

# 2. 最终架构

```text
Prism Complete Store
        │
Store Presentation / Coordinator
        │
Prism Core Contracts
        │
Runtime Service Bridge
        │
Typed IPC / Handshake
        │
RELAXIN-X Runtime Service Host
        │
 ┌──────┼────────┬─────────┬──────────┐
App   Artifact  Package  Background  Injection
Svc   Staging   Service   Service     Service
        │
RELAXIN-X Internal Backend
```

Prism 负责发现、规划、事务、日志、恢复和 UI；RELAXIN-X 负责执行它已经拥有的平台能力。

---

# 3. Core Freeze

原则上冻结并继续复用：

```text
PrismRuntimeInstallerProtocol
RuntimeDescriptor
CapabilityIdentifier
ProviderRegistry / Resolver / Policy
PackageServiceSession
Package Service State / Planning / Execution / Recovery
PrismTransaction
Journal
Reconcile
Recovery
Installation Ownership
Repository normalized model
Commerce contracts
Runtime Service Bridge protocol family
```

新增功能优先新增 Capability / Service / Provider / Adapter，而不是重写这些 Core。

---

# 4. Modern First / Legacy On Demand

```text
Native provider
  ↓ preferred
Compatibility provider
  ↓ only when native unavailable
Unavailable
  ↓ explicit
```

Active transaction 一旦开始，Provider 必须 pin。禁止中途静默切到 legacy provider。

---

# 5. Runtime Descriptor V2

推荐字段：

```swift
struct RuntimeDescriptor: Codable, Sendable {
    let runtimeIdentity: String
    let displayName: String
    let runtimeVersion: String
    let protocolRange: ProtocolRange
    let operatingMode: RuntimeOperatingMode
    let capabilities: [CapabilityState]
    let services: [RuntimeServiceDescriptor]
}
```

`runtimeIdentity` 必须稳定；Prism 不允许通过名称字符串判断行为。

---

# 6. Runtime Operating Mode

建议标准化：

```text
modern
hybrid
legacy
readOnly
degraded
unknown
```

模式来自 Runtime Descriptor 和真实 provider health，不从产品名推断。

---

# 7. Open CapabilityIdentifier

继续使用开放标识：

```swift
struct CapabilityIdentifier: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String
}
```

RELAXIN-X 可发布 `dev.relaxin.capability.*` 扩展。

规则：

```text
unknown optional → preserve
unknown required → explicit incompatible
known alias → normalize/merge
```

---

# 8. Prism 标准能力

建议至少支持/识别：

```text
dev.prism.capability.package-service
dev.prism.capability.repository-networking
dev.prism.capability.app-artifact-staging
dev.prism.capability.app-inspection
dev.prism.capability.app-install
dev.prism.capability.app-registration
dev.prism.capability.app-replace
dev.prism.capability.app-removal
dev.prism.capability.app-refresh
dev.prism.capability.app-injection
dev.prism.capability.injection-removal
dev.prism.capability.background-execution
dev.prism.capability.privileged-service
dev.prism.capability.lifecycle-recovery
dev.prism.capability.service-registration
dev.prism.capability.package-store-access
```

只有后端真实可用时才声明 `available`。

---

# 9. CapabilityState

```text
available
degraded
unavailable
unknown
```

每项能力可带 version 与非敏感 metadata。UI 根据真实 state 启用/禁用功能。

---

# 10. Legacy Capability Alias

历史环境可能同时出现 `appInstall` / `ipaInstall`，二者都映射到 `app-install`。必须 merge，不能假设来源唯一。

推荐可用性优先级：

```text
available > degraded > unknown > unavailable
```

---

# 11. Runtime Service Descriptor

推荐：

```swift
struct RuntimeServiceDescriptor: Codable, Sendable {
    let serviceID: String
    let serviceVersion: Int
    let capabilities: [CapabilityState]
    let health: RuntimeServiceHealth
    let providerKind: ProviderKind
}
```

`serviceID` 应跨重连稳定。

---

# 12. Provider Kind / Identity

ProviderKind：

```text
native
compatibility
readOnly
simulation
```

Compatibility Adapter 不修改底层稳定 provider ID；adapter kind 单独记录。Simulation 永远不能被解析成真实设备 provider。

---

# 13. Runtime Service Discovery

```text
Prism/prismd
→ Discovery
→ Endpoint Descriptor
→ Connect
→ Handshake
→ Provider registration
```

UI 不知道真实 socket / daemon / bootstrap 路径。

---

# 14. Protocol Version Negotiation

Client 与 Runtime 各提供 min/max protocol，协商最高共同版本。无交集必须返回明确 `protocolIncompatible`，不能静默 fallback 到旧写入路径。

---

# 15. Handshake

握手至少返回：

```text
Runtime Identity
Runtime Version
Negotiated Protocol
Operating Mode
Capabilities
Service Descriptors
Provider Descriptors
Background State
Health
```

失败时明确 unavailable/degraded。

---

# 16. Health

至少：

```text
healthy
degraded
unavailable
recovering
stopping
```

Health 应反映 transport、service、backend、registration subsystem，而不只是“进程存在”。

---

# 17. Disconnect / Reconnect

断开：

```text
detect
→ unregister affected remote providers
→ mark unavailable
→ preserve active journal
→ no silent provider switch
```

重连：

```text
fresh discovery
→ fresh handshake
→ fresh capabilities
→ fresh services
→ recompose next transaction
```

---

# 18. Timeout / Cancellation

分别支持 discovery / connect / handshake / operation / health / repository timeout。

长操作至少可处理 cancellation；如果当前阶段不能安全取消，返回明确 non-cancellable state，而不是硬中止。

---

# 19. Typed Error Contract

建议统一：

```text
unsupportedCapability
protocolIncompatible
runtimeUnavailable
providerUnavailable
artifactInvalid
artifactUnavailable
operationRejected
operationTimedOut
operationCancelled
stateMismatch
registrationFailed
recoveryRequired
rollbackUnavailable
```

---

# 20. TrollStore 架构映射

上传的 TrollStore 源码中可吸收的是成熟的职责分层，而不是把底层漏洞/绕过实现暴露给 Prism。

| TrollStore 职责 | RELAXIN-X / Prism 映射 |
|---|---|
| `TSInstallationController` | Prism InstallPlan/Transaction 协调 |
| `TSApplicationsManager` | Runtime Application Service / app inspection |
| RootHelper 的 helper/client 分离 | RELAXIN-X Runtime Service Host |
| app enumeration | `inspectApplications()` |
| registration/refresh | typed `register` / `refresh` |
| archive intake | controlled Artifact Staging Service |
| install/remove status | typed AppOperationResult |

Prism-facing contract 明确排除 exploit-specific、签名绕过、raw root command、raw kernel primitive、任意路径/进程控制 API。

---

# 21. TrollStore-style Compatibility Adapter

兼容层只表达：

```text
install
register
```

旧 backend 如果继续使用，由 RELAXIN-X 内部 adapter 映射成 `RuntimeApplicationService`。Prism 不依赖产品名。

---

# 22. TrollFools-style Compatibility Adapter

兼容层只表达：

```text
inspect
apply
remove
```

Prism API 不暴露任意 PID、任意 loader 参数、任意 shell。没有真实 capability 时必须 unavailable。

---

# 23. Runtime Application Service

推荐接口：

```swift
protocol RuntimeApplicationService: Sendable {
    func inspectApplications() async throws -> [RuntimeApplicationState]
    func install(artifact: AppArtifactReference,
                 request: AppInstallRequest) async throws -> AppOperationResult
    func register(bundleIdentifier: String) async throws -> AppOperationResult
    func replace(artifact: AppArtifactReference,
                 request: AppReplaceRequest) async throws -> AppOperationResult
    func remove(bundleIdentifier: String) async throws -> AppOperationResult
    func refresh(bundleIdentifier: String) async throws -> AppOperationResult
}
```

Prism owns transaction semantics；RELAXIN-X owns platform execution。

---

# 24. Runtime Application State

建议包含：

```text
bundleIdentifier
displayName
version
build
architecture
minimumOS
registrationState
installationSource
runtimeManaged
health
```

Build 52 Apps 页面直接消费规范化状态。

---

# 25. Artifact Staging Service

Build 52 真正的 IPA Import 需要：

```text
stage
inspect
discard
```

Prism 不传任意 privileged path，而只获得 opaque `AppArtifactReference`。

---

# 26. AppArtifactReference

建议最小字段：

```text
artifactID
displayName
expectedBundleIdentifier
contentDigest
format
size
expiresAt(optional)
```

真实内部路径留在 Runtime。

---

# 27. Artifact Inspection

返回：

```text
bundleIdentifier
displayName
version/build
supportedArchitectures
minimumOS
format
digest
validationState
```

可安全吸收成熟安装器对 archive 结构、metadata、架构、版本兼容、冲突和 digest 的检查思想。

---

# 28. Install Flow

```text
Stage
→ Inspect
→ Prism InstallPlan
→ Prism Transaction
→ Runtime install
→ Runtime register
→ actual-state query
→ Reconcile
→ Commit
```

Runtime 不替 Prism 写 Journal/Commit。

---

# 29. Register

`register(bundleIdentifier)` 是独立操作，用于 payload 已存在但 registration missing/stale 的情况。执行后必须支持 actual-state query。

---

# 30. Replace / Update

同 Bundle ID 更新应使用 Replace 语义：

```text
existing state + staged artifact
→ Replace Plan
→ Transaction
→ replace
→ registration verification
→ actual-state query
→ reconcile
```

---

# 31. Remove

`remove(bundleIdentifier)` 只代表 Application removal。它与 package/tweak 的 Remove/Purge 是两套 ownership，不能混用。

---

# 32. Refresh / Repair

用于 registration/metadata/runtime state 不一致。Build 52 UI 使用 Repair/Refresh，高层对应 typed `refresh(bundleIdentifier)`。

---

# 33. AppOperationResult

建议至少返回：

```text
operationID
status
bundleIdentifier
previousState
resultingState
warnings
```

helper 返回 success 后，Prism 仍会 actual-state reconcile。

---

# 34. Application Registration Service

RELAXIN-X 内部可把注册机制独立成模块，但 Prism-facing 仍只看到 `register` 与 `refresh`。内部实现变化不应要求 Prism 改接口。

---

# 35. Runtime Injection Service

可选：

```swift
protocol RuntimeInjectionService: Sendable {
    func inspect() async throws -> [InjectionState]
    func apply(_ request: InjectionRequest) async throws -> InjectionResult
    func remove(_ identifier: String) async throws -> InjectionResult
}
```

没有实际支持时 UI unavailable。

---

# 36. Background Runtime Service

Prism Settings 开关只有同时存在：

```text
background-execution
privileged-service
```

才可开启。

---

# 37. Background Contract

```swift
protocol RuntimeBackgroundService: Sendable {
    func startSession() async throws -> BackgroundSessionState
    func stopSession() async throws -> BackgroundSessionState
    func currentState() async throws -> BackgroundSessionState
}
```

状态至少 inactive/starting/active/stopping/degraded/unavailable。

---

# 38. Background Meaning

开关仅表示保持已经授权的 Runtime service session，不表示 Prism 获取新的系统权限。断线立即 degraded/unavailable；重连必须 fresh handshake。

---

# 39. Runtime Package Service

继续保持：

```text
State
Planning
Execution
Recovery
```

Application Service 不绕过 Package Transaction。

---

# 40. Package Identity / Version

本轮不重写 PackageVersion、PackageFormatIdentifier、依赖身份和已稳定的 package identity semantics。

---

# 41. Package Planning

Prism 继续负责 Install/Update/Remove/Purge plan、dependency/conflict preview；Runtime 只执行批准后的 typed package operation。

---

# 42. Package Removal 2.0

保留 Remove 与 Complete Removal/Purge、preview、dependency preservation、orphan-safe behavior、post-operation verification。

---

# 43. Repository Provider

```text
Registry
→ Probe
→ Resolver
→ Provider
→ PrismRepository / PrismPackage
```

UI 不知道 APT 的 Release/Packages 实现细节。

---

# 44. APT / Sileo / Zebra Compatibility

继续作为 first-class fallback：

```text
APT/Sileo/Zebra-compatible sources
DEB
Release/Packages metadata
Depends/Conflicts
Architecture
SHA256
Icon
Depiction
```

---

# 45. Modern Repository

RELAXIN-X 新源格式通过独立 Modern Provider 转成 normalized Prism models；Store UI 不做源格式分支。

---

# 46. Repository Probe Isolation

Probe 支持 timeout/cancellation/failure isolation。单个坏源不能拖垮整套刷新。

---

# 47. Trust / Provenance / Visuals

继续提供 normalized trust、provider/distribution、source、icon、depiction 等 metadata，供 Build 52 详情页展示。

---

# 48. Complete Store – Featured

Featured 消费 normalized snapshot：

```text
packages
sources
installed
updates
runtime
recommendations
categories
recent activity
```

RELAXIN-X 只提供数据，不控制 UI。

---

# 49. Complete Store – Packages

支持 category/source/install-status/commerce filters、sort、search。详情页包含 author/version/architecture/category/source/trust/distribution/dependencies/conflicts/requirements/commerce/install state。

---

# 50. Complete Store – Sources

源详情需要 provider identifier、refresh state、trust、compatibility、last refresh、summary、package count、source-local search、refresh、remove confirmation。

---

# 51. Complete Store – Apps

Build 52 是 real-runtime-first：

```text
Inspect
Import IPA
Install
Replace
Register
Repair/Refresh
Remove
```

Simulation 仅位于 Advanced/Lab。

---

# 52. Complete Store – IPA Import

完整真实链：

```text
select IPA
→ artifact staging
→ inspection
→ plan
→ transaction
→ RuntimeApplicationService
→ registration
→ verify
→ activity
```

没有 artifact-staging capability 时，Import 明确 unavailable。

---

# 53. Complete Store – Activity

统一：

```text
Pending
Running
Completed
Failed
Needs Review / Recovery
```

Package/App 都映射到 PrismTransaction，不创建第二套任务数据库。

---

# 54. Complete Store – Recovery

失败后：

```text
query actual state
→ reconcile
→ resume / rollback / safe abort / needs review
```

Activity 只展示 Core Recovery 结果。

---

# 55. Commerce

保留 PurchaseProvider / EntitlementProvider / RepositoryCommerceProvider。

```text
Free
Paid
Owned
Sign In Required
Unavailable
```

购买归 source/provider；Prism 和 Runtime 不存银行卡/CVV。Owned 后仍走普通 InstallPlan。

---

# 56. Installation Ownership

继续：

```text
standalone
runtimeManaged
legacyMigrated
external
```

Runtime-managed Prism 的 self-update 必须尊重 ownership。

---

# 57. Runtime Installer 与 App Installer 分离

`PrismRuntimeInstallerProtocol` 管理 Prism/Runtime 生命周期；`RuntimeApplicationService` 管理用户 App。不要因为都叫 install 就合并。

---

# 58. Transaction Boundary

```text
Prism owns Transaction / Journal / Reconcile / Recovery.
RELAXIN-X owns platform operation execution.
```

Runtime 不私自 commit、重写 journal、换 pinned provider、跳过 reconcile。

---

# 59. Journal Boundary

Runtime 可以返回 operationID/providerID/runtime token/result/state snapshot/warnings，但不要求 Prism 保存 Runtime 私有数据库结构。

---

# 60. Reconcile

reported success 后必须 query actual state。Expected 与 actual 不一致 → Needs Review / Recovery。

---

# 61. Recovery

Runtime 支持 inspect actual state、resume if safe、rollback if supported、safe abort。无法 rollback 时明确 `rollbackUnavailable`。

---

# 62. Provider Pinning

Transaction 开始后 provider ID 固定到 Commit/Abort/Recovery 完成。重连出来的新 provider 只服务下一笔事务。

---

# 63. Runtime Upgrade During Transaction

Active transaction 时 defer provider replacement；达到安全点后 finish/recover，再 restart/handshake/recompose。

---

# 64. ProviderOperationContext

建议关联 operationID、deadline、cancellationID，让 Runtime 操作能与 Journal、Global Log、timeout/cancel 对齐。

---

# 65. Structured Logging

事件建议：

```text
Runtime Connected/Disconnected
Handshake Failed
Capability Changed
Provider Degraded
App Operation Started/Completed/Failed
Background Started/Stopped
Repository Refresh Failed
Recovery Required
```

---

# 66. Log Redaction

过滤 password/token/secret/authorization/cookie/credential/private session material/raw privileged backend argument。

---

# 67. 推荐 RELAXIN-X 模块布局

```text
RuntimeDescriptor
CapabilityRegistry
RuntimeHealth
ServiceHost/
  Discovery
  Handshake
  Transport
  Reconnect
ArtifactStagingService/
ApplicationService/
ApplicationRegistrationService/
InjectionService/
BackgroundService/
PackageService/
RepositoryProvider/
Compatibility/
  LegacyCapabilityAdapter
  LegacyApplicationAdapter
  LegacyInjectionAdapter
  LegacyRepositoryAdapter
```

---

# 68. Startup / Shutdown

Startup：

```text
initialize backend
→ probe capabilities
→ start service host
→ publish descriptors
→ discovery ready
→ Prism handshake
```

Shutdown：

```text
mark stopping
→ reject new operations
→ safely finish/hold active work
→ close transport
→ Prism marks provider unavailable
```

---

# 69. Runtime Capability Changes

运行时 capability 改变可发布新状态，但 active transaction 不变；下一笔事务才重新 resolver。

---

# 70. Build 49 Compatibility

继续满足 Modern First、Legacy On Demand、Open Capability、Provider Policy、Repository Resolver、Runtime-neutral Presentation、No Silent Write Fallback。

---

# 71. Build 50 Compatibility

继续满足 Runtime Native Application Provider、Compatibility Application/Injection Adapter、Install/Register/Replace/Remove/Refresh、provider-pinned transaction。

---

# 72. Build 51 Compatibility

继续满足 Typed IPC、Discovery、Versioned Handshake、Remote Provider Registration、Disconnect/Reconnect、Background Runtime Control、fresh capability composition。

---

# 73. Build 52 Compatibility

提供 Complete Store 所需 normalized package/source/app/runtime/commerce/activity 数据。Runtime 不返回 SwiftUI model，也不依赖 Store UI。

---

# 74. Simulation Isolation

Mock/Simulation providers 保留测试能力，但必须标记 simulation；真实 Resolver 不得自动选择它们。

---

# 75. Read-Only / Partial Capability

只可 inspect/browse 时进入 readOnly/degraded。基础完整 App 安装链至少需要 `app-install + app-registration`。缺一项不能宣称完整安装 ready。

---

# 76. Service Independence

允许 Native Application + legacy Package、Application available + Injection unavailable、Modern Runtime + APT/Sileo/Zebra sources。各 provider 独立解析。

---

# 77. Migration Phase 1

先完成 Descriptor V2、Capability Registry、alias merge、ServiceDescriptor、Health。不要一开始同时改全部 backend。

---

# 78. Migration Phase 2

完成 Discovery、Transport、Handshake、Protocol Range、Health、Reconnect，并先验证稳定 connect/disconnect。

---

# 79. Migration Phase 3

完成 Artifact Staging、Application Inspection、Install/Register/Replace/Remove/Refresh，并接 Build 51/52 Bridge。

---

# 80. Migration Phase 4

回归 Package Service、APT/Sileo/Zebra、Modern repository、Trust/Provenance、Icons。

---

# 81. Migration Phase 5

实现 Background Service 与 capability gating，再启用完整后台体验。

---

# 82. Migration Phase 6

仅在真实支持时实现 typed Injection Service，否则保持 unavailable。

---

# 83. Migration Phase 7

验证 Commerce/Entitlement 与 Complete Store 流程，Paid/Owned 后继续走 normal InstallPlan。

---

# 84. Protocol Tests

至少：

```text
HandshakeNegotiatesHighestCommonVersion
ProtocolMismatchIsExplicit
UnknownOptionalCapabilityRoundTrips
UnknownRequiredCapabilityIsExplicit
LegacyAliasesMerge
ProviderIdentityStable
ReconnectPublishesFreshCapabilities
```

---

# 85. Application Tests

至少：

```text
InspectApplicationsReturnsNormalizedState
ArtifactStageReturnsOpaqueReference
ArtifactInspectionReturnsIdentity
Install/Register/Replace/Remove/Refresh typed result
RejectedOperationNeverReportsSuccess
TimeoutIsTyped
CancellationIsTyped
```

---

# 86. Transaction / Recovery Tests

至少：

```text
ProviderPinnedDuringTransaction
DisconnectDoesNotSilentlySwitch
ReportedSuccessRequiresStateVerification
StateMismatchTriggersRecovery
RollbackUnavailableExplicit
ReconnectAffectsNextTransactionOnly
```

---

# 87. Background Tests

至少：

```text
RequiresBackgroundExecution
RequiresPrivilegedService
StartActive
StopInactive
DisconnectUnavailable
ReconnectFreshHandshake
```

---

# 88. Repository / Package Regression

继续覆盖 APT/Sileo/Zebra/Modern source、provider probe、timeout/cancel/failure isolation、DEB/dependencies/conflicts/architecture/install/update/remove/purge/journal/recovery。

---

# 89. Store Tests

至少：

```text
FeaturedNormalizedData
PackageFiltersAndSort
PackageDetailMetadata
SourceDetailMetadata
RuntimeFirstApps
SimulationOnlyAdvancedLab
RegisterRepairRemoveUseTypedTransaction
ActivityBucketsMapTransactionState
ExactlyFiveRootTabs
```

---

# 90. Release Matrix

至少测试：

```text
A Modern Runtime + Native App + Native Package + Background
B Modern App + APT/Sileo/Zebra
C Compatibility Application only
D App available / Injection unavailable
E App unavailable / Injection available
F No Runtime / repository browsing only
G Disconnect idle
H Disconnect active transaction
I Reconnect changed capabilities
J Background supported
K Background unsupported
```

---

# 91. Architecture Gate

Prism-facing RELAXIN-X bridge 禁止 product-name branching、raw shell、raw arbitrary process control、raw kernel primitive、raw privileged path write、random provider IDs、UI decisions、silent fallback。

---

# 92. Build 52 Gate Contract

Prism 侧已经锁：5 root tabs、Store 文件拆分、runtime-first Apps、real typed app transactions、Simulation isolated、Package/Source/Activity complete store、双语、App/UIBridge 不出现 raw privileged primitives。

---

# 93. Runtime Definition of Done

- [ ] Descriptor V2
- [ ] Open Capability
- [ ] Alias merge
- [ ] Stable provider ID
- [ ] Service descriptors
- [ ] Health
- [ ] Discovery
- [ ] Handshake
- [ ] Reconnect
- [ ] Fresh capabilities
- [ ] No silent fallback

---

# 94. Application Host Definition of Done

- [ ] Artifact staging
- [ ] Artifact inspection
- [ ] App inspection
- [ ] Install
- [ ] Register
- [ ] Replace
- [ ] Remove
- [ ] Refresh/Repair
- [ ] Normalized results
- [ ] Actual-state verification
- [ ] Timeout/cancel
- [ ] Typed errors

---

# 95. Package / Repository Definition of Done

- [ ] Package Service preserved
- [ ] State/Planning/Execution/Recovery preserved
- [ ] APT/Sileo/Zebra preserved
- [ ] Modern provider coexistence
- [ ] Trust/provenance
- [ ] Icons
- [ ] Remove/Purge regression

---

# 96. Background / Optional Injection DoD

- [ ] background-execution
- [ ] privileged-service
- [ ] start/stop/state
- [ ] disconnect/reconnect
- [ ] structured log
- [ ] injection only when actually supported

---

# 97. Store Compatibility DoD

- [ ] Featured data
- [ ] Package detail data
- [ ] Source detail data
- [ ] App runtime state
- [ ] App actions feed Activity
- [ ] Commerce preserved
- [ ] Recovery visible through Prism transaction state
- [ ] No Store UI leakage into Runtime Core

---

# 98. Safety / Boundary DoD

- [ ] Typed allowlisted Prism-facing APIs
- [ ] No arbitrary shell endpoint
- [ ] No arbitrary raw process-injection endpoint
- [ ] No arbitrary kernel primitive endpoint
- [ ] No arbitrary privileged-path endpoint
- [ ] Sensitive log redaction
- [ ] Exploit/signing-bypass implementation outside Prism contract
- [ ] Simulation cannot become real provider

---

# 99. 推荐交付顺序

```text
1 Descriptor + Capability Registry
2 Service Host + Handshake
3 Health + Reconnect
4 Artifact Staging
5 App Inspection
6 Install/Register
7 Replace/Remove/Refresh
8 Background
9 Package/Repository regression
10 Optional Injection
11 Commerce/Store matrix
12 Real-device verification
```

---

# 100. 不要重写

除非发现真实 Core 缺陷，不重写：

```text
Prism Transaction
Journal
Recovery
Package identity/version
Repository normalized model
5-tab navigation
Commerce ownership
Global Log
```

**Change only what changed.**

---

# 101. 最终 Package Flow

```text
Store Detail
→ Plan
→ Transaction
→ Package Service
→ Runtime execution
→ actual-state verification
→ Reconcile
→ Activity
```

---

# 102. 最终 IPA Flow

```text
Apps
→ Import IPA
→ Artifact Staging
→ Inspect
→ Install/Replace Plan
→ Transaction
→ Runtime Application Service
→ Register
→ actual-state query
→ Reconcile
→ Activity
```

---

# 103. 最终 Repair Flow

```text
App Detail
→ Repair
→ refresh(bundleIdentifier)
→ query actual state
→ Reconcile
→ Activity
```

---

# 104. 最终 Background Flow

```text
Settings
→ Background ON
→ capability check
→ startSession
→ active

Disconnect
→ unavailable
→ reconnect
→ fresh handshake
→ recompose
```

---

# 105. Freeze Rule

Runtime Service Host 经过真实设备验证后，建议冻结 Prism Runtime Integration Core 与 RELAXIN-X Prism-facing Service Contract。后续通过 New Capability / Service / Provider / Adapter 扩展。

---

# 106. Final Principle

```text
RELAXIN-X changes internal backend
→ Prism unchanged

RELAXIN-X changes app backend
→ replace ApplicationService implementation

RELAXIN-X changes registration backend
→ replace RegistrationService implementation

RELAXIN-X changes package backend
→ replace PackageService implementation

RELAXIN-X adds capability
→ publish new CapabilityIdentifier

Prism changes Store UI
→ RELAXIN-X Runtime unchanged
```

> **RELAXIN-X 负责提供已经拥有并授权的能力。**
>
> **Prism 负责发现、组织、展示、规划、事务化和恢复这些能力。**
>
> **底层实现变化，只替换变化的 Service。**

**Change only what changed.**

---
