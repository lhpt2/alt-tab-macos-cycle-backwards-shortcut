#!/usr/bin/env bash
# Builds build/WindowSwitcher.app. Signs with $CODESIGN_IDENTITY (default "Local Self-Signed") when that
# certificate is in the keychain, else ad hoc. A stable signature keeps the Accessibility permission across
# rebuilds; with ad hoc signing macOS may ask for it again after every build.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
app=build/WindowSwitcher.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/WindowSwitcher" "$app/Contents/MacOS/WindowSwitcher"
cp Info.plist "$app/Contents/Info.plist"
identity="${CODESIGN_IDENTITY:-Local Self-Signed}"
if security find-identity -v -p codesigning | grep -qF "\"$identity\""; then
  codesign --force --sign "$identity" "$app"
else
  echo "Certificate \"$identity\" not found, signing ad hoc"
  codesign --force --sign - "$app"
fi
echo "Built $app"
