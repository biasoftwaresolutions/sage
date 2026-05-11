#!/bin/bash
# sage integration for Kiro
#
# Fresh install: sets up steering + scaffolds wiki at ~/sage/
# Update (re-run after git pull): updates steering + code files, never touches wiki data
#
# Usage:
#   bash install.sh             → global: ~/.kiro/steering + central wiki at ~/sage/
#   bash install.sh --project   → project-local: .kiro/steering + wiki in current dir
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../_shared/instructions.sh"
MODE="${1:---global}"

if [ "$MODE" = "--global" ]; then
    INSTRUCTIONS=$(cat "$SCRIPT_DIR/../_shared/sage-instructions.md")
    TARGET="$HOME/.kiro/steering/sage.md"
    mkdir -p "$HOME/.kiro/steering"

    # Always update steering — it may have changed
    echo "$INSTRUCTIONS" > "$TARGET"
    echo "sage steering → $TARGET"

    bash "$SCRIPT_DIR/../_shared/scaffold.sh"

    # Auto-register sage MCP server in Kiro's mcp.json
    MCP_CONFIG="$HOME/.kiro/settings/mcp.json"
    if [ -f "$MCP_CONFIG" ]; then
        if ! grep -q '"sage"' "$MCP_CONFIG"; then
            python3 - << 'PYEOF'
import json, pathlib, os
config_path = os.path.expanduser("~/.kiro/settings/mcp.json")
wiki_path = str(pathlib.Path.home() / "sage" / "wiki")
try:
    with open(config_path) as f:
        config = json.load(f)
    config.setdefault("mcpServers", {})["sage"] = {
        "command": "python3",
        "args": ["-m", "sage_mcp", "--wiki", wiki_path],
        "disabled": False
    }
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
    print("  ✓ sage MCP server registered in ~/.kiro/settings/mcp.json")
except Exception as e:
    print(f"  · Could not auto-register MCP: {e}")
    print(f"    Add manually: python3 -m sage_mcp --wiki {wiki_path}")
PYEOF
        else
            echo "  · sage MCP already registered in ~/.kiro/settings/mcp.json"
        fi
    fi

    if [ "$(uname)" = "Darwin" ]; then
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

elif [ "$MODE" = "--project" ]; then
    INSTRUCTIONS=$(sage_project_instructions "$SCRIPT_DIR/../_shared/sage-instructions.md")
    TARGET=".kiro/steering/sage.md"
    mkdir -p .kiro/steering

    echo "$INSTRUCTIONS" > "$TARGET"
    echo "sage steering → $TARGET"

    bash "$SCRIPT_DIR/../_shared/scaffold.sh" --project
    echo ""
    echo "Done. Drop sources into sources/ and say 'sage ingest' to process them."
else
    echo "Usage: bash install.sh [--project]"
    exit 1
fi
