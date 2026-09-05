#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY="$ROOT/Scripts/VerifyXcodeProject.command"

if ! grep -q -- "-destination 'generic/platform=iOS Simulator'" "$VERIFY"; then
  echo "ERROR: VerifyXcodeProject.command must use an explicit generic iOS Simulator destination."
  exit 1
fi

if grep -q -- '-sdk iphonesimulator' "$VERIFY" && ! grep -q -- "-destination 'generic/platform=iOS Simulator'" "$VERIFY"; then
  echo "ERROR: naked -sdk iphonesimulator can let Xcode choose a macOS destination."
  exit 1
fi

echo "Xcode simulator destination contract OK."
