# Prism V1 实施计划（中文版）

> **面向 Agent / 实施人员：** 必须逐任务执行，并保持 TDD。每个行为先写失败测试（RED），再写最小实现（GREEN），最后重构。任务使用 `- [ ]` 追踪状态。

**目标：** 构建 Prism V1 包管理基础：原生 iOS UI、Sileo/APT 兼容、Capability 驱动的 jailbreak 环境、BuildPlan / InstallPlan / Transaction、持久化恢复、类型化高权限 IPC、Settings 诊断与后台恢复中心，以及正式 Prism AppIcon。

**架构：** Prism 分成纯 Swift Domain/Service 模块、iOS UI App，以及最小化高权限 `prismd`。在接入真实越狱设备 Backend 前，必须先通过内存 / Mock Backend 把 Core 的端到端事务和恢复机制验证完整。真实 APT/dpkg 只允许藏在 `PackageExecutionBackend` 后面，绝不能暴露给 UI。

**技术栈：** Swift 6、SwiftUI、Foundation、XCTest / Swift Testing、Codable、V1 使用原子 JSON Transaction Journal、越狱目标使用 Unix Domain Socket、Xcode App/Daemon Target、Swift Package Core Modules。

**对应 Spec：** `docs/superpowers/specs/2026-09-03-prism-design-zh-CN.md`

---

## 全局约束

- Prism Native Core 不得依赖 Sileo 内部实现。
- Prism Native Core 不得假设 APT、dpkg、DEB、`/var/jb` 或传统 bootstrap 永远存在。
- `Prism.app` 不直接拥有高权限执行能力。
- 真正的高权限 Service 只运行在已有 jailbreak/bootstrap 授权环境中；不加入额外提权逻辑。
- 禁止通用 `runShell` / `runAnyCommand` Privileged API。
- 每次系统修改必须先生成并确认 `InstallPlan`，再创建 `Transaction`。
- 已确认 Transaction 必须独立于 Prism UI 生命周期。
- Recovery 必须先 Reconcile 实际状态，不能盲目重放事务。
- Sileo/APT 解析只存在于 Compatibility Boundary，并统一转换成 Prism Domain 类型。
- 正式图标统一使用 `Branding/Prism-AppIcon.png`。

---

## 工程结构

```text
Prism/
├── Prism.xcodeproj
├── App/
│   ├── PrismApp.swift
│   ├── AppContainer.swift
│   ├── Navigation/PrismRootView.swift
│   ├── Features/
│   │   ├── Featured/FeaturedView.swift
│   │   ├── Packages/PackagesView.swift
│   │   ├── Packages/PackageDetailView.swift
│   │   ├── Sources/SourcesView.swift
│   │   ├── Installed/InstalledView.swift
│   │   ├── Updates/UpdatesView.swift
│   │   ├── Queue/QueueView.swift
│   │   ├── Queue/TransactionDetailView.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── BackgroundServiceCard.swift
│   │       ├── EnvironmentDoctorView.swift
│   │       └── RecoveryView.swift
│   └── Assets.xcassets/AppIcon.appiconset/
├── Packages/PrismCore/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── PrismDomain/
│   │   ├── PrismRepositories/
│   │   ├── PrismEnvironment/
│   │   ├── PrismResolution/
│   │   ├── PrismTransactions/
│   │   └── PrismPrivilegedProtocol/
│   └── Tests/
├── Daemon/
│   ├── prismd-main.swift
│   ├── PrismDaemonService.swift
│   ├── UnixSocketServer.swift
│   └── PackageExecution/
│       ├── PackageExecutionBackend.swift
│       ├── MockPackageExecutionBackend.swift
│       └── JailbreakPackageExecutionBackend.swift
├── Resources/
│   └── com.prism.prismd.plist
└── Scripts/
    ├── VerifyArchitecture.command
    ├── VerifyNoHardcodedJBRoot.command
    └── VerifyPrivilegedAPI.command
```

---

# Task 1：搭建工程、模块边界、架构门禁和正式 AppIcon

**创建文件：**

- `Prism.xcodeproj`
- `App/PrismApp.swift`
- `App/AppContainer.swift`
- `Packages/PrismCore/Package.swift`
- `Scripts/VerifyArchitecture.command`
- `Scripts/VerifyNoHardcodedJBRoot.command`
- `Scripts/VerifyPrivilegedAPI.command`
- `App/Assets.xcassets/AppIcon.appiconset/*`

**测试：**

- `Packages/PrismCore/Tests/ArchitectureTests/ArchitectureContractTests.swift`

**需要产出的 Swift Package Targets：**

- `PrismDomain`
- `PrismRepositories`
- `PrismEnvironment`
- `PrismResolution`
- `PrismTransactions`
- `PrismPrivilegedProtocol`

App Target 可以依赖所有公开 Core Target。

Daemon Target 只能依赖：

- `PrismDomain`
- `PrismEnvironment`
- `PrismTransactions`
- `PrismPrivilegedProtocol`

Daemon 不允许依赖 SwiftUI 或 App Feature 文件。

- [ ] **Step 1：先写失败的 Architecture Test**

```swift
import Testing
@testable import PrismDomain

@Test func domainTargetLoadsWithoutUIFrameworks() {
    #expect(String(describing: PrismPackage.self).isEmpty == false)
}
```

此时应当失败，因为 `PrismDomain` / `PrismPackage` 还不存在。

- [ ] **Step 2：运行 Core 测试，确认 RED**

```bash
cd Packages/PrismCore
swift test
```

预期：FAIL。

- [ ] **Step 3：创建 Swift Package Targets**

`Package.swift`：

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrismCore",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "PrismDomain", targets: ["PrismDomain"]),
        .library(name: "PrismRepositories", targets: ["PrismRepositories"]),
        .library(name: "PrismEnvironment", targets: ["PrismEnvironment"]),
        .library(name: "PrismResolution", targets: ["PrismResolution"]),
        .library(name: "PrismTransactions", targets: ["PrismTransactions"]),
        .library(name: "PrismPrivilegedProtocol", targets: ["PrismPrivilegedProtocol"])
    ],
    targets: [
        .target(name: "PrismDomain"),
        .target(name: "PrismRepositories", dependencies: ["PrismDomain"]),
        .target(name: "PrismEnvironment", dependencies: ["PrismDomain"]),
        .target(name: "PrismResolution", dependencies: ["PrismDomain", "PrismEnvironment"]),
        .target(name: "PrismTransactions", dependencies: ["PrismDomain", "PrismEnvironment", "PrismResolution"]),
        .target(name: "PrismPrivilegedProtocol", dependencies: ["PrismDomain", "PrismEnvironment", "PrismTransactions"]),
        .testTarget(name: "PrismCoreTests", dependencies: ["PrismDomain", "PrismRepositories", "PrismEnvironment", "PrismResolution", "PrismTransactions", "PrismPrivilegedProtocol"])
    ]
)
```

- [ ] **Step 4：加入最小 `PrismPackage` 让测试变绿**

```swift
public struct PrismPackage: Sendable, Hashable, Codable {
    public let identifier: String
    public init(identifier: String) { self.identifier = identifier }
}
```

- [ ] **Step 5：加入静态架构门禁**

`VerifyNoHardcodedJBRoot.command`：

- `/var/jb` 只允许出现在 `PrismEnvironment` Provider / Test Fixture；
- 其他位置发现时直接失败。

`VerifyPrivilegedAPI.command`：

出现以下符号时失败：

- `runShell`
- `runAnyCommand`
- `executeArbitraryCommand`

`VerifyArchitecture.command`：

- 执行 `swift test`
- 执行以上两个静态门禁。

- [ ] **Step 6：生成 AppIcon 全尺寸素材**

从 `Branding/Prism-AppIcon.png` 生成 Xcode 所需尺寸。

不能重新绘制图形，不能让棱镜上下留白失衡。

- [ ] **Step 7：运行架构门禁**

```bash
./Scripts/VerifyArchitecture.command
```

预期：PASS。

- [ ] **Step 8：提交**

```bash
git add Prism.xcodeproj App Packages Scripts Resources Branding
git commit -m "chore: scaffold Prism architecture"
```

---

# Task 2：实现 Package / Repository / Dependency / Debian Version Domain Model

**创建：**

- `PackageModels.swift`
- `RepositoryModels.swift`
- `DebianVersion.swift`
- `Dependency.swift`

**测试：**

- `DomainModelTests.swift`
- `DebianVersionTests.swift`

**产出类型：**

- `PrismPackage`
- `PrismRepository`
- `DebianVersion`
- `PackageDependency`
- `PackageDistribution`
- `PackageInstallationState`
- `VersionRelation`

- [ ] **Step 1：先写 Debian Version 排序测试**

```swift
@Test func debianVersionsCompareNumericallyInsideSegments() {
    #expect(DebianVersion("2.10") > DebianVersion("2.9"))
}

@Test func dependencyRelationCanRequireMinimumVersion() {
    let dependency = PackageDependency(
        packageIdentifier: "libexample",
        relation: .greaterThanOrEqual,
        requiredVersion: DebianVersion("1.3")
    )
    #expect(dependency.isSatisfied(by: DebianVersion("1.4")))
    #expect(!dependency.isSatisfied(by: DebianVersion("1.2")))
}
```

- [ ] **Step 2：确认 RED**

```bash
swift test --filter DebianVersionTests
```

- [ ] **Step 3：实现公开类型**

```swift
public enum PackageDistribution: String, Codable, Sendable {
    case deb, source, native
}

public enum PackageInstallationState: String, Codable, Sendable {
    case notInstalled, installed, updateAvailable, installing, removing, broken, unknown
}

public enum VersionRelation: String, Codable, Sendable {
    case equal, greaterThan, greaterThanOrEqual, lessThan, lessThanOrEqual
}
```

`DebianVersion` 实现 `Comparable`。

必须正确处理：

- epoch
- upstream version
- revision
- 数字段按数值比较
- Debian `~` 排序语义

- [ ] **Step 4：扩展 `PrismPackage`**

Initializer 接收：

- identifier
- name
- version
- architecture
- author
- description
- repositoryID
- dependencies
- conflicts
- requirements
- distribution
- installationState
- metadata

- [ ] **Step 5：完整 Core Test**

```bash
swift test
```

预期：PASS。

- [ ] **Step 6：提交**

```bash
git add Packages/PrismCore
git commit -m "feat: add Prism package domain models"
```

---

# Task 3：把 Sileo/APT Repository Metadata 归一化成 Prism Model

**创建：**

- `DebianControlParser.swift`
- `SileoRepositoryProvider.swift`
- `RepositoryProvider.swift`
- `Fixtures/SileoPackages.fixture`

**测试：**

- `SileoRepositoryProviderTests.swift`

接口：

```swift
public protocol RepositoryProvider: Sendable {
    func normalizeRepository(
        metadata: Data,
        packagesIndex: Data,
        baseURL: URL
    ) throws -> PrismRepositorySnapshot
}
```

- [ ] **Step 1：写 Parser 失败测试**

Fixture 至少包含两个 Package，并覆盖：

- `Depends`
- `Conflicts`
- `Filename`
- `SHA256`
- `Icon`
- `SileoDepiction`
- 多行 `Description`

```swift
@Test func sileoPackagesNormalizeIntoPrismPackages() throws {
    let snapshot = try provider.normalizeRepository(
        metadata: releaseData,
        packagesIndex: packagesData,
        baseURL: baseURL
    )
    #expect(snapshot.packages.count == 2)
    #expect(snapshot.packages[0].distribution == .deb)
    #expect(snapshot.packages[0].metadata["SileoDepiction"] != nil)
}
```

- [ ] **Step 2：确认 RED**

```bash
swift test --filter SileoRepositoryProviderTests
```

- [ ] **Step 3：实现 Debian Control Paragraph Parser**

输出：

```swift
[[String: String]]
```

以一个空格开头的 continuation line 要追加到前一个 Key 中。

- [ ] **Step 4：解析 Dependency Field**

V1：

- 支持逗号分隔依赖；
- 支持单个 Alternative Branch；
- 复杂且暂不支持的 Alternative 不允许静默丢弃；
- 保存到 Metadata 并给出 Normalization Warning。

- [ ] **Step 5：兼容 Sileo Extension**

`Icon`、`SileoDepiction` 保存在 Metadata。

Standard Field 映射进 Prism Domain。

禁止在 `PrismDomain` 中出现 Sileo 专用类型。

- [ ] **Step 6：测试并提交**

```bash
swift test
git add Packages/PrismCore
git commit -m "feat: add Sileo APT compatibility provider"
```

---

# Task 4：实现 Capability 驱动的 Jailbreak Environment Discovery

**创建：**

- `EnvironmentModels.swift`
- `EnvironmentProvider.swift`
- `StandardRootlessEnvironmentProvider.swift`
- `RootfulEnvironmentProvider.swift`
- `EnvironmentResolver.swift`

**测试：**

- `EnvironmentResolverTests.swift`

接口：

```swift
public enum EnvironmentCapability: String, Codable, Hashable, Sendable {
    case backgroundService, packageInstall, apt, dpkg, sourceBuild, compiler,
         systemHookRuntime, tweakRuntime, repositoryManagement
}

public protocol EnvironmentProvider: Sendable {
    var identifier: String { get }
    func probe(_ probe: EnvironmentProbeSnapshot) -> PrismEnvironment?
}
```

- [ ] **Step 1：测试 Root Prefix 必须来自 Environment**

```swift
@Test func rootlessProviderOwnsRootPrefix() {
    let env = StandardRootlessEnvironmentProvider()
        .probe(.fixtureRootless)!
    #expect(env.rootPrefix.path == "/var/jb")
}
```

`/var/jb` literal 只允许出现在 Provider 与 Test Fixture。

- [ ] **Step 2：确认 RED**

- [ ] **Step 3：实现 `PrismEnvironment`**

包含：

- environment identifier
- bootstrap identifier
- root style
- root prefix
- architecture
- capabilities
- package database info

- [ ] **Step 4：实现 Provider Priority**

`EnvironmentResolver` 接收：

```swift
[any EnvironmentProvider]
```

输出第一个可靠匹配，同时保留全部 Probe Diagnostics。

Service 层禁止按产品名称写死。

- [ ] **Step 5：运行路径门禁**

```bash
./Scripts/VerifyNoHardcodedJBRoot.command
```

预期：PASS。

- [ ] **Step 6：提交**

```bash
git add Packages/PrismCore Scripts
git commit -m "feat: add jailbreak environment capability model"
```

---

# Task 5：实现 Dependency / Capability Resolver 和 InstallPlan

**创建：**

- `PackageStateSnapshot.swift`
- `DependencyResolver.swift`
- `CapabilityResolver.swift`
- `InstallPlan.swift`

**测试：**

- `InstallPlanTests.swift`

接口：

```swift
public struct InstallRequest: Sendable, Codable {
    public let packageIDs: [String]
}

public struct InstallPlan: Sendable, Codable, Equatable {
    public let requested: [PrismPackage]
    public let installs: [PrismPackage]
    public let upgrades: [PackageUpgrade]
    public let removals: [PrismPackage]
    public let unresolvedConflicts: [PackageConflict]
    public let unmetCapabilities: Set<EnvironmentCapability>
}

public protocol InstallPlanning: Sendable {
    func plan(
        request: InstallRequest,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        environment: PrismEnvironment
    ) throws -> InstallPlan
}
```

- [ ] **Step 1：Transitive Dependency 测试**

A 依赖 B >= 2.0，B 依赖 C。

当前已安装 B 1.5。

预期 Plan：

- Install A
- Install C
- Upgrade B

- [ ] **Step 2：Capability Mismatch 测试**

Source Package 需要 `.sourceBuild`，Environment 没有。

预期：

```swift
unmetCapabilities == [.sourceBuild]
```

并且 Plan 不允许执行。

- [ ] **Step 3：确认 RED**

- [ ] **Step 4：实现确定性的 Resolver**

候选 Package 按 Identifier + Version 排序，保证计划可复现。

检测 Dependency Cycle：

```swift
ResolutionError.dependencyCycle([String])
```

- [ ] **Step 5：确认 GREEN 并提交**

```bash
swift test --filter InstallPlanTests
git add Packages/PrismCore
git commit -m "feat: generate structured install plans"
```

---

# Task 6：实现 SourcePackage Manifest 和 BuildPlan

**创建：**

- `SourcePackageManifest.swift`
- `BuildPlan.swift`
- `BuildPlanner.swift`

**测试：**

- `BuildPlanTests.swift`

接口：

```swift
public struct SourcePackageManifest: Codable, Sendable, Equatable {
    public let packageIdentifier: String
    public let sourceReference: String
    public let requiredCapabilities: Set<EnvironmentCapability>
    public let toolchainRequirements: [String]
    public let steps: [BuildStep]
    public let artifact: ArtifactDescription
}
```

- [ ] **Step 1：证明 BuildPlan 与 InstallPlan 分离**

Source Package 需要：

- `.sourceBuild`
- `swiftc`

它应先生成 `BuildPlan`。

只有 Artifact 已存在，并且 InstallPlan 被确认后，才允许产生 Transaction。

- [ ] **Step 2：确认 RED**

- [ ] **Step 3：实现 Manifest Decode 与 Capability Validation**

V1 的 `BuildStep` 必须是声明式类型：

- `compile`
- `copyResource`
- `packageArtifact`

不能使用任意 Shell String。

- [ ] **Step 4：测试并提交**

```bash
swift test --filter BuildPlanTests
git add Packages/PrismCore
git commit -m "feat: add source package build planning"
```

---

# Task 7：实现 Transaction State Machine 与 Mock Backend

**创建：**

- `Transaction.swift`
- `TransactionStateMachine.swift`
- `TransactionExecutor.swift`
- `PackageExecutionBackend.swift`
- `MockPackageExecutionBackend.swift`

**测试：**

- `TransactionStateMachineTests.swift`

接口：

```swift
public enum TransactionPhase: String, Codable, Sendable {
    case created, preparing, resolving, ready, executing, reconciling,
         completed, failed, cancelled, needsRecovery, needsReview
}

public protocol PackageExecutionBackend: Sendable {
    func inspectState() async throws -> PackageStateSnapshot
    func execute(_ operation: TransactionOperation) async throws -> BackendOperationResult
}
```

- [ ] **Step 1：禁止非法状态跳转**

必须失败：

```text
created → executing
```

必须成功：

```text
created
→ preparing
→ resolving
→ ready
→ executing
→ reconciling
→ completed
```

- [ ] **Step 2：确认 RED**

- [ ] **Step 3：将 Transition Table 写成数据规则**

不能塞进 View Logic。

- [ ] **Step 4：实现 Deterministic In-Memory Mock Backend**

- [ ] **Step 5：端到端 Mock Transaction Test**

InstallPlan → Confirm → Transaction → Execute → Reconcile → Completed。

- [ ] **Step 6：测试并提交**

```bash
swift test --filter Transaction
git add Packages/PrismCore
git commit -m "feat: add transaction state machine"
```

---

# Task 8：实现原子 TransactionJournal 与 Reconciler

**创建：**

- `TransactionJournal.swift`
- `AtomicJournalStore.swift`
- `TransactionReconciler.swift`

**测试：**

- `TransactionRecoveryTests.swift`

接口：

```swift
public protocol TransactionJournalStore: Sendable {
    func save(_ journal: TransactionJournal) async throws
    func load(id: UUID) async throws -> TransactionJournal?
    func loadUnfinished() async throws -> [TransactionJournal]
}
```

- [ ] **Step 1：Interrupted Install 测试**

Journal 显示 `executing`，但 Backend State 已经有 Package A。

Reconciler 必须：

- 将 Operation 标为 Completed；
- 不能再次调用 Backend Execute。

- [ ] **Step 2：Corrupt Journal 测试**

损坏 Journal：

- 不能静默丢弃；
- 必须隔离；
- Transaction 进入 `needsReview`。

- [ ] **Step 3：确认 RED**

- [ ] **Step 4：实现 Atomic JSON Persistence**

写入：

```text
transaction-id.tmp
```

完成 fsync / close 后 rename 成：

```text
transaction-id.json
```

禁止直接原地改 Journal。

- [ ] **Step 5：实现 Reconcile Before Resume**

任何剩余 Operation 在继续执行之前，都必须先检查 Backend 实际状态。

- [ ] **Step 6：测试并提交**

```bash
swift test --filter TransactionRecoveryTests
git add Packages/PrismCore
git commit -m "feat: persist and reconcile transactions"
```

---

# Task 9：定义 Typed Privileged Protocol 与 Session Manager

**创建：**

- `PrivilegedMessages.swift`
- `PrivilegedTransport.swift`
- `PrivilegedSessionManager.swift`
- `InMemoryPrivilegedTransport.swift`

**测试：**

- `PrivilegedSessionTests.swift`

接口：

```swift
public enum PrivilegedRequest: Codable, Sendable {
    case handshake(ClientHello)
    case queryCapabilities
    case queryTransactions
    case submitTransaction(TransactionSubmission)
    case cancelTransaction(UUID)
    case queryPackageState
    case reconcileState(UUID)
}

public protocol PrivilegedTransport: Sendable {
    func send(_ request: PrivilegedRequest) async throws -> PrivilegedResponse
}
```

- [ ] **Step 1：Reconnect Test**

Transport 断开：

```text
connected
→ recovering
→ connected
```

恢复后自动重新查询 unfinished transaction。

- [ ] **Step 2：Protocol Safety Test**

协议列表里绝对不能存在 arbitrary command execution。

- [ ] **Step 3：确认 RED**

- [ ] **Step 4：实现指数重连**

每个前台恢复周期最多 5 次：

```text
0.5s
1s
2s
4s
8s
```

Manual Reconnect 会重置周期。

- [ ] **Step 5：运行 API Gate + Test**

```bash
./Scripts/VerifyPrivilegedAPI.command
swift test --filter PrivilegedSessionTests
```

- [ ] **Step 6：提交**

```bash
git add Packages/PrismCore Scripts
git commit -m "feat: add typed privileged session protocol"
```

---

# Task 10：建立 `prismd` Service Foundation

**创建：**

- `Daemon/prismd-main.swift`
- `Daemon/PrismDaemonService.swift`
- `Daemon/UnixSocketServer.swift`
- `Daemon/PackageExecution/PackageExecutionBackend.swift`
- `Daemon/PackageExecution/MockPackageExecutionBackend.swift`
- `Resources/com.prism.prismd.plist`

**测试：**

- `DaemonProtocolIntegrationTests.swift`

Daemon：

- 使用 `PrivilegedRequest` / `PrivilegedResponse`
- 持有 Transaction Execution / Journal Access
- 不拥有 UI / Repository Presentation Logic

- [ ] **Step 1：In-Process Daemon Integration Test**

必须完整往返：

- Handshake
- Capability Query
- Transaction Submission
- Query Transaction
- Reconciliation

真实 Transport 与测试必须共用同一套 Codable Protocol。

- [ ] **Step 2：确认 RED**

- [ ] **Step 3：定义 Frame Format**

```text
4-byte big-endian payload length
+
JSON encoded PrivilegedRequest / PrivilegedResponse
```

在 Decode 之前拒绝超过 1 MiB 的 Payload。

- [ ] **Step 4：Allowlisted Dispatch**

`PrismDaemonService.handle(_:)` 对 `PrivilegedRequest` 做 exhaustive `switch`。

禁止 Dynamic Command Name。

- [ ] **Step 5：Peer / Session Validation Hook**

Transport 提供 Peer Process Metadata 给 `ClientValidation`。

V1 Test Strategy 只接受已知 Prism App Identifier。

真实 jailbreak signing / identity 检查只在 Real Target Adapter 实现。

- [ ] **Step 6：测试并提交**

```bash
swift test --filter DaemonProtocolIntegrationTests
git add Daemon Resources Packages/PrismCore
git commit -m "feat: add prismd service foundation"
```

---

# Task 11：实现 Prism App Shell 与 Settings Recovery Center

**创建：**

- `PrismRootView.swift`
- `SettingsView.swift`
- `BackgroundServiceCard.swift`
- `EnvironmentDoctorView.swift`
- `RecoveryView.swift`

**修改：**

- `AppContainer.swift`

**测试：**

- `SettingsPresentationModelTests.swift`

`AppContainer` 只持有一个 `PrivilegedSessionManager` 与 Service Façade。

UI 只能读取 Presentation Model，不能自己拼命令或路径。

- [ ] **Step 1：Service Status Copy Test**

必须映射：

- `Connected`
- `Recovering…`
- `Offline`

绝对不能存在：

```text
Root Access ON
```

- [ ] **Step 2：确认 RED**

- [ ] **Step 3：实现 Startup Sequence**

Launch 时：

1. 立即渲染 Navigation；
2. 后台 Probe Environment；
3. Connect Service；
4. Negotiate Capabilities；
5. Reconcile Transactions；
6. Refresh Package State。

后台连接不允许卡死整个 UI。

- [ ] **Step 4：Background Service Card**

按钮：

- `Reconnect`
- `Restart Service`
- `Repair Service`
- `Diagnostics`

Restart / Repair 只有 Environment Capability 支持时才能启用。

- [ ] **Step 5：Environment Doctor**

Rows：

- jailbreak environment
- background service
- APT
- dpkg
- package database
- repository index
- transaction journal
- Sileo compatibility

- [ ] **Step 6：测试 + Simulator Build + Commit**

```bash
swift test
xcodebuild -project Prism.xcodeproj -scheme Prism -sdk iphonesimulator build
git add App
git commit -m "feat: add Prism settings recovery center"
```

---

# Task 12：实现 Packages / Sources / Installed / Updates / Queue / Transaction Detail UI

**创建所有：**

`App/Features/` 下的 Feature View。

另外：

- `PackageListModel.swift`
- `SourcesModel.swift`
- `QueueModel.swift`

**测试：**

- `FeatureModelTests.swift`

约束：

- Package UI 只消费 normalized `PrismPackage`
- Queue 只消费 persisted/reconciled Transaction Summary
- Updates 通过 InstallPlan，不允许调用 raw upgrade command

- [ ] **Step 1：Package State Section Test**

Installed / Update / Not Installed 都基于统一 `PackageInstallationState`。

- [ ] **Step 2：确认 RED**

- [ ] **Step 3：实现主导航**

- Featured
- Packages
- Sources
- Installed
- Updates
- Queue

Settings 从统一 Toolbar Entry 进入。

- [ ] **Step 4：Package Detail Confirmation Flow**

点击 `Install`：

```text
Install
→ InstallPlan Review
→ Confirm
→ TransactionSubmission
```

Cancel 不产生 Transaction。

- [ ] **Step 5：Queue Recovery Presentation**

显示：

- current phase
- completed operations
- pending operations
- recovery state
- diagnostics link

UI 断线绝不能清空 Queue Row。

- [ ] **Step 6：测试 + Build + Commit**

```bash
swift test
xcodebuild -project Prism.xcodeproj -scheme Prism -sdk iphonesimulator build
git add App
git commit -m "feat: add Prism package manager UI"
```

---

# Task 13：实现 Local Repository Index 与 SearchService

**创建：**

- `PackageIndex.swift`
- `SearchService.swift`
- `RepositoryRefreshService.swift`

**测试：**

- `SearchServiceTests.swift`

Search Index 字段：

- name
- identifier
- author
- description
- category

- [ ] **Step 1：Ranking Test**

排序优先级：

```text
Exact Identifier Match
>
Prefix Name Match
>
Author / Description Match
```

- [ ] **Step 2：确认 RED**

- [ ] **Step 3：Immutable Snapshot Index**

Repository Refresh：

1. 构建新 Index Snapshot；
2. 完整解析成功后 Atomic Swap；
3. Refresh 失败时保留旧 Snapshot。

- [ ] **Step 4：测试并提交**

```bash
swift test --filter SearchServiceTests
git add Packages/PrismCore
git commit -m "feat: add Prism local package search"
```

---

# Task 14：接入真实 Jailbroken Device Package Backend

**创建：**

- `JailbreakPackageExecutionBackend.swift`
- `PackageDatabaseInspector.swift`
- `APTAdapter.swift`
- `DPKGAdapter.swift`

**测试：**

- `JailbreakBackendContractTests.swift`

约束：

- 只能实现现有 `PackageExecutionBackend`
- Path / Feature Availability 全部来自 `PrismEnvironment`
- 除非现有 Typed Transaction Operation 无法表达某个 Domain Operation，否则不增加新的 Privileged Protocol Message

- [ ] **Step 1：Backend Contract Test**

使用 Fake Filesystem / Process Runner。

验证：

- Install
- Remove
- State Inspection

都使用 Environment 提供的 Binary / Database Path。

不能访问 Environment Provider 允许范围之外的路径。

- [ ] **Step 2：确认 RED**

- [ ] **Step 3：先实现 Read-Only Package Database Inspection**

先支持：

- Installed Package Discovery
- Installed Version State

在此阶段先不允许 Mutation。

- [ ] **Step 4：通过 Narrow Adapter 实现 Transaction Operation**

`APTAdapter` / `DPKGAdapter` 只接收 Typed Package Operation。

永远不接收来自 App 或 IPC 的任意 Command String。

- [ ] **Step 5：强制 Preflight Capability Check**

如果 Environment 缺少 `.apt` / `.dpkg`：

- 返回 `CapabilityError`
- Transaction 进入 `needsReview`
- 不猜测 Path
- 不静默 fallback

- [ ] **Step 6：跑全量 Test 与 Architecture Gate**

```bash
./Scripts/VerifyArchitecture.command
swift test
```

预期：PASS。

- [ ] **Step 7：提交**

```bash
git add Daemon Packages/PrismCore
git commit -m "feat: add jailbreak package execution backend"
```

---

# Task 15：V1 End-to-End Recovery / Compatibility Release Gate

**创建：**

- `Scripts/VerifyPrismV1.command`
- `PrismV1EndToEndTests.swift`

**修改：**

- `README.md`

- [ ] **Step 1：Sileo Package Install + UI/Session Interrupt E2E Test**

完整序列：

1. Parse Fixture Sileo Repository
2. Search + Select Package A
3. Resolve Dependency
4. Create InstallPlan
5. Confirm → Transaction
6. Mock Backend 执行一个 Operation
7. 模拟 App / Session Disconnect
8. Persist Journal
9. Recreate Session Manager
10. Reconcile Actual State
11. Finish Transaction
12. Assert Final Phase == `completed`
13. 断线前已经执行的 Operation 绝不能再次执行

- [ ] **Step 2：Source Package Path Test**

```text
SourcePackage Manifest
→ BuildPlan
→ Artifact Fixture
→ InstallPlan
→ Transaction
→ Completed
```

- [ ] **Step 3：先确认 RED，然后只修复 Test 暴露的问题**

- [ ] **Step 4：创建 `VerifyPrismV1.command`**

```bash
set -euo pipefail
./Scripts/VerifyArchitecture.command
(cd Packages/PrismCore && swift test)
xcodebuild -project Prism.xcodeproj -scheme Prism -sdk iphonesimulator build
```

- [ ] **Step 5：Final Gate**

```bash
./Scripts/VerifyPrismV1.command
```

预期：

- 所有测试通过；
- iOS Simulator Build 通过；
- Architecture Gates 通过。

- [ ] **Step 6：提交**

```bash
git add Scripts Packages README.md
git commit -m "test: add Prism V1 release gate"
```

---

## 实施顺序为什么这样排

1. 先锁 Module Boundary 与 Branding。
2. 先把 Package / Version / Dependency 语义做正确，再解析 Repository。
3. 先归一化 Sileo/APT，再让 UI 消费它。
4. 在任何安装计划之前，先确定 Environment Capability。
5. 明确证明 BuildPlan 与 InstallPlan 独立。
6. 先用 Mock Backend 完整证明 Transaction / Recovery。
7. Daemon 之前先把 Typed IPC 定好。
8. 在真实高权限执行之前先做 Settings / Recovery UI，让错误从第一天就可观察。
9. 所有 Core / Recovery Contract 变绿以后，才连接真实越狱设备 Backend。
10. Disconnect → Reconnect → Reconcile 的端到端测试不过，V1 不发布。

---

## Spec 覆盖检查

- Package / Repository / Version / Dependency：Task 2–3
- Environment / Capability / Rootless / Rootful：Task 4
- Sileo/APT Compatibility：Task 3
- Source Package / BuildPlan：Task 6
- Dependency Resolver / InstallPlan：Task 5
- Transaction / Queue：Task 7、12
- Journal / Reconciler / Background Recovery：Task 8、9、15
- Typed Privileged IPC / prismd：Task 9、10
- Settings Recovery Center / Environment Doctor：Task 11
- Search / Installed / Updates：Task 12、13
- Real Jailbreak Backend：Task 14
- 正式 AppIcon：Task 1
- V1 End-to-End Release Gate：Task 15

本计划没有依赖未定义的“以后再说”步骤。真实 jailbreak execution 被故意安排在后期，但其 Interface、Test Strategy 和 Safety Boundary 已经提前定义清楚。
