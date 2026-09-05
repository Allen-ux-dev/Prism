#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DOMAIN="$ROOT/Packages/PrismCore/Sources/PrismDomain"
TX="$ROOT/Packages/PrismCore/Sources/PrismTransactions"
UIBRIDGE="$ROOT/Packages/PrismCore/Sources/PrismUIBridge"
TESTS="$ROOT/Packages/PrismCore/Tests/PrismCoreTests"

# Core Freeze contracts must remain present.
grep -q 'protocol PrismRuntimeInstallerProtocol' "$UIBRIDGE/PrismRuntimeInstallerProtocol.swift"
grep -q 'enum PrismIntegrationState' "$DOMAIN/RuntimeIntegrationModels.swift"
grep -q 'struct PrismCompatibilityProfile' "$DOMAIN/CompatibilityProfile.swift"
grep -q 'actor PrismRuntimeIntegrationCoordinator' "$UIBRIDGE/PrismRuntimeIntegrationCoordinator.swift"
grep -q 'struct RelaxinRuntimeInstallerAdapter' "$UIBRIDGE/RelaxinRuntimeInstallerAdapter.swift"
grep -q 'struct RuntimeHandshake' "$DOMAIN/ContractVersions.swift"
grep -q 'protocol ProviderResolving' "$UIBRIDGE/ProviderResolver.swift"
grep -q 'protocol ProviderPolicyEvaluating' "$DOMAIN/ProviderPolicy.swift"
grep -q 'protocol PackageStateService' "$TX/PackageServiceContracts.swift"
grep -q 'protocol PackageRecoveryService' "$TX/PackageServiceContracts.swift"
grep -q 'struct PackageProvenance' "$DOMAIN/TrustModels.swift"
grep -q 'protocol PrismSchemaMigrator' "$DOMAIN/SchemaVersioning.swift"
grep -q 'enum PrismUpdateState' "$TX/PrismUpdateModels.swift"
test -f "$TESTS/ProviderConformanceTests.swift"
test -f "$TESTS/RelaxinBridgeConformanceTests.swift"

# Architecture Gates 3.0: implementation-agnostic Core and ordinary App UI.
# Explicit legacy implementation files/providers are checked separately and are the only allowlist.
CORE_PATHS=(
  "$ROOT/Packages/PrismCore/Sources/PrismDomain"
  "$ROOT/Packages/PrismCore/Sources/PrismRepositories"
  "$ROOT/Packages/PrismCore/Sources/PrismResolution"
  "$ROOT/Packages/PrismCore/Sources/PrismTransactions"
  "$ROOT/App"
)
forbidden=$(grep -RInE --include='*.swift' '(/basebin/|jbctl|apt-get|dpkg-query|prismd\.sock|/var/jb)' "${CORE_PATHS[@]}" 2>/dev/null || true)
if [ -n "$forbidden" ]; then
  echo 'ERROR: Core/App depends on a legacy implementation detail:'
  echo "$forbidden"
  exit 1
fi

# UI bridge is implementation-agnostic except explicit provider composition / legacy adapter files.
bridge_forbidden=$(find "$UIBRIDGE" -type f -name '*.swift' \
  ! -name 'PrismDaemonProvider.swift' \
  ! -name 'PrismProviderComposition.swift' \
  -print0 | xargs -0 grep -InE '(/basebin/|jbctl|apt-get|dpkg-query|prismd\.sock|/var/jb)' 2>/dev/null || true)
if [ -n "$bridge_forbidden" ]; then
  echo 'ERROR: non-legacy PrismUIBridge source depends on a legacy implementation detail:'
  echo "$bridge_forbidden"
  exit 1
fi

# Release identity must be the Core Freeze build.
grep -q 'MARKETING_VERSION = 0.4.1;' "$ROOT/Prism.xcodeproj/project.pbxproj"
grep -q 'CURRENT_PROJECT_VERSION = 52;' "$ROOT/Prism.xcodeproj/project.pbxproj"
grep -q 'serviceVersion: "0.4.1"' "$ROOT/Packages/PrismCore/Sources/PrismDaemonCore/PrismDaemonService.swift"
grep -q 'version: "0.4.1"' "$UIBRIDGE/PrismDaemonProvider.swift"

"$ROOT/Scripts/VerifyArchitecture.command"
"$ROOT/Scripts/VerifyUI.command"
"$ROOT/Scripts/VerifyAppIcon.command"
"$ROOT/Scripts/VerifyXcodePlatform.command"
"$ROOT/Scripts/VerifyXcodeObjectIDs.command"
"$ROOT/Scripts/VerifyXcodeProject.command"
"$ROOT/Scripts/VerifyXcodeDestination.command"
"$ROOT/Scripts/VerifyLocalization.command"
"$ROOT/Scripts/VerifyRepositoryVisuals.command"
"$ROOT/Scripts/VerifyPackageRemovalUI.command"
"$ROOT/Scripts/VerifySources2.command"
"$ROOT/Scripts/VerifyPackageVisualCoverage.command"
"$ROOT/Scripts/VerifyModernAppManagementCopy.command"
"$ROOT/Scripts/VerifyGlobalLog.command"
"$ROOT/Scripts/VerifyCommerce.command"
"$ROOT/Scripts/VerifyFutureWiring.command"
"$ROOT/Scripts/VerifyApplicationRuntimeWiring.command"
"$ROOT/Scripts/VerifyRuntimeServiceBridge.command"
"$ROOT/Scripts/VerifyCompleteStore.command"
"$ROOT/Scripts/VerifyDarwinPosixSpawn.command"
"$ROOT/Scripts/VerifyBuildCommand.command"

echo 'Prism 0.4.1 Core Contract Freeze release gate completed.'
