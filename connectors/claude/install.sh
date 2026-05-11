#!/bin/bash
# sage integration for Claude (Claude Code + Claude Desktop)
#
# Detects which Claude products are installed and configures each.
# Skipped products are reported at the end.
#
# Usage:
#   bash install.sh             → global: ~/.claude/CLAUDE.md + central wiki at ~/sage/
#   bash install.sh --project   → project-local: ./CLAUDE.md + wiki in current dir

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODE="${1:---global}"
. "$SCRIPT_DIR/../_shared/instructions.sh"

if [ "$MODE" = "--global" ]; then
    WIKI_PATH="$HOME/sage/wiki"
elif [ "$MODE" = "--project" ]; then
    WIKI_PATH="$(pwd)/wiki"
else
    echo "Usage: bash install.sh [--project]"
    exit 1
fi

SKIPPED=()
CONFIGURED=()

# ── scaffold wiki + install sage-mcp ─────────────────────────────────
if [ "$MODE" = "--project" ]; then
    bash "$SCRIPT_DIR/../_shared/scaffold.sh" --project
else
    bash "$SCRIPT_DIR/../_shared/scaffold.sh"
fi

# ── helper: register sage MCP in a JSON config file ──────────────────
_register_mcp() {
    local config_path="$1"
    SAGE_WIKI_PATH="$WIKI_PATH" MCP_CONFIG_PATH="$config_path" REPO_ROOT="$REPO_ROOT" python3 - << 'PYEOF'
import json, os, sys
config_path = os.environ["MCP_CONFIG_PATH"]
wiki_path = os.environ["SAGE_WIKI_PATH"]
repo_root = os.environ["REPO_ROOT"]
mcp_pkg = os.path.join(repo_root, "mcp_package")

pip_ok = __import__("subprocess").run(
    [sys.executable, "-c", "import sage_mcp"], capture_output=True
).returncode == 0

entry = {"command": sys.executable, "args": ["-m", "sage_mcp", "--wiki", wiki_path]}
if not pip_ok and os.path.isdir(mcp_pkg):
    entry["env"] = {"PYTHONPATH": mcp_pkg}

try:
    with open(config_path) as f:
        config = json.load(f)
    config.setdefault("mcpServers", {})["sage"] = entry
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
    src = "local checkout" if "env" in entry else "installed package"
    print(f"  ✓ sage MCP registered ({src})")
except Exception as e:
    print(f"  · Could not register MCP: {e}", file=sys.stderr)
PYEOF
}

# ── Claude Code ───────────────────────────────────────────────────────
echo ""
echo "  Checking Claude Code..."

if [ -d "$HOME/.claude" ]; then
    # Steering
    if [ "$MODE" = "--global" ]; then
        sage_upsert_instructions "$HOME/.claude/CLAUDE.md" \
            "$SCRIPT_DIR/../_shared/sage-instructions.md" "sage steering"
    else
        _proj_tmp=$(mktemp) && sage_project_instructions "$SCRIPT_DIR/../_shared/sage-instructions.md" > "$_proj_tmp"
        sage_upsert_instructions "CLAUDE.md" "$_proj_tmp" "sage steering"
    fi

    # MCP
    CC_MCP="$HOME/.claude.json"
    if [ -f "$CC_MCP" ]; then
        _register_mcp "$CC_MCP"
    else
        echo "  · ~/.claude.json not found — add MCP manually if needed"
    fi

    # Skills (/sage-* slash commands)
    if bash "$REPO_ROOT/scripts/install-skills.sh" 2>/dev/null; then
        echo "  ✓ Slash commands installed — restart Claude Code to apply"
    else
        echo "  · Skills install failed (run: bash $REPO_ROOT/scripts/install-skills.sh)"
    fi

    # Daily maintenance LaunchAgent (macOS, global only)
    if [ "$(uname)" = "Darwin" ] && [ "$MODE" = "--global" ]; then
        if bash "$REPO_ROOT/scripts/install-launchagent.sh" "$HOME/sage" 2>/dev/null; then
            echo "  ✓ LaunchAgent installed — daily lint at 6:00pm"
        else
            echo "  · Skipped LaunchAgent (run: bash $REPO_ROOT/scripts/install-launchagent.sh)"
        fi
    fi

    CONFIGURED+=("Claude Code")
else
    SKIPPED+=("Claude Code (~/.claude not found — install Claude Code first)")
fi

# ── Claude Desktop ────────────────────────────────────────────────────
echo ""
echo "  Checking Claude Desktop..."

DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [ -f "$DESKTOP_CONFIG" ]; then
    _register_mcp "$DESKTOP_CONFIG"
    echo "  ✓ Restart Claude Desktop to apply"
    CONFIGURED+=("Claude Desktop")
else
    SKIPPED+=("Claude Desktop (config not found — launch Claude Desktop once, then re-run)")
fi

# ── Summary ───────────────────────────────────────────────────────────
echo ""
if [ ${#CONFIGURED[@]} -gt 0 ]; then
    echo "  Configured: ${CONFIGURED[*]}"
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo "  Skipped:"
    for item in "${SKIPPED[@]}"; do
        echo "    · $item"
    done
fi
echo ""
echo "Done."
echo "  Drop sources into ~/sage/sources/ and say 'sage ingest' to process them."
