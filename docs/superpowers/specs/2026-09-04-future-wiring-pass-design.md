# Prism Build 48 → Future Wiring Pass Upgrade Document

> Target: Prism 0.4.1 Build 48+
>
> Status: Architecture stable / wiring hardening only
>
> Goal: 将 Prism Build 48 从“Core 架构已经未来化，但实际 App 接线仍存在 Legacy / 产品名特判”升级到真正的 Future-First Runtime + Repository Composition。
>
> 核心原则：
>
> **Do not redesign the Core.**
>
> **Do not rewrite Transaction / Journal / Recovery.**
>
> **Only replace wiring that is still tied to Legacy assumptions.**
>
> 最终目标：
>
> **Change only what changed.**

---

# 1. 当前状态

Build 48 的 Core 已经具备：

```text
Package Domain
Repository abstraction
Provider Registry
Provider Resolver
Provider Policy
Runtime Integration
RELAXIN-X Bridge
Runtime Installer
Installation Ownership
Protocol Handshake
Package Service
Transaction
Journal
Reconcile
Recovery
Trust / Provenance
Schema Migration
Modern / Hybrid / Legacy
Legacy DEB Compatibility
```

因此本轮 **禁止大改 Core Contract**。

本轮只处理四个剩余 Future Wiring 问题：

```text
1. AppContainer 仍然 Legacy / Hybrid-first
2. RepositoryCatalogClient 仍直接绑定 SileoRepositoryProvider
3. Presentation 仍存在 RELAXIN 产品名字符串判断
4. Capability Model 仍是封闭 enum
```

---

# 2. Upgrade Scope

本轮名称建议：

```text
Prism Build 49
Future Wiring Pass
```

或：

```text
Prism 0.4.2
Future-First Composition
```

本轮不增加新的大型功能。

只完成：

```text
Runtime-aware App Composition
Repository Provider Resolution
Runtime-neutral Presentation
Open Capability Identifier
```

---

# 3. AppContainer：从 Hybrid-first 改为 Runtime-aware Composition

## 当前问题

当前 App 启动路径仍然类似：

```swift
private let sessionFactory =
    PrismProviderComposition.compatibilityFactory(
        clientIdentifier: "dev.allenux.prism"
    )

private lazy var client =
    PrismClientFacade(
        factory: sessionFactory,
        mode: .hybrid
    )
```

这意味着实际 App 启动默认仍然偏向：

```text
Prism
   ↓
Compatibility Factory
   ↓
PrismDaemonProvider
   ↓
Legacy / Hybrid
```

而不是 Future-first。

---

## 目标

启动时应根据 Runtime / Capability 自动选择 Provider。

目标：

```text
Prism Launch
     ↓
Runtime Discovery
     ↓
Runtime Integration Probe
     ↓
Provider Resolver
     ↓
Provider Policy
     ↓
Best Available Runtime Provider
```

优先级：

```text
1. Modern Runtime Provider
2. Native / Direct Provider
3. Legacy Compatibility Provider
```

---

## 推荐接口

新增：

```swift
protocol PrismRuntimeCompositionResolving {
    func resolveComposition(
        environment: PrismEnvironment
    ) async throws -> PrismProviderComposition
}
```

或：

```swift
struct PrismRuntimeCompositionResolver {
    func resolve(
        runtimeDescriptor: RuntimeDescriptor?,
        environment: PrismEnvironment
    ) async -> PrismProviderComposition
}
```

---

## 推荐行为

```text
RELAXIN-X Runtime available
+ PackageService available
        ↓
RelaxinRuntimeProvider
        ↓
Modern Mode
```

否则：

```text
Modern unavailable
+ Legacy compatibility available
        ↓
PrismDaemonProvider
        ↓
Hybrid / Legacy
```

否则：

```text
No write provider
        ↓
Read-only / Degraded mode
```

---

## 禁止

AppContainer 不得：

```text
hardcode .hybrid
hardcode compatibilityFactory
hardcode prismd as primary backend
```

Legacy 只能是 fallback / compatibility。

---

# 4. Provider Composition Policy

新增明确策略：

```text
Modern First
Legacy On Demand
No Silent Write Fallback
```

Provider 选择必须经过：

```text
ProviderRegistry
      ↓
ProviderResolver
      ↓
ProviderPolicy
```

推荐：

```swift
enum ProviderPreference {
    case modernFirst
    case compatibilityFirst
    case explicit(String)
}
```

默认：

```swift
.modernFirst
```

用户可在高级设置查看当前模式，但 UI 不直接决定具体 Provider。

---

# 5. RepositoryCatalogClient：去除 SileoRepositoryProvider 直连

## 当前问题

Repository UI 实际路径仍类似：

```swift
private let provider = SileoRepositoryProvider()
```

这导致：

```text
Add Source
   ↓
RepositoryCatalogClient
   ↓
SileoRepositoryProvider
```

虽然 Core 已经支持多个 Repository Provider，但 UI 没真正走 Provider Resolution。

---

## 目标

改成：

```text
Add Source
   ↓
Repository Request
   ↓
Repository Provider Registry
   ↓
Repository Resolver
   ↓
Repository Probe
   ↓
Best Matching Repository Provider
```

Provider 可包括：

```text
APTRepositoryProvider
RelaxinModernRepositoryProvider
PrismNativeRepositoryProvider
FutureRepositoryProvider
```

---

# 6. Repository Probe Contract

建议新增：

```swift
protocol RepositoryProviderProbing {
    func probe(
        source: RepositorySource
    ) async -> RepositoryProbeResult
}
```

结果：

```swift
struct RepositoryProbeResult {
    let providerID: String
    let confidence: Double
    let compatibility: CompatibilityLevel
    let detectedFormat: String?
    let metadata: RepositoryMetadata?
}
```

---

## 示例

添加传统软件源：

```text
https://repo.example.com
        ↓
APT Provider Probe
        ↓
Release / Packages detected
        ↓
APTRepositoryProvider selected
```

添加未来 RELAXIN 源：

```text
https://future.relaxin.dev/repo
        ↓
Relaxin Modern Probe
        ↓
Modern repository metadata detected
        ↓
RelaxinModernRepositoryProvider selected
```

---

# 7. Repository UI 必须 Provider-neutral

Repository UI 只能显示统一模型：

```text
Repository
├─ ID
├─ Display Name
├─ URL
├─ Icon
├─ Description
├─ Trust Status
├─ Health
├─ Compatibility
└─ Provider Metadata
```

禁止 UI 直接读取：

```text
Release
Packages
Packages.gz
SileoDepiction
```

这些字段只能存在于对应 Provider 内部。

---

# 8. Package Source Flow

目标统一成：

```text
Source
  ↓
Repository Provider
  ↓
Prism Repository Model
  ↓
Prism Package Model
  ↓
Requirements
  ↓
Provider Resolver
  ↓
Package Service
  ↓
Transaction
```

传统源：

```text
APT / Sileo / Zebra source
        ↓
APTRepositoryProvider
        ↓
DEB Package
        ↓
Legacy-compatible Package Service
```

未来源：

```text
RELAXIN / Prism Modern source
        ↓
Modern Repository Provider
        ↓
Modern Package
        ↓
RELAXIN-X Package Service
```

Application Layer 不判断格式。

---

# 9. Presentation：移除 RELAXIN 产品名字符串判断

## 当前问题

Presentation 层存在类似：

```swift
environment.runtimeIdentity
    .lowercased()
    .contains("relaxin")
```

这种判断。

这会导致：

```text
产品名
→ 决定运行模式 / UI
```

这与未来架构原则冲突。

---

## 目标

Presentation 只消费 Runtime Descriptor / Compatibility Profile。

建议 Runtime Descriptor 提供：

```swift
struct RuntimePresentationDescriptor {
    let displayName: String
    let runtimeIdentity: String
    let runtimeVersion: String
    let operatingMode: RuntimeOperatingMode
    let compatibilityLevel: CompatibilityLevel
}
```

---

# 10. Runtime Operating Mode

推荐：

```swift
enum RuntimeOperatingMode: String, Codable, Sendable {
    case modern
    case hybrid
    case legacy
    case readOnly
    case degraded
    case unknown
}
```

模式必须由：

```text
Capabilities
Compatibility Layers
Provider Availability
Runtime Descriptor
```

推导。

禁止：

```text
if runtimeIdentity contains "relaxin"
    mode = modern
```

---

# 11. Runtime Display Name

Runtime UI 名称由 Runtime 提供：

```text
RELAXIN-X Runtime
Dopamine Runtime
RootHide Runtime
Future Runtime
```

Prism 不维护产品名列表。

建议：

```swift
RuntimeDescriptor.displayName
```

如果缺失：

```text
displayName = runtimeIdentity
```

---

# 12. Capability Model：从 enum 升级为开放 Identifier

## 当前问题

当前 Capability 类似：

```swift
enum EnvironmentCapability
enum RuntimeIntegrationCapability
```

这意味着未来增加 Capability 时：

```text
RELAXIN-X adds new capability
        ↓
Prism Core enum must change
```

这不是完全开放的未来架构。

---

## 目标

改成开放 Identifier：

```swift
struct CapabilityIdentifier:
    RawRepresentable,
    Hashable,
    Codable,
    Sendable
{
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}
```

---

# 13. Standard Capability Namespace

内建 Capability：

```swift
extension CapabilityIdentifier {
    static let packageService =
        CapabilityIdentifier(
            rawValue: "dev.prism.capability.package-service"
        )

    static let backgroundExecution =
        CapabilityIdentifier(
            rawValue: "dev.prism.capability.background-execution"
        )

    static let serviceRegistration =
        CapabilityIdentifier(
            rawValue: "dev.prism.capability.service-registration"
        )

    static let lifecycleRecovery =
        CapabilityIdentifier(
            rawValue: "dev.prism.capability.lifecycle-recovery"
        )

    static let packageStoreAccess =
        CapabilityIdentifier(
            rawValue: "dev.prism.capability.package-store-access"
        )

    static let repositoryNetworking =
        CapabilityIdentifier(
            rawValue: "dev.prism.capability.repository-networking"
        )

    static let appRegistration =
        CapabilityIdentifier(
            rawValue: "dev.prism.capability.app-registration"
        )
}
```

未来 RELAXIN-X 可以新增：

```text
dev.relaxin.capability.xxx
```

而 Prism Core 不需要更新。

---

# 14. Capability Availability

继续使用开放状态模型：

```swift
struct CapabilityState: Codable, Sendable {
    let identifier: CapabilityIdentifier
    let availability: CapabilityAvailability
    let version: Int?
    let metadata: [String: String]
}
```

未知 Capability：

```text
Decode
→ Preserve
→ Ignore if not required
```

禁止：

```text
Unknown capability
→ decode failure
```

---

# 15. Capability Requirement

Package / Provider / Runtime 都统一使用：

```swift
struct CapabilityRequirement: Codable, Sendable {
    let identifier: CapabilityIdentifier
    let minimumVersion: Int?
    let required: Bool
}
```

Provider Resolver 只比较 Identifier / Version / Availability。

---

# 16. Compatibility Profile Upgrade

将：

```text
Set<String>
```

升级成：

```swift
Set<CapabilityIdentifier>
```

或：

```swift
[CapabilityRequirement]
```

例如：

```swift
struct PrismCompatibilityProfile {
    let requiredCapabilities: [CapabilityRequirement]
    let optionalCapabilities: [CapabilityRequirement]
}
```

---

# 17. Runtime Integration Contract 保持不变

本轮不要重写：

```text
PrismRuntimeInstallerProtocol
RuntimeHandshake
RuntimeDescriptor
PackageServiceDescriptor
PackageServiceSession
InstallationOwnership
```

只允许 additive change。

如果 Capability 类型迁移：

```text
V1 enum
      ↓
Adapter
      ↓
CapabilityIdentifier
```

不得一次破坏旧 Runtime。

---

# 18. Backward Compatibility Adapter

建议加入：

```swift
struct LegacyCapabilityAdapter {
    func convert(
        _ legacy: RuntimeIntegrationCapability
    ) -> CapabilityIdentifier
}
```

旧 Runtime Handshake：

```text
Protocol V1
enum Capability
```

新 Prism：

```text
Protocol V2
CapabilityIdentifier
```

两者通过 Adapter 兼容。

---

# 19. No Silent Legacy Fallback

这一条必须继续保持。

场景：

```text
Modern Provider selected
        ↓
Transaction started
        ↓
Provider unavailable
```

禁止：

```text
silently switch to prismd / apt / dpkg
```

必须：

```text
Interrupted
   ↓
Reconcile
   ↓
Explicit decision
   ├─ Resume
   ├─ Rollback
   ├─ Safe Abort
   └─ Needs Review
```

---

# 20. Repository Provider Failure Isolation

Repository Provider 失败不能拖死 Sources 页面。

例如：

```text
Modern Repo Provider failed
APT Provider healthy
```

结果：

```text
Modern Source  Degraded
APT Source     Healthy
Prism          Healthy
```

新增超时：

```text
probe timeout
refresh timeout
metadata timeout
```

并允许 cancellation。

---

# 21. Provider Timeout / Cancellation

建议所有 Provider Operation 支持：

```swift
struct ProviderOperationContext {
    let operationID: UUID
    let deadline: Date?
    let cancellationToken: CancellationToken
}
```

目标：

```text
Provider hangs forever
→ timeout
→ provider degraded
→ Prism remains responsive
```

---

# 22. AppContainer Composition Tests

新增：

```text
ModernRuntimeIsPreferredWhenAvailable
LegacyProviderUsedWhenModernUnavailable
ReadOnlyModeWhenNoWriteProviderExists
HybridIsNotHardcodedAtStartup
RuntimeReconnectRecomposesProviderSession
ProviderSelectionUsesPolicy
```

---

# 23. Repository Resolution Tests

新增：

```text
APTSourceSelectsAPTProvider
ModernSourceSelectsModernProvider
UnknownSourceReturnsUnsupported
ProviderProbeFailureIsIsolated
RepositoryProviderTimeoutDoesNotBlockCatalog
MultipleProvidersUsePolicyRanking
```

---

# 24. Presentation Neutrality Tests

新增：

```text
PresentationDoesNotInspectRelaxinName
RuntimeDisplayNameComesFromDescriptor
OperatingModeComesFromCompatibilityProfile
UnknownRuntimeDisplaysCorrectly
```

静态门禁：

```text
contains("relaxin")
runtimeIdentity == "..."
```

不得出现在 Presentation / Application 决策代码。

---

# 25. Capability Extensibility Tests

新增：

```text
UnknownCapabilityRoundTrips
UnknownOptionalCapabilityDoesNotBreakHandshake
UnknownRequiredCapabilityMarksIncompatible
FutureCapabilityDoesNotRequireCoreChange
LegacyEnumCapabilityMigratesToIdentifier
CapabilityNamespaceRemainsStable
```

---

# 26. Architecture Gate 4.0

新增门禁。

App / Core 禁止：

```text
compatibilityFactory as default app composition
hardcoded .hybrid startup mode
private let provider = SileoRepositoryProvider()
contains("relaxin") for behavior decisions
closed capability enum as long-term runtime contract
```

允许位置：

```text
Legacy Compatibility adapters
APT Provider implementation
Migration code
Tests
```

---

# 27. Static Search Gate

新增：

```bash
rg 'contains\("relaxin"\)' Prism/
rg 'SileoRepositoryProvider\(\)' Prism/App Prism/UI
rg 'mode:\s*\.hybrid' Prism/App
rg 'compatibilityFactory' Prism/App
```

正常结果：

```text
No architectural violations found.
```

如果存在 allowlist：

必须明确记录原因。

---

# 28. Definition of Done

Future Wiring Pass 完成标准：

- [ ] AppContainer no longer defaults to compatibilityFactory
- [ ] AppContainer no longer hardcodes `.hybrid`
- [ ] Modern Runtime is preferred when available
- [ ] Legacy Runtime is compatibility fallback
- [ ] RepositoryCatalogClient no longer owns SileoRepositoryProvider directly
- [ ] Repository Provider Resolver is used by Sources UI
- [ ] APT source remains fully compatible
- [ ] Modern RELAXIN source can be routed through its Provider
- [ ] Presentation contains no RELAXIN-specific behavior branching
- [ ] Runtime display name comes from descriptor
- [ ] Runtime mode comes from capability / compatibility state
- [ ] CapabilityIdentifier replaces closed long-term capability enum
- [ ] Unknown optional capability is preserved safely
- [ ] Unknown required capability becomes explicit incompatibility
- [ ] Legacy capability adapter exists
- [ ] Transaction provider pinning remains intact
- [ ] No silent Legacy write fallback
- [ ] Repository provider failures are isolated
- [ ] Provider timeout / cancellation implemented
- [ ] Existing Build 48 Core tests remain PASS
- [ ] New Future Wiring tests PASS

---

# 29. Regression Requirements

本轮不得破坏：

```text
Transaction
Journal
Reconcile
Recovery
Trust
Provenance
Schema Migration
Installation Ownership
Prism Self Update
RELAXIN-X Runtime Installer
Runtime Handshake
Legacy DEB
APT / Sileo / Zebra Source Compatibility
```

尤其禁止为了 Future Wiring 改写：

```text
Transaction engine
Journal schema
Recovery semantics
Package identity
Package version model
```

---

# 30. Release Test Matrix

至少验证：

```text
Environment A
RELAXIN-X Modern Runtime
Modern Package Service
Modern Repository

Environment B
RELAXIN-X Modern Runtime
APT Legacy Compatibility
Sileo / Zebra Repo

Environment C
Legacy Runtime
prismd
APT / dpkg / DEB

Environment D
No Runtime
Repository browsing only

Environment E
Modern Runtime disconnected
Reconnection / repair
```

---

# 31. Traditional Source Compatibility

必须继续验证：

```text
Add APT Source
Refresh
Packages / Packages.gz
Package Metadata
Depends
Conflicts
Architecture
SHA256
Icon
SileoDepiction
Install Plan
Legacy DEB Service
Transaction
```

结论要求：

> Future-first 不等于破坏旧生态。

Legacy compatibility 仍然是一等兼容能力，只是不再是架构中心。

---

# 32. Final Runtime Architecture

```text
                    RELAXIN-X
                        │
                 Runtime Descriptor
                        │
                 Capability Contract
                        │
               Runtime Integration
                        │
             Runtime Composition Resolver
                        │
                Provider Registry
                        │
                Provider Resolver
                        │
                 Provider Policy
                        │
        ┌───────────────┼───────────────┐
        │               │               │
      Modern          Native          Legacy
        │                               │
RELAXIN-X Service                 prismd / apt / dpkg
        │                               │
        └───────────────┬───────────────┘
                        │
                      Prism
```

---

# 33. Final Repository Architecture

```text
                   Add Source
                       │
                Repository Request
                       │
              Repository Registry
                       │
              Repository Resolver
                       │
               Provider Probe
                       │
       ┌───────────────┼───────────────┐
       │               │               │
     Modern          Native           APT
       │               │               │
RELAXIN Repo       Prism Repo     Sileo/Zebra
       │               │               │
       └───────────────┬───────────────┘
                       │
              Prism Repository Model
                       │
               Prism Package Model
```

---

# 34. Final Capability Architecture

```text
CapabilityIdentifier
        │
        ├─ dev.prism.capability.package-service
        ├─ dev.prism.capability.background-execution
        ├─ dev.prism.capability.app-registration
        │
        ├─ dev.relaxin.capability.*
        │
        └─ future.vendor.capability.*
```

Prism Core 只理解：

```text
Identifier
Availability
Version
Requirement
```

而不要求知道所有 Capability 的名字。

---

# 35. Freeze Rule

Future Wiring Pass 完成之后：

> Freeze Prism Package Core + Runtime Integration Core.

后续变化只允许：

```text
New Provider
New Capability Identifier
New Adapter
New Repository Provider
New Package Format
New Runtime Descriptor field
```

原则上不再：

```text
rewrite Domain
rewrite Transaction
rewrite Journal
rewrite Recovery
```

---

# 36. 最终目标

Prism 必须满足：

```text
RELAXIN-X changes Kernel Backend
→ Prism unchanged

RELAXIN-X removes basebin
→ Prism unchanged

RELAXIN-X changes package service
→ replace Provider

RELAXIN-X adds capability
→ add CapabilityIdentifier

Repository format changes
→ replace RepositoryProvider

Legacy ecosystem still needed
→ Legacy Provider remains available
```

一句话：

> **Prism 不应该知道未来具体长什么样，只需要知道未来如何接进来。**

最终原则：

```text
Change only what changed.
```

**哪里变了，只换哪里。**
