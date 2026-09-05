#!/bin/bash
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
APP="$ROOT/App"
UI="$ROOT/Packages/PrismCore/Sources/PrismUIBridge"
DOMAIN="$ROOT/Packages/PrismCore/Sources/PrismDomain"
REPOS="$ROOT/Packages/PrismCore/Sources/PrismRepositories"

fail_if_matches() {
  local label="$1"; shift
  local pattern="$1"; shift
  local output=""
  for path in "$@"; do
    [ -e "$path" ] || continue
    if [ -d "$path" ]; then
      output+="$(grep -RInE --include='*.swift' "$pattern" "$path" 2>/dev/null || true)"
    else
      output+="$(grep -InE "$pattern" "$path" 2>/dev/null || true)"
    fi
  done
  if [ -n "$output" ]; then
    echo "ERROR: $label"
    echo "$output"
    exit 1
  fi
}

# App composition must be runtime-aware. Legacy compatibility is allowed only behind adapters.
fail_if_matches "App defaults to compatibilityFactory" 'compatibilityFactory[[:space:]]*\(' "$APP"
fail_if_matches "App hard-codes hybrid startup mode" 'mode:[[:space:]]*\.hybrid' "$APP"

# Repository UI/application wiring must not construct compatibility parser/providers directly.
[ -f "$UI/RepositoryCatalogClient.swift" ] && \
  fail_if_matches "RepositoryCatalogClient directly owns SileoRepositoryProvider" 'SileoRepositoryProvider[[:space:]]*\(' "$UI/RepositoryCatalogClient.swift"
[ -f "$UI/RepositoryCatalogClient.swift" ] && \
  fail_if_matches "RepositoryCatalogClient reads APT implementation filenames" '"(Release|Packages|Packages\.gz|SileoDepiction)"' "$UI/RepositoryCatalogClient.swift"

# Presentation decisions must come from descriptors/capabilities, never product names.
PRESENTATION_PATHS=("$APP" "$UI/Presentation.swift" "$UI/RuntimeIsolationPolicy.swift" "$UI/RuntimePresentationDescriptor.swift")
fail_if_matches "Presentation branches on RELAXIN product name" 'contains[[:space:]]*\([[:space:]]*"relaxin"' "${PRESENTATION_PATHS[@]}"
fail_if_matches "Presentation compares runtimeIdentity to a product literal" 'runtimeIdentity[[:space:]]*==[[:space:]]*"' "${PRESENTATION_PATHS[@]}"

# Positive wiring contracts. Skip only when running the negative fixture self-test with an intentionally partial tree.
if [ -f "$APP/AppContainer.swift" ] && [ -f "$UI/RepositoryCatalogClient.swift" ]; then
  grep -q 'runtimeAwareResolver' "$APP/AppContainer.swift"
  grep -q 'RepositoryProviderResolver' "$UI/RepositoryCatalogClient.swift"
  grep -q 'struct CapabilityIdentifier' "$DOMAIN/CapabilityModels.swift"
  grep -q 'capabilityStates: \[CapabilityIdentifier: CapabilityState\]' "$DOMAIN/ContractVersions.swift"
  grep -q 'protocol RepositoryProviderProbing' "$REPOS/RepositoryProvider.swift"
  grep -q 'struct ProviderOperationContext' "$REPOS/RepositoryProvider.swift"
fi

echo 'Prism Architecture Gate 4.0 / Future Wiring contract OK.'
