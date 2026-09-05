#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DOMAIN="$ROOT/Packages/PrismCore/Sources/PrismDomain"
UIBRIDGE="$ROOT/Packages/PrismCore/Sources/PrismUIBridge"
TX="$ROOT/Packages/PrismCore/Sources/PrismTransactions"
ENV="$ROOT/Packages/PrismCore/Sources/PrismEnvironment"

# Future-Ready type/architecture contracts.
grep -q 'public struct PackageVersion' "$DOMAIN/PackageVersion.swift"
grep -q 'public struct PackageFormatIdentifier' "$DOMAIN/PackageFormatIdentifier.swift"
grep -q 'public actor ProviderRegistry' "$DOMAIN/ProviderRegistry.swift"
grep -q 'public protocol PackageServiceProtocol' "$TX/PackageServiceProtocol.swift"
grep -q 'public actor RelaxinRuntimeProvider' "$UIBRIDGE/RelaxinRuntimeProvider.swift"
grep -q 'public actor PrismDaemonProvider' "$UIBRIDGE/PrismDaemonProvider.swift"
grep -q 'public let legacy: LegacyEnvironmentDetails?' "$ENV/EnvironmentModels.swift"
grep -q 'case degraded(String)' "$ENV/EnvironmentModels.swift"
grep -q 'case unknown(String?)' "$ENV/EnvironmentModels.swift"

if grep -RIn --include='*.swift' 'enum PackageDistribution' "$DOMAIN" >/dev/null; then
  echo 'ERROR: PackageDistribution became a closed enum again.'
  exit 1
fi
if grep -RIn --include='*.swift' 'public let version: DebianVersion' "$DOMAIN" >/dev/null; then
  echo 'ERROR: Prism Domain regressed to DebianVersion as its global version type.'
  exit 1
fi
if grep -n 'PrivilegedSessionManager' "$UIBRIDGE/Presentation.swift" >/dev/null; then
  echo 'ERROR: PrismClientFacade is coupled directly to the privileged daemon session.'
  exit 1
fi

"$ROOT/Scripts/VerifyArchitecture.command"
"$ROOT/Scripts/VerifyUI.command"
"$ROOT/Scripts/VerifyAppIcon.command"
"$ROOT/Scripts/VerifyXcodeProject.command"

echo 'Prism 0.3.0 Future-Ready release gate completed.'
