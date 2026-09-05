#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_CONTAINER="$ROOT/App/AppContainer.swift"
UI="$ROOT/App/Navigation/PrismRootView.swift"
PBX="$ROOT/Prism.xcodeproj/project.pbxproj"
EN="$ROOT/App/en.lproj/Localizable.strings"
ZH="$ROOT/App/zh-Hans.lproj/Localizable.strings"

for file in "$EN" "$ZH"; do
  test -f "$file" || { echo "ERROR: missing localization resource: $file"; exit 1; }
done

grep -q 'enum PrismLanguage' "$APP_CONTAINER" || { echo 'ERROR: missing PrismLanguage'; exit 1; }
grep -q 'case system' "$APP_CONTAINER" || { echo 'ERROR: missing system language option'; exit 1; }
grep -q 'case english' "$APP_CONTAINER" || { echo 'ERROR: missing English language option'; exit 1; }
grep -q 'case simplifiedChinese' "$APP_CONTAINER" || { echo 'ERROR: missing Simplified Chinese language option'; exit 1; }
grep -q 'PrismLanguage' "$UI" || { echo 'ERROR: Settings UI has no language picker'; exit 1; }

grep -q 'zh-Hans' "$PBX" || { echo 'ERROR: Xcode project does not include zh-Hans localization'; exit 1; }
grep -q 'Localizable.strings' "$PBX" || { echo 'ERROR: Localizable.strings is not in Xcode resources'; exit 1; }

for key in 'Featured' 'Packages' 'Sources' 'Apps' 'Activity' 'Settings' 'Language' 'Follow System' 'Simplified Chinese' 'English' 'Repositories' 'Add Source' 'Package Service'; do
  grep -Fq "\"$key\"" "$EN" || { echo "ERROR: English localization missing key: $key"; exit 1; }
  grep -Fq "\"$key\"" "$ZH" || { echo "ERROR: Chinese localization missing key: $key"; exit 1; }
done

echo 'Prism localization contract OK.'
