#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/Daka.app"
SIGN_IDENTITY="${DAKA_SIGN_IDENTITY:--}"
CONFIGURATION="release"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            APP_DIR="$2"
            shift 2
            ;;
        --sign-identity)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        *)
            print -u2 "Unknown argument: $1"
            exit 2
            ;;
    esac
done

if [[ -z "$APP_DIR" || "$APP_DIR" == "/" || "$APP_DIR" != *.app ]]; then
    print -u2 "Output path must be a specific .app directory: $APP_DIR"
    exit 2
fi

VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"

/usr/bin/swift build -c "$CONFIGURATION" >&2
BIN_DIR="$(/usr/bin/swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$BIN_DIR/daka" "$MACOS_DIR/daka"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/daka"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/bin/codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR" >&2
"$ROOT_DIR/scripts/verify-app.sh" "$APP_DIR" "$VERSION" >&2

printf '%s\n' "$APP_DIR"
