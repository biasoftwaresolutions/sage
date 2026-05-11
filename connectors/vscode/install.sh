#!/bin/bash
# sage integration for VS Code (Copilot Chat)
# One command: settings.json + wiki scaffold + sage-mcp install
#
# Usage:
#   bash install.sh             → .vscode/settings.json + central wiki at ~/sage/
#   bash install.sh --project   → .vscode/settings.json + wiki in current dir
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../_shared/instructions.sh"
MODE="${1:---global}"
TARGET=".vscode/settings.json"
mkdir -p .vscode

if [ "$MODE" = "--project" ]; then
    INSTRUCTIONS_FILE=$(mktemp) && sage_project_instructions "$SCRIPT_DIR/../_shared/sage-instructions.md" > "$INSTRUCTIONS_FILE"
    WIKI_PATH="$(pwd)/wiki"
else
    INSTRUCTIONS_FILE="$SCRIPT_DIR/../_shared/sage-instructions.md"
    WIKI_PATH="$HOME/sage/wiki"
fi

# Write to .vscode/settings.json
SAGE_INSTRUCTIONS_FILE="$INSTRUCTIONS_FILE" python3 - << 'PYEOF'
import json, os
target = ".vscode/settings.json"
instructions_text = open(os.environ["SAGE_INSTRUCTIONS_FILE"], encoding="utf-8").read()
settings = {}
if os.path.exists(target):
    try:
        with open(target) as f:
            settings = json.load(f)
    except Exception:
        pass
key = 'github.copilot.chat.codeGeneration.instructions'
instructions = settings.get(key, [])
if not isinstance(instructions, list):
    instructions = []
instructions = [
    i for i in instructions
    if '## sage — Personal Knowledge Wiki' not in i.get('text', '')
    and 'sage, an LLM-maintained knowledge wiki' not in i.get('text', '')
]
instructions.append({'text': instructions_text})
settings[key] = instructions
with open(target, 'w') as f:
    json.dump(settings, f, indent=2)
print(f"sage instructions → {target}")
PYEOF

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
echo "  MCP: add to .vscode/mcp.json:"
echo "  { \"servers\": { \"sage\": { \"type\": \"stdio\", \"command\": \"python3\", \"args\": [\"-m\", \"sage_mcp\", \"--wiki\", \"$WIKI_PATH\"] } } }"
