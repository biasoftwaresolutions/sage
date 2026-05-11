#!/bin/bash
# sage integration for Google Antigravity (Gemini CLI)
# One command: GEMINI.md + wiki scaffold + sage-mcp install
#
# Usage:
#   bash install.sh             → global: ~/.gemini/GEMINI.md + central wiki at ~/sage/
#   bash install.sh --project   → project-local: ./GEMINI.md + wiki in current dir
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:---global}"
. "$SCRIPT_DIR/../_shared/instructions.sh"

if [ "$MODE" = "--global" ]; then
    INSTRUCTIONS_FILE="$SCRIPT_DIR/../_shared/sage-instructions.md"
    TARGET="$HOME/.gemini/GEMINI.md"
    WIKI_PATH="$HOME/sage/wiki"
elif [ "$MODE" = "--project" ]; then
    INSTRUCTIONS_FILE=$(mktemp) && sage_project_instructions "$SCRIPT_DIR/../_shared/sage-instructions.md" > "$INSTRUCTIONS_FILE"
    TARGET="GEMINI.md"
    WIKI_PATH="$(pwd)/wiki"
else
    echo "Usage: bash install.sh [--project]"
    exit 1
fi

sage_upsert_instructions "$TARGET" "$INSTRUCTIONS_FILE" "sage instructions"

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
echo "  MCP: add to ~/.gemini/settings.json:"
echo "  { \"mcpServers\": { \"sage\": { \"command\": \"python3\", \"args\": [\"-m\", \"sage_mcp\", \"--wiki\", \"$WIKI_PATH\"] } } }"
