#!/bin/bash
# Installs StudyBuddy.app to /Applications from the latest GitHub release,
# and clears the Gatekeeper quarantine flag so it opens with no warnings.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tylko17/studybuddy/main/install.sh | bash
set -euo pipefail

REPO="tylko17/studybuddy"
APP_NAME="StudyBuddy.app"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/StudyBuddy.app.zip"
TMP_DIR="$(mktemp -d)"

echo "==> Downloading latest StudyBuddy release"
curl -fsSL "$ZIP_URL" -o "${TMP_DIR}/StudyBuddy.app.zip"

echo "==> Extracting"
ditto -x -k "${TMP_DIR}/StudyBuddy.app.zip" "$TMP_DIR"

echo "==> Installing to /Applications"
rm -rf "/Applications/${APP_NAME}"
ditto "${TMP_DIR}/${APP_NAME}" "/Applications/${APP_NAME}"
rm -rf "$TMP_DIR"

echo "==> Clearing quarantine flag and re-signing"
xattr -cr "/Applications/${APP_NAME}"
codesign --force --deep --sign - "/Applications/${APP_NAME}"

echo "==> Launching StudyBuddy"
open "/Applications/${APP_NAME}"

echo "Done. Look for the book icon in your menu bar."
