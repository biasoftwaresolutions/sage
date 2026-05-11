#!/bin/bash
# Remove sage from Claude Code and Claude Desktop.
# Wiki data at ~/sage/ is not touched.
#
# Usage:
#   bash uninstall.sh            → global CLAUDE.md
#   bash uninstall.sh --project  → project CLAUDE.md

set -e

MODE="${1:---global}"
SKIPPED=()
REMOVED=()

# ── Claude Code ───────────────────────────────────────────────────────
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
    REMOVED+=("Claude Code (CLAUDE.md)")
else
    SKIPPED+=("Claude Code ($CC_TARGET not found)")
fi

# ── Claude Desktop ────────────────────────────────────────────────────
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
    REMOVED+=("Claude Desktop (MCP config)")
else
    SKIPPED+=("Claude Desktop (config not found)")
fi

# ── Summary ───────────────────────────────────────────────────────────
echo ""
[ ${#REMOVED[@]} -gt 0 ] && echo "  Removed: ${REMOVED[*]}"
if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo "  Skipped:"
    for item in "${SKIPPED[@]}"; do echo "    · $item"; done
fi
echo ""
echo "  Wiki data at ~/sage/ was not touched."
echo "  Restart Claude Code / Claude Desktop to apply."
