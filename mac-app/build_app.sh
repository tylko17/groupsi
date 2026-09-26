#!/bin/bash
# Builds StudyBuddy.app - a standalone macOS menu bar app bundle.
#
# By default signs ad-hoc (fine for local testing, but macOS blocks it for
# anyone else who downloads it). Pass --notarize to sign with a Developer ID
# Application certificate and submit to Apple for notarization - requires:
#   - a "Developer ID Application" cert in your keychain (Xcode > Settings >
#     Accounts > Manage Certificates > + > Developer ID Application)
#   - notarytool credentials stored under the profile name below
#     (xcrun notarytool store-credentials studybuddy-notary --apple-id <id> --team-id <team>)
set -euo pipefail
cd "$(dirname "$0")"

NOTARIZE=false
if [[ "${1:-}" == "--notarize" ]]; then
    NOTARIZE=true
fi

DEVELOPER_ID="Developer ID Application: Luke Bula (CT4LUXQA4T)"
NOTARY_PROFILE="studybuddy-notary"

APP_NAME="StudyBuddy"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building release binary"
swift build -c release

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

if command -v iconutil >/dev/null 2>&1; then
    echo "==> Generating app icon"
    ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
    swift scripts/generate_icon.swift "${ICONSET_DIR}"
    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf "$(dirname "${ICONSET_DIR}")"
fi

if [ "$NOTARIZE" = true ]; then
    echo "==> Signing with Developer ID (hardened runtime)"
    codesign --force --deep --options runtime --sign "${DEVELOPER_ID}" "${APP_DIR}"

    echo "==> Submitting for notarization (this can take a few minutes)"
    NOTARIZE_ZIP="$(mktemp -d)/StudyBuddy-notarize.zip"
    ditto -c -k --keepParent "${APP_DIR}" "${NOTARIZE_ZIP}"
    xcrun notarytool submit "${NOTARIZE_ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
    rm -f "${NOTARIZE_ZIP}"

    echo "==> Stapling notarization ticket"
    xcrun stapler staple "${APP_DIR}"

    echo "==> Verifying Gatekeeper acceptance"
    spctl -a -vv "${APP_DIR}"
else
    echo "==> Ad-hoc signing app bundle (local testing only)"
    codesign --force --deep --sign - "${APP_DIR}"
fi

echo "==> Done: ${APP_DIR}"
echo "Run it with: open ${APP_DIR}"
