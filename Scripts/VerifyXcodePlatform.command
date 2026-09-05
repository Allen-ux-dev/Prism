#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBX="$ROOT/Prism.xcodeproj/project.pbxproj"

# Prism is an iOS/iPadOS app target. Both Debug and Release must explicitly
# select the iPhoneOS SDK and advertise iPhoneOS + Simulator platforms.
count_sdk=$(grep -c 'SDKROOT = iphoneos;' "$PBX" || true)
count_platforms=$(grep -c 'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";' "$PBX" || true)
count_catalyst=$(grep -c 'SUPPORTS_MACCATALYST = NO;' "$PBX" || true)
count_mac_designed=$(grep -c 'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;' "$PBX" || true)

if [ "$count_sdk" -lt 2 ]; then
  echo "ERROR: Prism target must declare SDKROOT = iphoneos in Debug and Release."
  exit 1
fi
if [ "$count_platforms" -lt 2 ]; then
  echo 'ERROR: Prism target must declare SUPPORTED_PLATFORMS = "iphoneos iphonesimulator" in Debug and Release.'
  exit 1
fi
if [ "$count_catalyst" -lt 2 ]; then
  echo "ERROR: Prism target must explicitly disable Mac Catalyst for this iOS build contract."
  exit 1
fi
if [ "$count_mac_designed" -lt 2 ]; then
  echo "ERROR: Prism target must not expose a Designed-for-iPhone/iPad Mac destination."
  exit 1
fi

echo "Prism Xcode iOS platform contract OK."
