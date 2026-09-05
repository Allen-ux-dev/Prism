#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

search_roots=()
for candidate in App Packages/PrismCore/Sources Daemon; do
  [ -e "$candidate" ] && search_roots+=("$candidate")
done

if [ ${#search_roots[@]} -eq 0 ]; then
  exit 0
fi

violations=$(grep -RInE --include='*.swift' '\b(runShell|runAnyCommand|executeArbitraryCommand)\b' "${search_roots[@]}" 2>/dev/null || true)
if [ -n "$violations" ]; then
  echo "ERROR: forbidden generic privileged API found:"
  echo "$violations"
  exit 1
fi

echo "Privileged API surface is typed/allowlisted."
