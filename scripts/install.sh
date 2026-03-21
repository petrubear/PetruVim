#!/bin/zsh
# Installs PetruVim to /Applications, resets Accessibility so macOS prompts again.

APP=PetruVim
BUNDLE_ID=com.petru.PetruVim
BUILD=build/DerivedData/Build/Products/Release/${APP}.app
DEST=/Applications/${APP}.app

set -e

echo "==> Building ${APP}..."
xcodegen generate
xcodebuild -project ${APP}.xcodeproj -scheme ${APP} -configuration Release -derivedDataPath build/DerivedData

echo "==> Stopping ${APP} (if running)..."
pkill -x "$APP" 2>/dev/null || true
sleep 0.5

echo "==> Resetting Accessibility permission..."
tccutil reset Accessibility "$BUNDLE_ID"

echo "==> Copying to ${DEST}..."
rm -rf "$DEST"
cp -R "$BUILD" "$DEST"

echo "==> Done. Launch ${APP} to grant Accessibility access."
