#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Jailbreak root literals belong only to environment providers and test fixtures.
search_roots=()
for candidate in App Packages/PrismCore/Sources Daemon; do
  [ -e "$candidate" ] && search_roots+=("$candidate")
done

if [ ${#search_roots[@]} -eq 0 ]; then
  exit 0
fi

violations=$(grep -RIn --include='*.swift' '/var/jb' "${search_roots[@]}" 2>/dev/null \
  | grep -v '/PrismEnvironment/' \
  | grep -v '/Tests/' || true)

if [ -n "$violations" ]; then
  echo "ERROR: hard-coded jailbreak root found outside PrismEnvironment/Test fixtures:"
  echo "$violations"
  exit 1
fi

echo "No hard-coded jailbreak root leaks found."
