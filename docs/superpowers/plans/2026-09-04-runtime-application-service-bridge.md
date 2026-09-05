# Runtime Application Service Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect Prism Build 50's typed application/injection providers to a versioned already-authorized runtime service and add an explicit privileged-background-session toggle.

**Architecture:** Add a separate runtime-service protocol in PrismPrivilegedProtocol, remote service adapters/coordinator in PrismDaemonCore, additive prismd control/status requests, and an App-facing controller. Runtime Native stays preferred, compatibility stays fallback, and transaction/recovery semantics remain unchanged.

**Tech Stack:** Swift 6, Swift Concurrency, Codable, Unix domain sockets, existing LengthPrefixedJSONCodec, Swift Testing, SwiftUI iOS 15+.

**Spec:** `docs/superpowers/specs/2026-09-04-runtime-application-service-bridge-design.md`

## Global Constraints
- Do not implement exploit, jailbreak, signature-bypass, arbitrary-process injection, shell execution, or loader-command interfaces.
- Do not rewrite Transaction, Journal, Reconcile, or Recovery.
- Native runtime provider always outranks compatibility when both satisfy capabilities.
- Background mode controls only an already-advertised runtime capability.
- No silent provider fallback during an in-flight write transaction.
- iOS deployment target remains 15.0.

---

### Task 1: Runtime-service protocol and artifact reference

**Files:**
- Create: `Packages/PrismCore/Sources/PrismPrivilegedProtocol/RuntimeServiceMessages.swift`
- Modify: `Packages/PrismCore/Sources/PrismTransactions/TransactionModels.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeServiceProtocolTests.swift`

**Interfaces:**
- Produces `RuntimeServiceHelloRequest`, `RuntimeServiceHello`, `RuntimeServiceRequest`, `RuntimeServiceResponse`, `RuntimeBackgroundSessionState`, and additive `AppArtifactReference`.

- [ ] Write tests for handshake round-trip, unknown capability preservation, background state, and legacy `AppInstallOperation` decoding without artifact.
- [ ] Run focused tests and confirm RED because the new protocol types do not exist.
- [ ] Implement the minimal Codable/Sendable protocol types and optional artifact field.
- [ ] Run focused tests and confirm GREEN.

### Task 2: Runtime-service transport and remote adapters

**Files:**
- Create: `Packages/PrismCore/Sources/PrismPrivilegedProtocol/RuntimeServiceTransport.swift`
- Create: `Packages/PrismCore/Sources/PrismDaemonCore/RuntimeServiceBridge.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeServiceBridgeTests.swift`

**Interfaces:**
- Consumes Task 1 messages.
- Produces `RuntimeServiceTransport`, `InMemoryRuntimeServiceTransport`, `UnixSocketRuntimeServiceTransport`, `RemoteRuntimeApplicationService`, `RemoteRuntimeInjectionService`.

- [ ] Write tests that a handshake creates typed app/injection descriptors, delegates install/register/injection operations, and marks transport failure without fabricating success.
- [ ] Verify RED.
- [ ] Implement transport and remote adapters with typed requests only.
- [ ] Verify GREEN.

### Task 3: Discovery, reconnect, and background-session coordinator

**Files:**
- Create: `Packages/PrismCore/Sources/PrismDaemonCore/RuntimeServiceBridgeCoordinator.swift`
- Modify: `Packages/PrismCore/Sources/PrismDaemonCore/RuntimeApplicationServices.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeServiceBridgeCoordinatorTests.swift`

**Interfaces:**
- Produces `RuntimeServiceEndpoint`, `RuntimeServiceEndpointSource`, `RuntimeServiceBridgeStatus`, `RuntimeServiceBridgeCoordinator`.

- [ ] Write tests for native preference, compatibility fallback, disconnect unregister, reconnect re-register, independent injection/app registration, and background capability gating.
- [ ] Verify RED.
- [ ] Implement coordinator against injected endpoint sources/transports and existing registry.
- [ ] Verify GREEN.

### Task 4: prismd bridge control/status wiring

**Files:**
- Modify: `Packages/PrismCore/Sources/PrismPrivilegedProtocol/Messages.swift`
- Modify: `Packages/PrismCore/Sources/PrismDaemonCore/PrismDaemonService.swift`
- Modify: `Packages/PrismCore/Sources/prismd/main.swift`
- Test: `Packages/PrismCore/Tests/PrismCoreTests/RuntimeServiceDaemonWiringTests.swift`

**Interfaces:**
- Adds `queryRuntimeBridgeStatus`, `reconnectRuntimeBridge`, and `setRuntimeBackgroundEnabled(Bool)` to Prism↔prismd protocol.

- [ ] Write daemon tests for status/query/control and unavailable coordinator behavior.
- [ ] Verify RED.
- [ ] Wire coordinator into daemon service and startup; keep unavailable fallback when no remote service exists.
- [ ] Verify GREEN.

### Task 5: App controller, settings toggle, logging, and localization

**Files:**
- Create: `Packages/PrismCore/Sources/PrismUIBridge/RuntimeBridgeController.swift`
- Modify: `App/AppContainer.swift`
- Modify: `App/Navigation/PrismRootView.swift`
- Modify: `App/en.lproj/Localizable.strings`
- Modify: `App/zh-Hans.lproj/Localizable.strings`
- Create: `Scripts/VerifyRuntimeServiceBridge.command`

**Interfaces:**
- AppContainer exposes runtime bridge status and `runtimeBackgroundEnabled` preference.

- [ ] Add a static UI gate requiring the Runtime Background section, capability-aware disabled state, and localization keys; verify RED.
- [ ] Add controller/state/update logic and Settings UI; log enable/disable/connectivity outcomes.
- [ ] Verify UI gate GREEN.

### Task 6: Release hardening and Build 51

**Files:**
- Modify: `Scripts/VerifyPrismCoreFreeze.command`
- Modify: `Prism.xcodeproj/project.pbxproj`
- Modify: `README.md`

**Interfaces:**
- Build number 51 and release gate inclusion.

- [ ] Add the Build 51 gate to Core Freeze and verify the pre-change gate fails for missing inclusion.
- [ ] Bump `CURRENT_PROJECT_VERSION` to 51 and document Build 51.
- [ ] Delete SwiftPM `.build`, run full `swift test`, then full `VerifyPrismCoreFreeze.command`.
- [ ] Confirm all tests/gates pass before packaging.
