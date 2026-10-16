#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'clean-mac requires macOS.\n' >&2
  exit 1
fi

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="${CLEAN_MAC_APP_PATH:-$PWD/dist/clean-mac.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CleanMac" "$APP/Contents/MacOS/CleanMac"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R "$BIN_DIR/clean-mac_CleanMacCore.bundle" "$APP/Contents/Resources/"
cp -R "$BIN_DIR/clean-mac_CleanMacCore.bundle/"*.lproj "$APP/Contents/Resources/"
swift Scripts/make-icon.swift "$PWD/dist"
iconutil -c icns "$PWD/dist/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
printf '\nApp ready: %s\n' "$APP"
