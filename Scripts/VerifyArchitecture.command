#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/Scripts/VerifyNoHardcodedJBRoot.command"
"$ROOT/Scripts/VerifyPrivilegedAPI.command"
(
  cd "$ROOT/Packages/PrismCore"
  swift build --product prismd
  swift test
)

echo "Prism architecture contract OK."
