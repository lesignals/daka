#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/lint.sh"
/usr/bin/swift test
/usr/bin/swift build -c release -Xswiftc -warnings-as-errors
"$ROOT_DIR/scripts/check-release.sh"

if command -v brew >/dev/null 2>&1; then
    brew style "$ROOT_DIR/Formula/daka.rb"
else
    print -u2 "Homebrew is required to validate Formula/daka.rb"
    exit 1
fi

print "Quality gate passed"
