#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DOMAIN="$ROOT/Packages/PrismCore/Sources/PrismDomain"
UIBRIDGE="$ROOT/Packages/PrismCore/Sources/PrismUIBridge"
APP="$ROOT/App"

# Provider Runtime 0.4 contracts.
grep -q 'public struct ProviderRuntimeState' "$DOMAIN/ProviderModels.swift"
grep -q 'func refreshHealth' "$DOMAIN/ProviderRegistry.swift"
grep -q 'public struct RelaxinBridgeHandshake' "$UIBRIDGE/RelaxinBridgeContract.swift"
grep -q 'public actor PackageServiceSession' "$UIBRIDGE/PackageServiceSession.swift"
grep -q 'public enum ProviderRecoveryStrategy' "$DOMAIN/ProviderModels.swift"
grep -q 'public enum MockProviderFaultMode' "$UIBRIDGE/MockProviderFaults.swift"

# The ordinary App/Facade layer must not reconstruct legacy implementation details.
forbidden=$(grep -RInE --include='*.swift' '(/var/jb|apt-get|dpkg-query|prismd\.sock|basebin|PrismDaemonProvider\()' \
  "$APP" "$UIBRIDGE/Presentation.swift" "$UIBRIDGE/PackageServiceBootstrap.swift" 2>/dev/null || true)
if [ -n "$forbidden" ]; then
  echo 'ERROR: provider-runtime boundary leaked a legacy implementation detail into App/Facade:'
  echo "$forbidden"
  exit 1
fi

"$ROOT/Scripts/VerifyArchitecture.command"
"$ROOT/Scripts/VerifyUI.command"
"$ROOT/Scripts/VerifyAppIcon.command"
"$ROOT/Scripts/VerifyXcodeProject.command"

echo 'Prism 0.4.0 Provider Runtime release gate completed.'
