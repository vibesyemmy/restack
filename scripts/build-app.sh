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

# shellcheck source=lib/assemble-app.sh
source "$ROOT_DIR/scripts/lib/assemble-app.sh"

build_restack_release_binary
assemble_restack_app_bundle

# Prefer a stable dev identity so the TCC/Accessibility grant survives rebuilds.
# Ad-hoc signatures change every build, invalidating the grant each time.
DEV_IDENTITY="${SIGN_IDENTITY:-Restack Dev}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$DEV_IDENTITY\""; then
    echo "==> Code signing with dev identity: $DEV_IDENTITY"
    codesign --force --deep --sign "$DEV_IDENTITY" "$APP_BUNDLE"
    echo "==> Code signing succeeded (stable identity — Accessibility grant persists)"
else
    echo "==> Ad-hoc code signing (best-effort; no '$DEV_IDENTITY' identity found)"
    if codesign --force --deep --sign - "$APP_BUNDLE"; then
        echo "==> Code signing succeeded"
    else
        echo "warning: codesign failed; continuing without a valid signature" >&2
    fi
fi

echo "==> Done"
echo "$APP_BUNDLE"
