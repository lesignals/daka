#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
PACKAGE_MINIMUM="$(/usr/bin/grep -Eo '\.macOS\(\.v[0-9]+\)' "$ROOT_DIR/Package.swift" | /usr/bin/grep -Eo '[0-9]+' | /usr/bin/head -1)"
PLIST_MINIMUM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$ROOT_DIR/Resources/Info.plist")"
FORMULA_VERSION="$(/usr/bin/grep -Eo 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+' "$ROOT_DIR/Formula/daka.rb" | /usr/bin/head -1 | /usr/bin/sed 's#refs/tags/v##')"

[[ "$VERSION" == "$PLIST_VERSION" ]] || {
    print -u2 "VERSION ($VERSION) and Info.plist ($PLIST_VERSION) disagree"
    exit 1
}
[[ "$PLIST_MINIMUM" == "$PACKAGE_MINIMUM.0" ]] || {
    print -u2 "Package.swift (macOS $PACKAGE_MINIMUM) and Info.plist ($PLIST_MINIMUM) disagree"
    exit 1
}
[[ "$VERSION" == "$FORMULA_VERSION" ]] || {
    print -u2 "VERSION ($VERSION) and Homebrew formula ($FORMULA_VERSION) disagree"
    exit 1
}

"$ROOT_DIR/scripts/build-app.sh" --output "$ROOT_DIR/.build/Daka.app" >/dev/null
"$ROOT_DIR/scripts/verify-app.sh" "$ROOT_DIR/.build/Daka.app" "$VERSION"
print "Release metadata is consistent for Daka $VERSION"
