#!/bin/bash
# sage daily maintenance — no LLM required.
# Deterministic lint fixes + macOS notification.
# Called by the LaunchAgent at the configured time daily.
#
# Environment variables (set by LaunchAgent plist):
#   SAGE_ROOT        path to sage repo/install
#   SAGE_LINT_HOUR   scheduled hour (0-23)
#   SAGE_LINT_MIN    scheduled minute (0-59)
#   SKIP_DELAY_CHECK set to 1 to bypass late-detection (used for postponed runs)

set -euo pipefail

SAGE_ROOT="${SAGE_ROOT:-$HOME/sage}"
SAGE_LINT_HOUR="${SAGE_LINT_HOUR:-18}"
SAGE_LINT_MIN="${SAGE_LINT_MIN:-0}"
SKIP_DELAY_CHECK="${SKIP_DELAY_CHECK:-}"
OPS="python3 $SAGE_ROOT/scripts/sage-operations.py"
THIS_SCRIPT="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

if [ ! -f "$SAGE_ROOT/scripts/sage-operations.py" ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: scripts/sage-operations.py not found at $SAGE_ROOT" >&2
    exit 1
fi

# ── late detection ────────────────────────────────────────────────────
# When the Mac is asleep at the scheduled time, launchd fires immediately
# on wake. Detect this and ask the user what they want to do.
if [ -z "$SKIP_DELAY_CHECK" ]; then
    CURRENT_TOTAL=$((10#$(date +%H) * 60 + 10#$(date +%M)))
    SCHEDULED_TOTAL=$((10#$SAGE_LINT_HOUR * 60 + 10#$SAGE_LINT_MIN))
    DIFF=$((CURRENT_TOTAL - SCHEDULED_TOTAL))

    # Handle midnight wrap-around (e.g. scheduled 23:50, current 00:10)
    if [ "$DIFF" -lt -120 ]; then
        DIFF=$((DIFF + 1440))
    fi

    SCHEDULED_DISPLAY=$(printf "%02d:%02d" "$SAGE_LINT_HOUR" "$SAGE_LINT_MIN")

    if [ "$DIFF" -gt 30 ]; then
        CHOICE=$(osascript << APPLESCRIPT 2>/dev/null || echo "Run Now"
set msg to "sage daily maintenance was scheduled for $SCHEDULED_DISPLAY, but your Mac was off." & return & return & "What would you like to do?"
set theResult to display dialog msg buttons {"Skip Today", "Postpone 2h", "Run Now"} default button "Run Now" with title "sage" with icon caution
return button returned of theResult
APPLESCRIPT
        )

        case "$CHOICE" in
            "Skip Today")
                echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] sage: skipped by user (${DIFF}min late)"
                exit 0 ;;
            "Postpone 2h")
                echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] sage: postponed 2h by user"
                nohup bash -c "sleep 7200 && \
                    SAGE_ROOT='$SAGE_ROOT' \
                    SAGE_LINT_HOUR='$SAGE_LINT_HOUR' \
                    SAGE_LINT_MIN='$SAGE_LINT_MIN' \
                    SKIP_DELAY_CHECK=1 \
                    bash '$THIS_SCRIPT'" > /dev/null 2>&1 &
                disown
                exit 0 ;;
            *)
                # "Run Now" or osascript failed — fall through
                ;;
        esac
    fi
fi

# ── lint with auto-fix ────────────────────────────────────────────────
LINT_JSON=$($OPS lint --fix 2>/dev/null || true)
ISSUES=$(echo "$LINT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['issue_count'])")
FIXED=$(echo "$LINT_JSON"  | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['auto_fixed']))")
SUMMARY=$(echo "$LINT_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
s = d.get('summary', {})
print(', '.join(f\"{v}x {k}\" for k, v in s.items()) or 'none')
")

# ── check for uningestd files ─────────────────────────────────────────
DISCOVER_JSON=$($OPS discover 2>/dev/null)
NEW_FILES=$(echo "$DISCOVER_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['new_count'])")

# ── macOS notification ────────────────────────────────────────────────
if [ "$NEW_FILES" -gt 0 ]; then
    SUBTITLE="${NEW_FILES} new file(s) ready — say 'sage ingest' to process"
else
    SUBTITLE="No new files"
fi

if [ "$ISSUES" -gt 0 ]; then
    BODY="$FIXED auto-fixed | $ISSUES flagged: $SUMMARY"
else
    BODY="Wiki is clean"
fi

osascript -e "display notification \"$BODY\" with title \"sage\" subtitle \"$SUBTITLE\""

# ── weekly digest (Sundays only) ─────────────────────────────────────
DOW=$(date +%u)  # 1=Mon … 7=Sun
if [ "$DOW" -eq 7 ]; then
    DIGEST_JSON=$($OPS digest --days 7 2>/dev/null || true)
    if [ -n "$DIGEST_JSON" ]; then
        ENTRY_COUNT=$(echo "$DIGEST_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['entry_count'])")
        BY_OP=$(echo "$DIGEST_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(', '.join(f\"{v}x {k}\" for k, v in d.get('by_operation', {}).items()) or 'no activity')
")
        osascript -e "display notification \"$BY_OP\" with title \"sage weekly digest\" subtitle \"$ENTRY_COUNT operations this week\""
    fi
fi

# ── log to stdout (captured by LaunchAgent plist) ─────────────────────
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] sage: fixed=$FIXED, remaining=$ISSUES, new_files=$NEW_FILES"
