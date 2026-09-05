#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if grep -R -n -E 'White-Troll|TrollFools|TrollStore|白巨魔|巨魔风格' "$ROOT/App" --include='*.swift' --include='*.strings'; then
  echo 'Legacy branded app-management copy found in user-facing resources.' >&2
  exit 1
fi
grep -q 'Application Installation' "$ROOT/App/en.lproj/Localizable.strings"
grep -q 'Application Injection' "$ROOT/App/en.lproj/Localizable.strings"
echo 'Prism modern app-management copy OK.'
