#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/App"
STORE="$APP/Store"
UIBRIDGE="$ROOT/Packages/PrismCore/Sources/PrismUIBridge"
PBX="$ROOT/Prism.xcodeproj/project.pbxproj"

# Build identity.
grep -q 'CURRENT_PROJECT_VERSION = 52;' "$PBX"

# Complete Store files.
for f in StoreSharedViews.swift FeaturedView.swift PackagesView.swift SourcesView.swift AppsView.swift ActivityView.swift SettingsView.swift; do
  test -f "$STORE/$f"
done

# Root navigation remains exactly five modern phone destinations and routes to the Complete Store views.
ROOTVIEW="$APP/Navigation/PrismRootView.swift"
for view in StoreFeaturedView StorePackagesView StoreSourcesView StoreAppsView StoreActivityView; do
  grep -q "$view()" "$ROOTVIEW"
done
count=$(sed -n '/private var phoneLayout/,/^    }/p' "$ROOTVIEW" | grep -c 'tabItem' || true)
[ "$count" -eq 5 ] || { echo "ERROR: phone root tab count is $count, expected 5"; exit 1; }
! sed -n '/private var phoneLayout/,/^    }/p' "$ROOTVIEW" | grep -q 'SettingsView'

# Store domain / filters / details / activity buckets.
grep -q 'struct PrismStoreQuery' "$UIBRIDGE/StorePresentation.swift"
grep -q 'enum PrismPackageInstallationFilter' "$UIBRIDGE/StorePresentation.swift"
grep -q 'enum PrismPackageCommerceFilter' "$UIBRIDGE/StorePresentation.swift"
grep -q 'struct PrismPackageDetailPresentation' "$UIBRIDGE/StorePresentation.swift"
grep -q 'struct PrismSourceDetailPresentation' "$UIBRIDGE/StorePresentation.swift"
grep -q 'enum PrismActivityBucket' "$UIBRIDGE/StorePresentation.swift"

# Apps must be real-runtime-first. Simulation is only under Advanced/Lab.
grep -q 'ApplicationManagementController' "$UIBRIDGE/ApplicationManagementController.swift"
grep -q 'queryApplicationState' "$UIBRIDGE/ApplicationManagementController.swift"
grep -q 'submitTransaction' "$UIBRIDGE/ApplicationManagementController.swift"
grep -q 'Register Application' "$STORE/AppsView.swift"
grep -q 'Repair / Refresh' "$STORE/AppsView.swift"
grep -q 'Remove Application' "$STORE/AppsView.swift"
grep -q 'Advanced / Lab' "$STORE/AppsView.swift"
grep -q 'Simulation Environment' "$STORE/AppsView.swift"

# Source/package product completeness.
grep -q 'Reset Filters' "$STORE/PackagesView.swift"
grep -q 'Dependencies' "$STORE/PackagesView.swift"
grep -q 'Requirements' "$STORE/PackagesView.swift"
grep -q 'Source Status' "$STORE/SourcesView.swift"
grep -q 'Remove Source' "$STORE/SourcesView.swift"
grep -q 'Needs Review / Recovery' "$STORE/ActivityView.swift"

# New Store files are in the Xcode target and PBX IDs remain structurally verified elsewhere.
for f in StoreSharedViews.swift FeaturedView.swift PackagesView.swift SourcesView.swift AppsView.swift ActivityView.swift SettingsView.swift; do
  grep -q "$f in Sources" "$PBX"
done

# Both localizations carry representative Build 52 strings.
for strings in "$APP/en.lproj/Localizable.strings" "$APP/zh-Hans.lproj/Localizable.strings"; do
  grep -q '"Categories" =' "$strings"
  grep -q '"Runtime Application Service" =' "$strings"
  grep -q '"Needs Review / Recovery" =' "$strings"
done

# Prism-facing store code must not grow raw privileged primitives.
forbidden=$(grep -RInE --include='*.swift' '(spawnRoot|coretrust_bug|fastPathSign|posix_spawn.*root|arbitrary shell|kernel address)' "$APP" "$UIBRIDGE" 2>/dev/null || true)
if [ -n "$forbidden" ]; then
  echo 'ERROR: Complete Store exposes a forbidden privileged primitive:'
  echo "$forbidden"
  exit 1
fi

echo 'Prism Complete Store / Architecture Gate 5.0 OK.'
