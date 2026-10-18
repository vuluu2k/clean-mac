#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v cwebp >/dev/null || { printf 'Install cwebp to generate optimized preview images.\n' >&2; exit 1; }
swift build
BIN="$(swift build --show-bin-path)"
WORK="$(mktemp -d "$PWD/.build/site-preview.XXXXXX")"
APP="$WORK/Preview.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" site/assets/screenshots
SOURCES=()
for source in Sources/CleanMac/*.swift; do
    [[ "$source" == "Sources/CleanMac/App.swift" ]] || SOURCES+=("$source")
done
swiftc -swift-version 6 -parse-as-library -I "$BIN/Modules" \
    "$BIN/CleanMacCore.build/"*.o "${SOURCES[@]}" Scripts/SitePreview.swift -o "$APP/Contents/MacOS/Preview"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier app.cleanmac.site-preview.$(uuidgen)" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Preview' "$APP/Contents/Info.plist"
cp -R "$BIN/clean-mac_CleanMacCore.bundle" "$APP/Contents/Resources/"
cp -R "$BIN/clean-mac_CleanMacCore.bundle/"*.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
for mode in storage-en storage-vi apps-en apps-vi confirm-en confirm-vi updates-en updates-vi; do
    "$APP/Contents/MacOS/Preview" "$mode" "$WORK/$mode.png"
    cwebp -quiet -lossless -z 9 "$WORK/$mode.png" -o "site/assets/screenshots/$mode.webp"
done
printf 'Captured production views with sample data. Raw PNGs: %s\n' "$WORK"
