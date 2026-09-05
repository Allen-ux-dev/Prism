# Prism Build 51 — Runtime Application Service Bridge Design

## Goal
Turn Build 50's in-process application/injection provider registry into a discoverable, versioned runtime-service bridge. When an already-authorized runtime exposes application or injection services, prismd can handshake, register typed providers, and use them through the existing transaction engine. Add a user-controlled privileged background-session toggle that only controls a capability already granted by the runtime.

## Safety and architectural boundary
- Prism does not implement jailbreak, privilege escalation, signature bypass, arbitrary-process injection, or exploit chains.
- Runtime services are assumed to be already authorized by the device/runtime environment.
- Compatibility adapters remain typed delegates. They do not accept shell commands, PIDs, loader arguments, or arbitrary executable paths.
- Transaction / Journal / Reconcile / Recovery semantics are preserved.
- Provider pinning remains in force during transactions; no silent provider switching after execution begins.

## Components
1. `PrismPrivilegedProtocol/RuntimeServiceMessages.swift`
   - Versioned handshake, service descriptor, typed application/injection operations, background-session control, health/status response.
2. `PrismPrivilegedProtocol/RuntimeServiceTransport.swift`
   - Transport protocol plus Unix-domain-socket implementation using the existing length-prefixed JSON codec.
3. `PrismDaemonCore/RuntimeServiceBridge.swift`
   - Client that handshakes with one runtime endpoint, exposes remote services as `RuntimeApplicationService` / `RuntimeInjectionService`, and degrades cleanly on disconnect.
4. `PrismDaemonCore/RuntimeServiceBridgeCoordinator.swift`
   - Discovery/reconnect coordinator. Registers/removes remote services in `RuntimeApplicationServiceRegistry`, controls privileged background sessions, exposes a compact status snapshot.
5. `PrismPrivilegedProtocol/Messages.swift` + `PrismDaemonService.swift`
   - Additive Prism↔prismd status/control requests for runtime bridge state and background-session toggle.
6. `PrismUIBridge/RuntimeBridgeController.swift`
   - Client-facing facade used by AppContainer.
7. `App/AppContainer.swift` + Settings UI + localization
   - Persist user preference, request background-session activation only when the runtime advertises the capability, log state changes, show unsupported/degraded state without faking success.

## Runtime service protocol
Handshake reports:
- protocol range / selected protocol version
- runtime identity and display name
- service version
- provider kind (`native` or `compatibility`)
- capability states
- health

Application operations remain typed:
- inspect installed apps
- inspect registrations
- install
- replace
- remove
- register
- refresh/repair

Injection operations remain typed:
- inspect active injections
- apply artifact to a bundle identifier
- remove artifact from a bundle identifier

Background operations:
- query background-session state
- enable/disable Prism's runtime background session

## Artifact reference
`AppInstallOperation` gains an optional, additive `AppArtifactReference`. It may carry an opaque staging identifier and integrity digest. Existing V1 operations without an artifact continue decoding. The bridge never interprets this as a shell path.

## Background mode
The UI setting represents Prism's requested runtime session state, not a jailbreak switch.
- Unsupported capability: toggle disabled.
- Supported + off: user may enable.
- Starting/active/degraded: show explicit state.
- Runtime disconnect: state becomes degraded/unavailable and is logged.
- Disable: coordinator asks runtime to release Prism's background session.

## Discovery
Build 51 uses injected endpoint discovery with a small default endpoint-source abstraction. No product-name branching is allowed. A runtime can provide a configured Unix socket endpoint; tests use in-memory transports.

## Definition of done
- Versioned runtime-service handshake round-trips unknown optional capability identifiers.
- Native application service discovered remotely becomes the selected application provider.
- Compatibility remote service is selected only when no qualifying native service exists.
- Application and injection service resolution remain independent.
- Disconnect unregisters remote services and falls back to unavailable without changing an in-flight transaction provider.
- Reconnect re-handshakes and re-registers services for the next transaction.
- Background toggle only enables when the runtime advertises `background-execution` and `privileged-service`.
- Global log records background request/result and runtime bridge connectivity without secrets.
- Existing Build 50 tests stay green.
- New Build 51 gate is included in Core Freeze verification.
