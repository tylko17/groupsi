#!/bin/bash
# Builds StudyBuddy.app - a standalone macOS menu bar app bundle.
set -euo pipefail
cd "$(dirname "$0")"

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

echo "==> Done: ${APP_DIR}"
echo "Run it with: open ${APP_DIR}"
