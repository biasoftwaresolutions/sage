#!/bin/bash
# Install the sage daily maintenance LaunchAgent (macOS only).
# Runs scripts/sage-operations.py lint --fix + macOS notification daily at a configurable time.
#
# Usage:
#   bash install-launchagent.sh                            # default root ~/sage, time 18:00
#   bash install-launchagent.sh /path/to/sage              # custom root
#   bash install-launchagent.sh --time 20:30               # custom time (8:30pm)
#   bash install-launchagent.sh /path/to/sage --time 09:00 # both
#   bash install-launchagent.sh --uninstall                # remove

set -e

LABEL="com.sage.daily-maintenance"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── parse args ────────────────────────────────────────────────────────
SAGE_ROOT=""
LINT_HOUR="18"
LINT_MIN="0"
UNINSTALL=false

while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall)
            UNINSTALL=true ;;
        --time)
            shift
            LINT_HOUR="${1%%:*}"
            LINT_MIN="${1##*:}"
            # strip leading zeros for plist (integer fields don't allow them)
            LINT_HOUR=$((10#$LINT_HOUR))
            LINT_MIN=$((10#$LINT_MIN)) ;;
        *)
            SAGE_ROOT="$(cd "$1" && pwd)" ;;
    esac
    shift
done

# ── uninstall ─────────────────────────────────────────────────────────
if $UNINSTALL; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "  ✓ LaunchAgent removed"
    exit 0
fi

SAGE_ROOT="${SAGE_ROOT:-${SAGE_ROOT:-$HOME/sage}}"

# ── validate ──────────────────────────────────────────────────────────
if [ ! -f "$SAGE_ROOT/scripts/sage-operations.py" ]; then
    echo "Error: scripts/sage-operations.py not found at $SAGE_ROOT/scripts/sage-operations.py"
    echo "  Pass the correct sage root as an argument, or run scaffold first."
    exit 1
fi

MAINTENANCE_SCRIPT="$SAGE_ROOT/scripts/daily-maintenance.sh"
if [ ! -f "$MAINTENANCE_SCRIPT" ]; then
    MAINTENANCE_SCRIPT="$SCRIPT_DIR/daily-maintenance.sh"
fi
if [ ! -f "$MAINTENANCE_SCRIPT" ]; then
    echo "Error: daily-maintenance.sh not found (expected at $MAINTENANCE_SCRIPT)"
    exit 1
fi

DISPLAY_TIME=$(printf "%02d:%02d" "$LINT_HOUR" "$LINT_MIN")

# ── write plist ───────────────────────────────────────────────────────
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$MAINTENANCE_SCRIPT</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <key>SAGE_ROOT</key>
        <string>$SAGE_ROOT</string>
        <key>SAGE_LINT_HOUR</key>
        <string>$LINT_HOUR</string>
        <key>SAGE_LINT_MIN</key>
        <string>$LINT_MIN</string>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$LINT_HOUR</integer>
        <key>Minute</key>
        <integer>$LINT_MIN</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>/tmp/sage-maintenance.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/sage-maintenance.err</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST_EOF

# ── load (idempotent) ─────────────────────────────────────────────────
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "  ✓ LaunchAgent installed: $LABEL"
echo "  Fires daily at $DISPLAY_TIME"
echo "  SAGE_ROOT: $SAGE_ROOT"
echo "  Log: /tmp/sage-maintenance.log"
echo ""
echo "  Change time: bash $0 $SAGE_ROOT --time HH:MM"
echo "  Test now:    bash $MAINTENANCE_SCRIPT"
echo "  Uninstall:   bash $0 --uninstall"
