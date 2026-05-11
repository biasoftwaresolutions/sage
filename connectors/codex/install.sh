#!/bin/bash
# sage integration for Codex / OpenCode
# One command: AGENTS.md + wiki scaffold + sage-mcp install
#
# Usage:
#   bash install.sh             → global: ~/AGENTS.md + central wiki at ~/sage/
#   bash install.sh --project   → project-local: ./AGENTS.md + wiki in current dir
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:---global}"
. "$SCRIPT_DIR/../_shared/instructions.sh"

if [ "$MODE" = "--global" ]; then
    INSTRUCTIONS_FILE="$SCRIPT_DIR/../_shared/sage-instructions.md"
    TARGET="$HOME/AGENTS.md"
    WIKI_PATH="$HOME/sage/wiki"
elif [ "$MODE" = "--project" ]; then
    INSTRUCTIONS_FILE=$(mktemp) && sage_project_instructions "$SCRIPT_DIR/../_shared/sage-instructions.md" > "$INSTRUCTIONS_FILE"
    TARGET="AGENTS.md"
    WIKI_PATH="$(pwd)/wiki"
else
    echo "Usage: bash install.sh [--project]"
    exit 1
fi

# Instructions
sage_upsert_instructions "$TARGET" "$INSTRUCTIONS_FILE" "sage instructions"

# Wiki scaffold + sage-mcp install
if [ "$MODE" = "--global" ]; then
    bash "$SCRIPT_DIR/../_shared/scaffold.sh"
else
    bash "$SCRIPT_DIR/../_shared/scaffold.sh" --project
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
echo ""

# Auto-register MCP in ~/.codex/config.toml
CODEX_CONFIG="$HOME/.codex/config.toml"
if [ -f "$CODEX_CONFIG" ] && ! grep -q '\[mcp_servers.sage\]' "$CODEX_CONFIG"; then
    cat >> "$CODEX_CONFIG" << TOML

[mcp_servers.sage]
command = "python3"
args = ["-m", "sage_mcp", "--wiki", "$WIKI_PATH"]
TOML
    echo "  ✓ sage MCP registered in ~/.codex/config.toml"
elif [ ! -f "$CODEX_CONFIG" ]; then
    echo "  MCP config: add to ~/.codex/config.toml:"
    echo "  [mcp_servers.sage]"
    echo "  command = \"python3\""
    echo "  args = [\"-m\", \"sage_mcp\", \"--wiki\", \"$WIKI_PATH\"]"
fi
