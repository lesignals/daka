#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    print -u2 "Usage: $0 APP_PATH [EXPECTED_VERSION]"
    exit 2
fi

APP_DIR="$1"
EXPECTED_VERSION="${2:-}"
PLIST="$APP_DIR/Contents/Info.plist"
EXECUTABLE="$APP_DIR/Contents/MacOS/daka"

[[ -d "$APP_DIR" ]] || { print -u2 "Missing app bundle: $APP_DIR"; exit 1; }
[[ -f "$PLIST" ]] || { print -u2 "Missing Info.plist: $PLIST"; exit 1; }
[[ -x "$EXECUTABLE" ]] || { print -u2 "Missing executable: $EXECUTABLE"; exit 1; }

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
MINIMUM_SYSTEM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")"
LOCATION_DESCRIPTION="$(/usr/libexec/PlistBuddy -c 'Print :NSLocationWhenInUseUsageDescription' "$PLIST")"

[[ "$BUNDLE_ID" == "local.daka.menu" ]] || { print -u2 "Unexpected bundle id: $BUNDLE_ID"; exit 1; }
[[ "$MINIMUM_SYSTEM" == "12.0" ]] || { print -u2 "Unexpected minimum macOS version: $MINIMUM_SYSTEM"; exit 1; }
[[ -n "$LOCATION_DESCRIPTION" ]] || { print -u2 "Missing location usage description"; exit 1; }
if [[ -n "$EXPECTED_VERSION" && "$VERSION" != "$EXPECTED_VERSION" ]]; then
    print -u2 "Expected version $EXPECTED_VERSION, found $VERSION"
    exit 1
fi

/usr/bin/codesign --verify --deep --strict "$APP_DIR"
print "Verified Daka.app $VERSION ($BUNDLE_ID), macOS $MINIMUM_SYSTEM+"
