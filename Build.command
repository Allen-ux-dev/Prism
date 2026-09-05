#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"
STAGING_ROOT="$DIST/.staging"
RELEASES_ROOT="$DIST/releases"
LOGS_ROOT="$DIST/logs"
PROJECT="$ROOT/Prism.xcodeproj"
SCHEME="Prism"
PBX="$PROJECT/project.pbxproj"
STAMP="$(date '+%Y%m%d-%H%M%S')"
STAGE="$STAGING_ROOT/$STAMP-$$"
LOG_FILE="$LOGS_ROOT/build-$STAMP.log"

mkdir -p "$STAGING_ROOT" "$RELEASES_ROOT" "$LOGS_ROOT"
mkdir -p "$STAGE"

# Keep a log even when a build fails, but never publish partial artifacts.
exec > >(tee "$LOG_FILE") 2>&1

cleanup() {
  status=$?
  if [ -d "$STAGE" ]; then
    rm -rf "$STAGE"
  fi
  if [ "$status" -ne 0 ]; then
    echo
    echo "==> Build failed"
    echo "Previous successful artifacts were not changed."
    echo "Log: $LOG_FILE"
  fi
}
trap cleanup EXIT

echo "==> Prism Build"
echo "Project: $ROOT"
echo

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: Build.command must run on macOS with Xcode installed."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild was not found. Install the full Xcode app first."
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "ERROR: Xcode command-line tools are not pointing at a usable Xcode installation."
  echo "Open Xcode once, or select it with:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

if [ ! -f "$PBX" ]; then
  echo "ERROR: Prism.xcodeproj/project.pbxproj is missing."
  exit 1
fi

VERSION="$(grep -m1 'MARKETING_VERSION = ' "$PBX" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/')"
BUILD_NUMBER="$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PBX" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);.*/\1/')"

if [ -z "$VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
  echo "ERROR: Could not read Prism version/build from the Xcode project."
  exit 1
fi

RELEASE_ID="Prism-$VERSION-Build$BUILD_NUMBER-$STAMP"
OUTPUT="$STAGE/output"
DEVICE_DERIVED="$STAGE/DerivedData-device"
SIM_DERIVED="$STAGE/DerivedData-simulator"
mkdir -p "$OUTPUT"

echo "Version: $VERSION"
echo "Build:   $BUILD_NUMBER"
echo "Xcode:   $(xcodebuild -version | tr '\n' ' ')"
echo

echo "==> 1/4 Verify Core Freeze contracts"
"$ROOT/Scripts/VerifyPrismCoreFreeze.command"

echo
echo "==> 2/4 Build Release for iPhoneOS (unsigned)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DEVICE_DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  "CODE_SIGN_IDENTITY=" \
  build

DEVICE_APP_SOURCE="$DEVICE_DERIVED/Build/Products/Release-iphoneos/Prism.app"
if [ ! -d "$DEVICE_APP_SOURCE" ]; then
  echo "ERROR: iPhoneOS build succeeded but Prism.app was not found at:"
  echo "  $DEVICE_APP_SOURCE"
  exit 1
fi

DEVICE_APP="$OUTPUT/Prism-device.app"
/usr/bin/ditto "$DEVICE_APP_SOURCE" "$DEVICE_APP"
rm -rf "$DEVICE_APP/_CodeSignature"
rm -f "$DEVICE_APP/embedded.mobileprovision"

PAYLOAD="$STAGE/Payload"
mkdir -p "$PAYLOAD"
/usr/bin/ditto "$DEVICE_APP" "$PAYLOAD/Prism.app"
rm -rf "$PAYLOAD/Prism.app/_CodeSignature"
rm -f "$PAYLOAD/Prism.app/embedded.mobileprovision"

IPA_NAME="Prism-$VERSION-Build$BUILD_NUMBER-unsigned.ipa"
IPA_PATH="$OUTPUT/$IPA_NAME"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PAYLOAD" "$IPA_PATH"

echo
echo "==> 3/4 Build Release for iOS Simulator"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$SIM_DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

SIM_APP_SOURCE="$SIM_DERIVED/Build/Products/Release-iphonesimulator/Prism.app"
if [ ! -d "$SIM_APP_SOURCE" ]; then
  echo "ERROR: Simulator build succeeded but Prism.app was not found at:"
  echo "  $SIM_APP_SOURCE"
  exit 1
fi

/usr/bin/ditto "$SIM_APP_SOURCE" "$OUTPUT/Prism-simulator.app"

cat > "$OUTPUT/BUILD-INFO.txt" <<INFO
Prism $VERSION (Build $BUILD_NUMBER)
Built: $(date)
Scheme: $SCHEME
Configuration: Release

Artifacts:
- $IPA_NAME                 unsigned iPhoneOS IPA
- Prism-device.app          unsigned iPhoneOS application bundle
- Prism-simulator.app       iOS Simulator application bundle

The IPA is intentionally unsigned. No Apple Team ID or signing identity is embedded by Build.command.
INFO

echo
echo "==> 4/4 Publish artifacts atomically"
RELEASE_DIR="$RELEASES_ROOT/$RELEASE_ID"
if [ -e "$RELEASE_DIR" ]; then
  echo "ERROR: Release directory already exists: $RELEASE_DIR"
  exit 1
fi
mv "$OUTPUT" "$RELEASE_DIR"

LATEST_TMP="$DIST/.latest-$STAMP-$$"
rm -f "$LATEST_TMP"
ln -s "releases/$RELEASE_ID" "$LATEST_TMP"
if [ -e "$DIST/latest" ] && [ ! -L "$DIST/latest" ]; then
  echo "ERROR: dist/latest exists but is not a symlink. Refusing to overwrite it."
  exit 1
fi
mv -f "$LATEST_TMP" "$DIST/latest"

# Successful publication: derived-data staging can now be discarded by the trap.
echo
echo "==> Build complete"
echo "Release: $RELEASE_DIR"
echo "Latest:  $DIST/latest"
echo "IPA:     $DIST/latest/$IPA_NAME"
echo "Log:     $LOG_FILE"

echo
if command -v open >/dev/null 2>&1; then
  open "$DIST/latest" >/dev/null 2>&1 || true
fi
