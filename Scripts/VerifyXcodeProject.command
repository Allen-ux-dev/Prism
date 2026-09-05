#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBX="$ROOT/Prism.xcodeproj/project.pbxproj"
SCHEME="$ROOT/Prism.xcodeproj/xcshareddata/xcschemes/Prism.xcscheme"

grep -q 'productName = PrismUIBridge;' "$PBX"
grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' "$PBX"
grep -q 'MARKETING_VERSION = 0.4.1;' "$PBX"
grep -q 'CURRENT_PROJECT_VERSION = 52;' "$PBX"
test -f "$SCHEME"

if command -v xcodebuild >/dev/null 2>&1; then
  VERIFY_DERIVED="$(mktemp -d "${TMPDIR:-/tmp}/prism-xcode-verify.XXXXXX")"
  trap 'rm -rf "$VERIFY_DERIVED"' EXIT
  xcodebuild \
    -project "$ROOT/Prism.xcodeproj" \
    -scheme Prism \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$VERIFY_DERIVED" \
    CODE_SIGNING_ALLOWED=NO \
    build
  echo "Xcode iOS Simulator build OK."
else
  echo "xcodebuild not present; project structure validated, Apple SDK build not executed."
fi
