#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$ROOT/Packages/PrismCore/Sources/PrismUIBridge/GlobalLog.swift"
UI="$ROOT/App/Navigation/PrismRootView.swift"
CONTAINER="$ROOT/App/AppContainer.swift"
test -f "$LOG"
for token in 'actor PrismLogStore' 'capacity' '<redacted>' 'exportText'; do grep -Fq "$token" "$LOG" || { echo "ERROR: global log core missing: $token"; exit 1; }; done
for token in 'GlobalLogView' 'View Global Log' 'logEntries' 'logExportText' 'clearLogs'; do grep -Fq "$token" "$UI" "$CONTAINER" || { echo "ERROR: global log UI missing: $token"; exit 1; }; done
echo 'Prism global log contract OK.'
