#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'DMG packaging requires macOS.\n' >&2
  exit 1
fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid release version.\n' >&2
  exit 1
fi
case "$(uname -m)" in
  arm64) OTHER_ARCH=x86_64 ;;
  x86_64) OTHER_ARCH=arm64 ;;
  *) printf 'Unsupported Mac architecture.\n' >&2; exit 1 ;;
esac
OUTPUT="$PWD/dist/releases"
NAME="clean-mac-$VERSION-universal.dmg"
if [[ -e "$OUTPUT/$NAME" || -e "$OUTPUT/SHA256SUMS" ]]; then
  printf 'Release output already exists; it will not be overwritten.\n' >&2
  exit 1
fi
mkdir -p "$PWD/.build" "$OUTPUT"
WORK="$(mktemp -d "$PWD/.build/distribution.XXXXXX")"
STAGE="$WORK/volume"
MOUNT="$WORK/mount"
mkdir -p "$STAGE" "$MOUNT"
APP="$STAGE/clean-mac.app"

CLEAN_MAC_APP_PATH="$APP" ./Scripts/build-app.sh
TRIPLE="$OTHER_ARCH-apple-macosx14.0"
swift build -c release --triple "$TRIPLE"
OTHER_BIN="$(swift build -c release --triple "$TRIPLE" --show-bin-path)"
lipo -create "$APP/Contents/MacOS/CleanMac" "$OTHER_BIN/CleanMac" -output "$WORK/CleanMac.universal"
mv "$WORK/CleanMac.universal" "$APP/Contents/MacOS/CleanMac"
lipo "$APP/Contents/MacOS/CleanMac" -verify_arch arm64 x86_64
codesign --force --sign - "$APP"
codesign --verify --strict --deep "$APP"
ln -s /Applications "$STAGE/Applications"
cp INSTALL.md "$STAGE/INSTALL.md"

IMAGE="$WORK/$NAME"
hdiutil create -volname "clean-mac $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO "$IMAGE"
hdiutil verify "$IMAGE"
MOUNTED=0
cleanup() {
  if [[ "$MOUNTED" == 1 ]]; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || printf 'Owned verification image is still mounted at %s; no force detach attempted.\n' "$MOUNT" >&2
  fi
}
trap cleanup EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$IMAGE" >/dev/null
MOUNTED=1
[[ "$(readlink "$MOUNT/Applications")" == /Applications ]]
[[ -f "$MOUNT/INSTALL.md" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT/clean-mac.app/Contents/Info.plist")" == "$VERSION" ]]
lipo "$MOUNT/clean-mac.app/Contents/MacOS/CleanMac" -verify_arch arm64 x86_64
codesign --verify --strict --deep "$MOUNT/clean-mac.app"
hdiutil detach "$MOUNT" >/dev/null
MOUNTED=0
mv "$IMAGE" "$OUTPUT/$NAME"
(cd "$OUTPUT" && shasum -a 256 "$NAME" > SHA256SUMS && shasum -a 256 -c SHA256SUMS)
printf '\nUniversal DMG ready: %s/%s\nAd-hoc signed; not Developer ID signed or notarized.\n' "$OUTPUT" "$NAME"
