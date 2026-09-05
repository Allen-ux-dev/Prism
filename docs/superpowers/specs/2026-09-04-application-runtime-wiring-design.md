# Prism Build 50 Application Runtime Wiring Design

## Goal
Wire real application-management capability selection into Prism without embedding exploit, signature-bypass, or product-specific behavior in the app layer.

## Architecture
Prism keeps `AppInstallPlan -> PrismTransaction -> Journal/Reconcile` as the only write path. Modern runtimes advertise open capability identifiers and execute application transactions through their typed runtime service. Legacy/compatibility environments may expose typed application or injection execution services that are wrapped by compatibility adapters.

Provider preference is runtime-native first. A TrollStore-style application adapter may be used only when an authorized runtime explicitly registers a compatible application execution service. A TrollFools-style injection adapter follows the same rule for injection operations. Neither adapter contains exploitation, arbitrary shell execution, or hidden fallback behavior.

## Capability model
Add standard identifiers for application install, registration, replacement, removal, refresh, injection and artifact-specific injection capabilities. V1 `EnvironmentCapability` continues to adapt into these identifiers.

## Composition
`RuntimeApplicationServiceRegistry` discovers registered typed services. `RuntimeApplicationProviderResolver` chooses native services before compatibility services and returns unavailable providers when no compatible service exists. Prism daemon composition uses that resolver rather than hardcoding unavailable providers.

## Safety and transaction rules
No silent fallback after a transaction starts. No raw process/path/argument interface is exposed through the adapter boundary. All application changes remain typed transaction operations and existing reconcile/recovery behavior remains authoritative.

## Compatibility
Existing mock TrollStore/TrollFools simulation providers remain non-destructive test fixtures. Existing package, repository, journal, migration and package-service contracts are unchanged except for additive capability identifiers and runtime application composition.
