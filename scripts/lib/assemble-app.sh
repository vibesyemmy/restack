#!/bin/bash
# Shared bundle-assembly logic for Restack.app.
# Sourced by scripts/build-app.sh and scripts/release.sh — do not execute directly.
#
# Provides:
#   build_restack_release_binary   - swift build -c release, returns bin path via $BIN_PATH
#   assemble_restack_app_bundle    - builds Contents/{MacOS,Resources}/Info.plist from App/Info.plist
#
# Requires ROOT_DIR, APP_NAME, APP_BUNDLE, CONTENTS_DIR, MACOS_DIR, RESOURCES_DIR
# to already be set by the calling script.

build_restack_release_binary() {
    echo "==> Building release binary (swift build -c release)"
    swift build -c release

    BIN_PATH="$(swift build -c release --show-bin-path)/RestackApp"
    if [ ! -f "$BIN_PATH" ]; then
        echo "error: expected built binary at $BIN_PATH but it was not found" >&2
        exit 1
    fi
}

assemble_restack_app_bundle() {
    echo "==> Assembling ${APP_NAME}.app bundle"
    rm -rf "$APP_BUNDLE"
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

    cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
    chmod +x "$MACOS_DIR/$APP_NAME"

    echo "==> Writing Info.plist"
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
}
