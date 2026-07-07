#!/bin/bash
# Builds, signs, verifies, and (optionally) notarizes Restack.app for
# Developer ID distribution outside the Mac App Store.
#
# Env vars (both optional):
#   SIGN_IDENTITY   - e.g. "Developer ID Application: Jane Doe (TEAMID1234)"
#                     If unset, the app is ad-hoc signed and notarization is
#                     skipped. See docs/DISTRIBUTION.md to obtain one.
#   NOTARY_PROFILE  - a keychain profile name created with
#                     `xcrun notarytool store-credentials`. Only used when
#                     SIGN_IDENTITY is also set.
#
# Usage:
#   scripts/release.sh                                  # ad-hoc, no notarization
#   SIGN_IDENTITY="Developer ID Application: ..." scripts/release.sh          # signed, no notarization
#   SIGN_IDENTITY="..." NOTARY_PROFILE="restack-notary" scripts/release.sh    # signed + notarized
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Restack"
APP_BUNDLE="$ROOT_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS="$ROOT_DIR/${APP_NAME}.entitlements"
ZIP_PATH="$ROOT_DIR/${APP_NAME}.zip"

# shellcheck source=lib/assemble-app.sh
source "$ROOT_DIR/scripts/lib/assemble-app.sh"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

SIGN_MODE="ad-hoc"
NOTARIZE_STATUS="skipped"

echo "==================================================================="
echo " Restack release build"
echo "==================================================================="

build_restack_release_binary
assemble_restack_app_bundle

echo "==================================================================="
echo " Code signing"
echo "==================================================================="

if [ -n "$SIGN_IDENTITY" ]; then
    echo "==> Signing with Developer ID identity: $SIGN_IDENTITY"
    echo "==> Hardened Runtime + secure timestamp + entitlements: $ENTITLEMENTS"
    codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE"
    SIGN_MODE="developer-id"
else
    echo "warning: SIGN_IDENTITY is not set." >&2
    echo "warning: Falling back to ad-hoc signing (--sign -)." >&2
    echo "warning: This build is NOT suitable for distribution outside this Mac." >&2
    echo "warning: See docs/DISTRIBUTION.md to set up a Developer ID certificate." >&2
    codesign --force --sign - "$APP_BUNDLE"
    SIGN_MODE="ad-hoc"
fi

echo "==================================================================="
echo " Verification"
echo "==================================================================="

echo "==> codesign --verify --strict"
codesign --verify --strict --verbose=2 "$APP_BUNDLE"

echo "==> spctl assessment (informational; expected to fail pre-notarization)"
spctl -a -vvv --type exec "$APP_BUNDLE" || true

echo "==================================================================="
echo " Notarization"
echo "==================================================================="

if [ "$SIGN_MODE" = "developer-id" ] && [ -n "$NOTARY_PROFILE" ]; then
    echo "==> Zipping ${APP_NAME}.app for submission"
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

    echo "==> Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
    if xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait; then
        echo "==> Notarization succeeded; stapling ticket"
        xcrun stapler staple "$APP_BUNDLE"

        echo "==> Re-checking spctl assessment (should now say 'accepted')"
        spctl -a -vvv --type exec "$APP_BUNDLE" || true

        NOTARIZE_STATUS="notarized"
    else
        echo "error: notarization failed; see log above (rerun with 'xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE' for details)" >&2
        NOTARIZE_STATUS="failed"
    fi

    echo "==> Cleaning up ${APP_NAME}.zip"
    rm -f "$ZIP_PATH"
elif [ "$SIGN_MODE" = "developer-id" ]; then
    echo "NOTARY_PROFILE not set; skipping notarization (signed build only)."
    NOTARIZE_STATUS="skipped"
else
    echo "Ad-hoc build; notarization is not possible without a Developer ID signature. Skipping."
    NOTARIZE_STATUS="skipped"
fi

echo "==================================================================="
echo " Final status"
echo "==================================================================="

if [ "$SIGN_MODE" = "developer-id" ]; then
    echo "Signed:       Developer ID (\"$SIGN_IDENTITY\")"
else
    echo "Signed:       ad-hoc (not for distribution)"
fi

case "$NOTARIZE_STATUS" in
    notarized) echo "Notarized:    yes" ;;
    failed)    echo "Notarized:    FAILED (see log above)" ;;
    skipped)   echo "Notarized:    skipped" ;;
esac

echo "App bundle:   $APP_BUNDLE"

if [ "$NOTARIZE_STATUS" = "failed" ]; then
    exit 1
fi
