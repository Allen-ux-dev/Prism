#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI="$ROOT/App/Navigation/PrismRootView.swift"
CONTAINER="$ROOT/App/AppContainer.swift"
for token in 'SourceDetailView' 'Search this source' 'Remove Source' 'Packages in this Source' 'PrismRepositoryScope.filteredPackages'; do
  grep -Fq "$token" "$UI" || { echo "ERROR: Sources 2.0 UI missing: $token"; exit 1; }
done
grep -Fq 'func removeSource(_ source: PrismSourceRow)' "$CONTAINER" || { echo 'ERROR: direct source removal action missing'; exit 1; }
echo 'Prism Sources 2.0 contract OK.'
