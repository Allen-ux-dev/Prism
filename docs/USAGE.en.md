# Prism Usage Guide

[English](USAGE.en.md) | [简体中文](USAGE.zh-CN.md)

This guide describes normal Prism usage in a supported development, jailbreak, or already-authorized Runtime environment.

> Prism does not acquire jailbreak/system privileges by itself. Runtime-dependent features are available only when the connected environment already provides the required capability.

## 1. Install Prism

Use the release IPA that matches the current Prism version and install it through a supported development/signing/runtime workflow for your device.

The distributed IPA may be unsigned. Signing and installation depend on the environment you already use.

## 2. First Launch

On first launch, Prism initializes its package/runtime state and opens the main store interface.

The iPhone interface contains five primary destinations:

- **Featured**
- **Packages**
- **Sources**
- **Apps**
- **Activity**

Settings is available from the app interface for Runtime, compatibility and diagnostics controls.

## 3. Runtime Connection

Prism can operate with different Runtime modes.

### Modern

A Modern Runtime can provide native repository, package and application services through the Runtime Service Bridge.

In this mode, Prism Core does not require `basebin`, APT, dpkg, `prismd`, `/var/jb`, or a fixed bootstrap directory as mandatory dependencies.

### Hybrid

A Modern Runtime stays primary, while Debian/APT compatibility is enabled only when a package or source requires it.

### Legacy

Traditional environments can expose package operations through `prismd` and APT/dpkg compatibility providers.

### Connection status

Prism tracks Runtime/helper state, health and capabilities. If the service becomes unavailable, use the Runtime/connection section in Settings to inspect status and request a reconnect.

## 4. Add and Refresh Sources

Open **Sources** to manage repositories.

Typical workflow:

1. Add a supported repository URL.
2. Refresh the source.
3. Wait for metadata normalization and catalog update.
4. Open the source to browse or search packages.

Prism supports Debian/APT repository layouts and common Sileo/Zebra metadata patterns through compatibility providers.

## 5. Browse and Search Packages

Open **Packages** to:

- search by package name or metadata
- filter by category
- filter by source
- filter by installed/update state
- inspect version, architecture, dependencies and conflicts
- review the selected provider/environment state

## 6. Install or Update a Package

When you request an install or update, Prism builds a plan before executing a write.

```text
Plan
→ Transaction
→ Journal
→ Execute
→ Inspect Actual State
→ Reconcile
→ Complete / Recovery / Needs Review
```

Before confirming an operation, review dependencies, conflicts and the selected action.

The actual execution backend depends on the active Runtime Provider. A Modern environment may use native package services; a compatible Legacy environment may use APT/dpkg through the compatibility provider.

## 7. Remove or Purge a Package

Package removal uses the same transaction system.

- **Remove** removes the package using the selected provider's normal removal semantics.
- **Purge** can additionally request removal of package-managed configuration where supported by the backend.

Final state is inspected and reconciled after execution.

## 8. Apps

Open **Apps** to view application state supplied by the connected Runtime.

Depending on advertised capabilities, Prism can provide entries for:

- register / refresh
- repair
- remove
- runtime-managed installation requests
- artifact staging

Unavailable Runtime capabilities remain unavailable instead of being silently simulated as real device actions.

## 9. Activity

Open **Activity** to inspect transactions.

Prism groups work into states such as:

- Pending
- Running
- Needs Review / Recovery
- Failed
- Completed

If an operation was interrupted, inspect its Activity entry before starting unrelated corrective actions.

## 10. Recovery

Recovery is based on the recorded transaction and actual state.

Prism can use, when supported by the selected provider:

- reconcile
- rollback
- safe abort
- needs-review handling

Prism does not silently replay an interrupted write through a different provider.

## 11. Diagnostics

Use Settings / Diagnostics when investigating:

- Runtime Bridge connection state
- provider health
- capability availability
- background-service state
- repository failures
- transaction/recovery state
- global logs

Implementation-sensitive paths should be redacted in exported diagnostics.

## 12. Language

Prism includes:

- English
- Simplified Chinese

## Related Documentation

- [Features](FEATURES.en.md)
- [Runtime Integration](RUNTIME-INTEGRATION.en.md)
- [Repository README](../README.en.md)
