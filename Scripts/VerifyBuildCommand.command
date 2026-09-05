#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/Build.command"

if [ ! -f "$BUILD" ]; then
  echo "ERROR: Build.command is missing."
  exit 1
fi
if [ ! -x "$BUILD" ]; then
  echo "ERROR: Build.command is not executable."
  exit 1
fi

grep -q 'VerifyPrismCoreFreeze.command' "$BUILD"
grep -q 'generic/platform=iOS' "$BUILD"
grep -q 'generic/platform=iOS Simulator' "$BUILD"
grep -q 'CODE_SIGNING_ALLOWED=NO' "$BUILD"
grep -q 'Payload' "$BUILD"
grep -q 'STAGING_ROOT="$DIST/.staging"' "$BUILD"
grep -q '"$DIST/latest"' "$BUILD"

if grep -qE 'DEVELOPMENT_TEAM[[:space:]]*=' "$BUILD"; then
  echo "ERROR: Build.command must not hard-code a signing team."
  exit 1
fi

echo "Prism Build.command contract OK."
