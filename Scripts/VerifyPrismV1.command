#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/Scripts/VerifyArchitecture.command"
"$ROOT/Scripts/VerifyUI.command"
"$ROOT/Scripts/VerifyAppIcon.command"
"$ROOT/Scripts/VerifyXcodeProject.command"
echo "Prism V1 verification gate completed."
