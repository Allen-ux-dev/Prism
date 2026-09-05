#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="$ROOT/Packages/PrismCore/Sources/PrismDomain/CommerceModels.swift"
PROVIDER="$ROOT/Packages/PrismCore/Sources/PrismUIBridge/CommerceProvider.swift"
UI="$ROOT/App/Navigation/PrismRootView.swift"
for token in 'PrismCommerceAccessState' 'PrismCommerceProduct' 'PrismCommerceEntitlement'; do grep -Fq "$token" "$DOMAIN" || { echo "ERROR: commerce domain missing: $token"; exit 1; }; done
for token in 'protocol EntitlementProvider' 'protocol PurchaseProvider' 'RepositoryCommerceProvider' 'PrismCommerceMetadataParser'; do grep -Fq "$token" "$PROVIDER" || { echo "ERROR: commerce provider contract missing: $token"; exit 1; }; done
for token in 'Purchase entitlement is owned' 'No purchase adapter is available for this source.' 'Purchase Provider'; do grep -Fq "$token" "$UI" || { echo "ERROR: commerce UI missing: $token"; exit 1; }; done
if grep -RInE --include='*.swift' '(cardNumber|cvv|creditCard|debitCard)' "$ROOT/App" "$ROOT/Packages/PrismCore/Sources" >/dev/null; then
  echo 'ERROR: Prism must not store payment-card fields.'
  exit 1
fi
echo 'Prism commerce contract OK.'
