#!/bin/bash
# sage integration for GitHub Copilot
# One command: instructions + wiki scaffold + sage-mcp install
#
# Usage:
#   bash install.sh             → .github/copilot-instructions.md + central wiki at ~/sage/
#   bash install.sh --project   → .github/copilot-instructions.md + wiki in current dir
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:---global}"
. "$SCRIPT_DIR/../_shared/instructions.sh"

if [ "$MODE" = "--project" ]; then
    INSTRUCTIONS_FILE=$(mktemp) && sage_project_instructions "$SCRIPT_DIR/../_shared/sage-instructions.md" > "$INSTRUCTIONS_FILE"
    WIKI_PATH="$(pwd)/wiki"
else
    INSTRUCTIONS_FILE="$SCRIPT_DIR/../_shared/sage-instructions.md"
    WIKI_PATH="$HOME/sage/wiki"
fi

TARGET=".github/copilot-instructions.md"

sage_upsert_instructions "$TARGET" "$INSTRUCTIONS_FILE" "sage instructions"

if [ "$MODE" = "--project" ]; then
    bash "$SCRIPT_DIR/../_shared/scaffold.sh" --project
else
    bash "$SCRIPT_DIR/../_shared/scaffold.sh"
fi

if [ "$(uname)" = "Darwin" ] && [ "$MODE" != "--project" ]; then
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
echo "  Drop sources into sources/ and say 'sage ingest' to process them."
echo "  View wiki: python ~/sage/wiki_server.py"
echo ""
echo "  MCP: add to your Copilot MCP config:"
echo "  { \"mcpServers\": { \"sage\": { \"command\": \"python3\", \"args\": [\"-m\", \"sage_mcp\", \"--wiki\", \"$WIKI_PATH\"] } } }"
