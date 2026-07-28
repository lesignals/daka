#!/bin/zsh
set -euo pipefail

APP_DIR="${DAKA_APP_PATH:-$HOME/Applications/Daka.app}"
if [[ ! -x "$APP_DIR/Contents/MacOS/daka" ]]; then
    print -u2 "Daka app is not installed at $APP_DIR"
    exit 1
fi
exec "$APP_DIR/Contents/MacOS/daka"
