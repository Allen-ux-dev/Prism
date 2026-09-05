#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

UI_FILE="App/Navigation/PrismRootView.swift"
PRESENTATION_FILES=(
  "Packages/PrismCore/Sources/PrismUIBridge/Presentation.swift"
  "Packages/PrismCore/Sources/PrismUIBridge/RuntimeIsolationPolicy.swift"
)

# Syntax parse is available even on non-Apple Swift toolchains.
swiftc -frontend -parse App/PrismApp.swift App/AppContainer.swift "$UI_FILE"

# iPhone navigation is intentionally capped at five primary destinations.
tab_count=$(grep -c '\.tabItem' "$UI_FILE" || true)
if [ "$tab_count" -ne 5 ]; then
  echo "ERROR: iPhone navigation must contain exactly 5 primary tabs; found $tab_count."
  exit 1
fi

# App UI must not know legacy field names or implementation paths.
app_forbidden=$(grep -InE '(/var/jb|apt-get|dpkg-query|prismd\.sock|Jailbreak Environment|Root Style|rootPrefix|packageDatabase|runShell|runAnyCommand)' \
  App/*.swift "$UI_FILE" 2>/dev/null || true)
if [ -n "$app_forbidden" ]; then
  echo "ERROR: ordinary App UI exposed a legacy/backend implementation detail:"
  echo "$app_forbidden"
  exit 1
fi

# Presentation may read legacy fields only to redact them for Advanced Diagnostics;
# it still must never contain concrete legacy paths or package-tool commands.
presentation_forbidden=$(grep -InE '(/var/jb|apt-get|dpkg-query|prismd\.sock|runShell|runAnyCommand)' \
  "${PRESENTATION_FILES[@]}" 2>/dev/null || true)
if [ -n "$presentation_forbidden" ]; then
  echo "ERROR: presentation layer contains a concrete backend implementation detail:"
  echo "$presentation_forbidden"
  exit 1
fi

# Keep the locked iOS 15 baseline.
new_api=$(grep -RInE --include='*.swift' '(NavigationStack|NavigationSplitView|ContentUnavailableView|@Observable|SwiftData)' App 2>/dev/null || true)
if [ -n "$new_api" ]; then
  echo "ERROR: UI contains API outside the locked iOS 15 baseline:"
  echo "$new_api"
  exit 1
fi

# Large fixed-width content blocks are a common compact-width/Dynamic-Type failure.
large_fixed_width=$(grep -InE '\.frame\(width: *[1-9][0-9]{2,}' "$UI_FILE" || true)
if [ -n "$large_fixed_width" ]; then
  echo "ERROR: large fixed-width UI content detected; use adaptive/maxWidth layout instead:"
  echo "$large_fixed_width"
  exit 1
fi

# Provider diagnostics must use adaptive vertical rows so long IDs, reasons and format lists wrap instead of colliding.
grep -q 'private struct AdvancedStatusRow' "$UI_FILE" || {
  echo "ERROR: Advanced Diagnostics must use its adaptive vertical status row."
  exit 1
}
grep -q 'fixedSize(horizontal: false, vertical: true)' "$UI_FILE" || {
  echo "ERROR: long provider/status text must be vertically expandable."
  exit 1
}

# Future-ready settings must expose the four quiet daily runtime rows.
for label in 'Runtime' 'Package Service' 'Compatibility' 'Background'; do
  grep -q "\"$label\"" Packages/PrismCore/Sources/PrismUIBridge/Presentation.swift || {
    echo "ERROR: missing future-ready daily status label: $label"
    exit 1
  }
done

# Old boolean-only app capability key must not drive the user-facing Apps page.
if grep -n 'capability("ipaInstall")\|contains("ipaInstall")' "$UI_FILE" >/dev/null; then
  echo "ERROR: Apps UI still depends on legacy ipaInstall capability instead of appInstall."
  exit 1
fi

echo "Prism future-ready UI layout, navigation, privacy, and iOS 15 syntax gates OK."
