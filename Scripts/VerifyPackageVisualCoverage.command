#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI="$ROOT/App/Navigation/PrismRootView.swift"
grep -q 'private struct PackageRow' "$UI"
grep -q 'PrismRemoteIcon' "$UI"
grep -q 'private struct SourceDetailView' "$UI"
grep -A80 'private struct SourceDetailView' "$UI" | grep -q 'PackageRow(row:'
grep -A80 'private struct PackageDetailView' "$UI" | grep -q 'PrismRemoteIcon'
echo 'Prism package visual coverage OK.'
