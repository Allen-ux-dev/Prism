#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
UI="$ROOT/App/Navigation/PrismRootView.swift"

for token in 'PrismRemoteImageLoader' 'NSCache<NSURL, UIImage>' 'URLRequest' 'returnCacheDataElseLoad' 'source.displayName' 'source.iconURLs' 'row.iconURL'; do
  grep -Fq "$token" "$UI" || { echo "ERROR: repository/package visuals missing UI token: $token"; exit 1; }
done

grep -Fq 'Image(systemName: "shippingbox")' "$UI" || { echo 'ERROR: package icon fallback is missing'; exit 1; }
grep -Fq 'Image(systemName: "tray.full")' "$UI" || { echo 'ERROR: repository icon fallback is missing'; exit 1; }

echo 'Prism repository/package visual contract OK.'
