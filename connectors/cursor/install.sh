#!/bin/bash
# sage integration for Cursor
# One command: rules + wiki scaffold + MCP registration
#
# Usage:
#   bash install.sh             → global: ~/.cursor/rules/sage.mdc + central wiki at ~/sage/
#   bash install.sh --project   → project-local: .cursor/rules/sage.mdc + wiki in current dir
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../_shared/instructions.sh"
MODE="${1:---global}"

if [ "$MODE" = "--global" ]; then
    INSTRUCTIONS=$(cat "$SCRIPT_DIR/../_shared/sage-instructions.md")
    TARGET="$HOME/.cursor/rules/sage.mdc"
    mkdir -p "$HOME/.cursor/rules"
    WIKI_PATH="$HOME/sage/wiki"
elif [ "$MODE" = "--project" ]; then
    INSTRUCTIONS=$(sage_project_instructions "$SCRIPT_DIR/../_shared/sage-instructions.md")
    TARGET=".cursor/rules/sage.mdc"
    mkdir -p .cursor/rules
    WIKI_PATH="$(pwd)/wiki"
else
    echo "Usage: bash install.sh [--project]"
    exit 1
fi

# Cursor rule with alwaysApply
cat > "$TARGET" << 'FRONTMATTER'
---
description: sage knowledge wiki context
alwaysApply: true
---

FRONTMATTER
echo "$INSTRUCTIONS" >> "$TARGET"
echo "sage rule → $TARGET"

# Wiki scaffold + sage-mcp install
if [ "$MODE" = "--global" ]; then
    bash "$SCRIPT_DIR/../_shared/scaffold.sh"
else
    bash "$SCRIPT_DIR/../_shared/scaffold.sh" --project
fi

# Auto-register MCP server in ~/.cursor/mcp.json
MCP_CONFIG="$HOME/.cursor/mcp.json"
if [ -f "$MCP_CONFIG" ]; then
    SAGE_WIKI_PATH="$WIKI_PATH" python3 - << 'PYEOF'
import json, os
config_path = os.path.expanduser("~/.cursor/mcp.json")
wiki_path = os.environ["SAGE_WIKI_PATH"]
try:
    with open(config_path) as f:
        config = json.load(f)
    config.setdefault("mcpServers", {})["sage"] = {
        "command": "python3",
        "args": ["-m", "sage_mcp", "--wiki", wiki_path]
    }
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
    print("  ✓ sage MCP registered in ~/.cursor/mcp.json")
except Exception as e:
    print(f"  · Could not auto-register MCP: {e}")
PYEOF
elif [ ! -f "$MCP_CONFIG" ]; then
    echo ""
    echo "  Add to ~/.cursor/mcp.json:"
    echo "  { \"mcpServers\": { \"sage\": { \"command\": \"python3\", \"args\": [\"-m\", \"sage_mcp\", \"--wiki\", \"$WIKI_PATH\"] } } }"
fi

if [ "$(uname)" = "Darwin" ] && [ "$MODE" = "--global" ]; then
    echo ""
    echo "  Setting up daily maintenance (6:00pm, no LLM)..."
    LINK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    if bash "$LINK_ROOT/scripts/install-launchagent.sh" "$HOME/sage" 2>/dev/null; then
        echo "  ✓ LaunchAgent installed — daily lint + notify at 6:00pm"
    else
        echo "  · Skipped LaunchAgent (run manually: bash $LINK_ROOT/scripts/install-launchagent.sh)"
    fi
fi

echo ""
echo "Done."
echo "  Drop sources into ~/sage/sources/ and say 'sage ingest' to process them."
echo "  View wiki: python ~/sage/wiki_server.py"
