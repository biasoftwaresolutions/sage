#!/bin/bash
# Remove sage from Claude Code and Claude Desktop.
# Preserves ~/sage/sources/ and ~/sage/wiki/ — all knowledge data is untouched.
#
# Usage:
#   bash uninstall.sh            → global CLAUDE.md
#   bash uninstall.sh --project  → project CLAUDE.md

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODE="${1:---global}"
SKIPPED=()
REMOVED=()

SAGE_ROOT="${SAGE_ROOT:-$HOME/sage}"
COMMANDS_DIR="$HOME/.claude/commands"

# ── Claude Code: CLAUDE.md ────────────────────────────────────────────
echo ""
echo "  Checking Claude Code..."

if [ "$MODE" = "--global" ]; then
    CC_TARGET="$HOME/.claude/CLAUDE.md"
else
    CC_TARGET="CLAUDE.md"
fi

if [ -f "$CC_TARGET" ]; then
    python3 -c "
import re, os
text = open('$CC_TARGET').read()
cleaned = re.sub(r'\n*## sage — Personal Knowledge Wiki\n.*?(?=\n## |\Z)', '', text, flags=re.DOTALL).rstrip()
if cleaned:
    open('$CC_TARGET', 'w').write(cleaned + '\n')
    print('  ✓ sage section removed from $CC_TARGET')
else:
    os.remove('$CC_TARGET')
    print('  ✓ $CC_TARGET removed (was empty)')
"
    REMOVED+=("CLAUDE.md")
else
    SKIPPED+=("CLAUDE.md ($CC_TARGET not found)")
fi

# ── Claude Code: MCP entry in ~/.claude.json ─────────────────────────
CC_MCP="$HOME/.claude.json"
if [ -f "$CC_MCP" ]; then
    python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.claude.json")
try:
    with open(path) as f:
        config = json.load(f)
    removed = config.get("mcpServers", {}).pop("sage", None)
    with open(path, "w") as f:
        json.dump(config, f, indent=2)
    if removed:
        print("  ✓ sage MCP removed from ~/.claude.json")
    else:
        print("  · sage was not in ~/.claude.json")
except Exception as e:
    print(f"  · Error updating ~/.claude.json: {e}")
PYEOF
    REMOVED+=("Claude Code MCP (~/.claude.json)")
else
    SKIPPED+=("~/.claude.json (not found)")
fi

# ── Claude Code: slash commands ───────────────────────────────────────
COMMANDS_REMOVED=0
for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate sage-meeting sage-memory; do
    if [ -f "$COMMANDS_DIR/${skill}.md" ]; then
        rm -f "$COMMANDS_DIR/${skill}.md"
        COMMANDS_REMOVED=$((COMMANDS_REMOVED + 1))
    fi
done
if [ "$COMMANDS_REMOVED" -gt 0 ]; then
    echo "  ✓ $COMMANDS_REMOVED slash commands removed from $COMMANDS_DIR/"
    REMOVED+=("slash commands")
else
    echo "  · No sage slash commands found in $COMMANDS_DIR/"
fi

# ── Claude Desktop: MCP ───────────────────────────────────────────────
echo ""
echo "  Checking Claude Desktop..."

DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [ -f "$DESKTOP_CONFIG" ]; then
    python3 - << 'PYEOF'
import json, os
config_path = os.path.expanduser("~/Library/Application Support/Claude/claude_desktop_config.json")
try:
    with open(config_path) as f:
        config = json.load(f)
    removed = config.get("mcpServers", {}).pop("sage", None)
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
    if removed:
        print("  ✓ sage MCP removed from Claude Desktop config")
    else:
        print("  · sage was not in Claude Desktop config")
except Exception as e:
    print(f"  · Error: {e}")
PYEOF
    REMOVED+=("Claude Desktop MCP")
else
    SKIPPED+=("Claude Desktop (config not found)")
fi

# ── LaunchAgent (macOS) ───────────────────────────────────────────────
PLIST="$HOME/Library/LaunchAgents/com.sage.daily-maintenance.plist"
if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "  ✓ LaunchAgent removed (com.sage.daily-maintenance)"
    REMOVED+=("LaunchAgent")
fi

# ── sage runtime files (skills + ops script, not wiki/sources) ────────
RUNTIME_REMOVED=0
for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate sage-meeting sage-memory; do
    if [ -f "$SAGE_ROOT/skills/${skill}.md" ]; then
        rm -f "$SAGE_ROOT/skills/${skill}.md"
        RUNTIME_REMOVED=$((RUNTIME_REMOVED + 1))
    fi
done
if [ "$RUNTIME_REMOVED" -gt 0 ]; then
    echo "  ✓ $RUNTIME_REMOVED skill files removed from $SAGE_ROOT/skills/"
    # Remove skills dir if now empty
    rmdir "$SAGE_ROOT/skills" 2>/dev/null && echo "  ✓ $SAGE_ROOT/skills/ removed (empty)" || true
    REMOVED+=("skill files")
fi

# Remove all sage-installed scripts (ops.py is legacy name)
SCRIPTS_REMOVED=0
for f in sage-operations.py ops.py daily-maintenance.sh install-launchagent.sh install-skills.sh; do
    if [ -f "$SAGE_ROOT/scripts/$f" ]; then
        rm -f "$SAGE_ROOT/scripts/$f"
        SCRIPTS_REMOVED=$((SCRIPTS_REMOVED + 1))
    fi
done
if [ "$SCRIPTS_REMOVED" -gt 0 ]; then
    echo "  ✓ $SCRIPTS_REMOVED script(s) removed from $SAGE_ROOT/scripts/"
    rmdir "$SAGE_ROOT/scripts" 2>/dev/null && echo "  ✓ $SAGE_ROOT/scripts/ removed (empty)" || true
    REMOVED+=("scripts")
fi

# ── Summary ───────────────────────────────────────────────────────────
echo ""
if [ ${#REMOVED[@]} -gt 0 ]; then
    echo "  Removed: ${REMOVED[*]}"
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo "  Skipped:"
    for item in "${SKIPPED[@]}"; do echo "    · $item"; done
fi
echo ""
echo "  Wiki data at $SAGE_ROOT/wiki/ and $SAGE_ROOT/sources/ was not touched."
echo "  Restart Claude Code / Claude Desktop to apply."
