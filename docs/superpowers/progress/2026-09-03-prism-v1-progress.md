# Prism V1 实施进度

当前版本：**0.2.0 (Build 20)**

## 已完成

- [x] Task 1：工程骨架、Swift Core Targets、架构门禁、正式 AppIcon
- [x] Task 2：Package / Repository / Dependency / Debian Version Domain Model
- [x] Task 3：Sileo/APT Repository Metadata 归一化
- [x] Task 4：Capability 驱动的 Jailbreak Environment
- [x] Task 5：Dependency / Capability Resolver 与 InstallPlan
- [x] Task 6：SourcePackage Manifest 与 BuildPlan Domain/Planner
- [x] Task 7：Transaction State Machine 与 Mock Backend
- [x] Task 8：TransactionJournal 与 Reconciler
- [x] Task 9：Typed Privileged Protocol、持久 Socket Session、Reconnect
- [x] Task 10：prismd Service Foundation + executable
- [x] Task 11：Settings / Environment 状态 / Recovery 状态
- [x] Task 12：Featured / Packages / Sources / Apps / Activity UI
- [x] Task 13：Local Package Index 与 Search
- [x] Task 14：受限的真实 APT/dpkg Package Backend
- [x] Task 15：V1 Verification Gate
- [x] Task 16：App Management Domain 与 AppInstallPlan
- [x] Task 17：Injection Domain 与 InjectionPlan
- [x] Task 18：App / Injection 接入统一 Transaction / Journal / Reconcile
- [x] Task 19：Typed App/Injection Provider Boundary + Composable Backend
- [x] Task 20：Apps / Capability UI 基础页面（运行 Provider 不存在时正确禁用修改操作）
- [ ] Task 21：具体第三方 App/Injection runtime 的真机 E2E（Provider boundary / Recovery model 测试已完成）

## 本轮额外修复

- [x] `A | B` Alternative Dependency 结构化解析与 Resolver
- [x] `Packages.gz` 解码
- [x] Prism Source List typed sync
- [x] Unix socket 持久会话必须先 Handshake
- [x] Session `connect()` 幂等，避免 Refresh 重复握手
- [x] `posix_spawn` 移除全局 `environ` 依赖
- [x] Package Detail Install/Update → InstallPlan Review → Confirm → Transaction
- [x] daemon 重启后恢复未完成 Journal 并先 Reconcile
- [x] daemon 重启后恢复完成/失败/取消的 Activity 历史
- [x] Package/App/Injection 拆成组合 Execution Provider

## 最新自动验证

`./Scripts/VerifyPrismV1.command`

- Swift `prismd` build：PASS
- Swift Testing：38 / 38 PASS
- Architecture boundary：PASS
- Privileged API allowlist gate：PASS
- UI / iOS 15 syntax gate：PASS
- AppIcon gate：PASS
- Xcode project structure：PASS

## 尚需在真实 Apple 环境验证

当前执行容器没有 Xcode/iOS SDK，因此以下项目不能在这里冒充已经验证：

- iOS Simulator `xcodebuild`
- 真机安装/签名
- 真机 jailbreak/bootstrap 环境中的 `prismd` 生命周期
- 具体第三方 IPA installer / Injection runtime Provider

V1 默认不会写死 TrollStore/TrollFools 的第三方命令接口；相关功能通过 typed Provider boundary 接入，只有 Provider 真正存在时 Environment 才应该报告对应 Capability。
