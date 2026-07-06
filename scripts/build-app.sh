#!/bin/bash
# Builds Restack.app from the SwiftPM RestackApp executable target.
# Usage: scripts/build-app.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Restack"
APP_BUNDLE="$ROOT_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building release binary (swift build -c release)"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/RestackApp"
if [ ! -f "$BIN_PATH" ]; then
    echo "error: expected built binary at $BIN_PATH but it was not found" >&2
    exit 1
fi

echo "==> Assembling ${APP_NAME}.app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

echo "==> Writing Info.plist"
/usr/libexec/PlistBuddy -c "Clear dict" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true

# Start from App/Info.plist, then override/add the required keys.
cp "$ROOT_DIR/App/Info.plist" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :CFBundleExecutable" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :CFBundleIdentifier" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.restack.app" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :CFBundleName" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :LSUIElement" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :LSMinimumSystemVersion" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :CFBundlePackageType" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$CONTENTS_DIR/Info.plist"

echo "==> Ad-hoc code signing (best-effort)"
if codesign --force --deep --sign - "$APP_BUNDLE"; then
    echo "==> Code signing succeeded"
else
    echo "warning: codesign failed; continuing without a valid signature" >&2
fi

echo "==> Done"
echo "$APP_BUNDLE"
