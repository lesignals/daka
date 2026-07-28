#!/bin/zsh
set -euo pipefail

LABEL="local.daka.menu"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="${DAKA_INSTALL_DIR:-$HOME/Applications}"
APP_DIR="$INSTALL_DIR/Daka.app"
APP_EXECUTABLE="$APP_DIR/Contents/MacOS/daka"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/Daka"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/Daka-install.XXXXXX")"
STAGED_APP="$STAGING_DIR/Daka.app"
PREVIOUS_APP="$STAGING_DIR/Previous-Daka.app"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR" "$INSTALL_DIR"
"$ROOT_DIR/scripts/build-app.sh" --output "$STAGED_APP" >/dev/null

if [[ -d "$APP_DIR" ]]; then
    mv "$APP_DIR" "$PREVIOUS_APP"
fi
if ! /usr/bin/ditto "$STAGED_APP" "$APP_DIR"; then
    if [[ -d "$PREVIOUS_APP" ]]; then
        mv "$PREVIOUS_APP" "$APP_DIR"
    fi
    exit 1
fi
if ! "$ROOT_DIR/scripts/verify-app.sh" "$APP_DIR" "$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"; then
    mv "$APP_DIR" "$STAGING_DIR/Failed-Daka.app"
    if [[ -d "$PREVIOUS_APP" ]]; then
        mv "$PREVIOUS_APP" "$APP_DIR"
    fi
    exit 1
fi

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_EXECUTABLE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
PLIST

if launchctl print "gui/$UID/$LABEL" >/dev/null 2>&1; then
    launchctl bootout "gui/$UID/$LABEL" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5; do
        if ! launchctl print "gui/$UID/$LABEL" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
fi

BOOTSTRAPPED=false
for _ in 1 2 3; do
    if launchctl bootstrap "gui/$UID" "$PLIST"; then
        BOOTSTRAPPED=true
        break
    fi
    sleep 1
done
if [[ "$BOOTSTRAPPED" != true ]]; then
    print -u2 "Failed to register $LABEL after 3 attempts."
    exit 1
fi
launchctl enable "gui/$UID/$LABEL"
launchctl kickstart -k "gui/$UID/$LABEL"

echo "Daka autostart installed and started."
echo "App: $APP_DIR"
echo "Logs: $LOG_DIR"
