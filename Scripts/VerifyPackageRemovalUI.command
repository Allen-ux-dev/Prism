#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI="$ROOT/App/Navigation/PrismRootView.swift"
CONTAINER="$ROOT/App/AppContainer.swift"
EN="$ROOT/App/en.lproj/Localizable.strings"
ZH="$ROOT/App/zh-Hans.lproj/Localizable.strings"

for token in 'removalPlanReview' 'preparePackageRemoval' 'confirmPreparedRemoval' 'RemovalPlanReviewView' 'Complete Removal' 'Preserved Dependencies' 'Residue Verification'; do
  grep -Fq "$token" "$UI" "$CONTAINER" || { echo "ERROR: package removal UI missing token: $token"; exit 1; }
done

for key in 'Remove' 'Complete Removal' 'Review Removal' 'Preserved Dependencies' 'Delete package configuration and managed cache data.' 'Residue Verification' 'Prism verifies package state again after removal.'; do
  grep -Fq "\"$key\"" "$EN" || { echo "ERROR: English removal localization missing: $key"; exit 1; }
  grep -Fq "\"$key\"" "$ZH" || { echo "ERROR: Chinese removal localization missing: $key"; exit 1; }
done

echo 'Prism package removal UI contract OK.'
