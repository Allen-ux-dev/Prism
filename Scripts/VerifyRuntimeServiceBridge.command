#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/App/AppContainer.swift"
UI="$ROOT/App/Navigation/PrismRootView.swift"
EN="$ROOT/App/en.lproj/Localizable.strings"
ZH="$ROOT/App/zh-Hans.lproj/Localizable.strings"
CORE="$ROOT/Packages/PrismCore/Sources"

required_files=(
  "$CORE/PrismPrivilegedProtocol/RuntimeServiceMessages.swift"
  "$CORE/PrismPrivilegedProtocol/RuntimeServiceTransport.swift"
  "$CORE/PrismDaemonCore/RuntimeServiceBridge.swift"
  "$CORE/PrismDaemonCore/RuntimeServiceBridgeCoordinator.swift"
  "$CORE/PrismUIBridge/RuntimeBridgeController.swift"
)
for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || { echo "Missing Runtime Service Bridge file: $file"; exit 1; }
done

grep -q 'queryRuntimeBridgeStatus' "$CORE/PrismPrivilegedProtocol/Messages.swift"
grep -q 'reconnectRuntimeBridge' "$CORE/PrismPrivilegedProtocol/Messages.swift"
grep -q 'setRuntimeBackgroundEnabled' "$CORE/PrismPrivilegedProtocol/Messages.swift"
grep -q 'runtimeBackgroundRequested' "$APP"
grep -q 'setRuntimeBackgroundEnabled' "$APP"
grep -q 'Runtime Background Service' "$UI"
grep -q 'runtimeBridgeStatus.backgroundSupported' "$UI"
grep -q 'Reconnect Runtime Bridge' "$UI"
grep -q '"Runtime Background Service"' "$EN"
grep -q '"Runtime Background Service"' "$ZH"
grep -q '"Runtime Bridge Status"' "$EN"
grep -q '"Runtime Bridge Status"' "$ZH"

if grep -R -E 'shellCommand|processID|loaderArguments|signatureBypass|exploitChain' \
  "$CORE/PrismDaemonCore/RuntimeServiceBridge.swift" \
  "$CORE/PrismDaemonCore/RuntimeServiceBridgeCoordinator.swift" \
  "$CORE/PrismPrivilegedProtocol/RuntimeServiceMessages.swift" >/dev/null; then
  echo "Unsafe untyped runtime bridge surface detected."
  exit 1
fi

echo "Prism Runtime Service Bridge contract OK."
