#!/bin/bash
# Scaffold or update the Sage wiki structure.
#
# Fresh install: creates everything from scratch.
# Update (wiki already exists): updates code/config files only, never touches wiki data.
#
# Usage:
#   bash scaffold.sh              → ~/sage/ (central wiki)
#   bash scaffold.sh --project    → current directory

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODE="${1:---global}"

if [ "$MODE" = "--project" ]; then
    TARGET_DIR="."
else
    TARGET_DIR="$HOME/sage"
    mkdir -p "$TARGET_DIR"
fi

# ── Detect: fresh install or update? ─────────────────────────────────
# A wiki exists if wiki/index.md is present (created on first ingest or scaffold)
IS_UPDATE=false
if [ -f "$TARGET_DIR/wiki/index.md" ] || [ -f "$TARGET_DIR/wiki/log.md" ]; then
    IS_UPDATE=true
fi

if [ "$IS_UPDATE" = true ]; then
    echo "  Existing wiki detected at $TARGET_DIR — updating code only, wiki data untouched."
else
    echo "  Fresh install at $TARGET_DIR."
fi

# ── Code files: always update ─────────────────────────────────────────
# These are developer-maintained and should always reflect the latest version.
cp "$SCRIPT_DIR/sage.md" "$TARGET_DIR/sage.md"
echo "  Updated sage.md"

mkdir -p "$TARGET_DIR/scripts"
cp "$REPO_ROOT/scripts/sage-operations.py" "$TARGET_DIR/scripts/sage-operations.py"
cp "$REPO_ROOT/scripts/daily-maintenance.sh" "$TARGET_DIR/scripts/daily-maintenance.sh"
cp "$REPO_ROOT/scripts/install-launchagent.sh" "$TARGET_DIR/scripts/install-launchagent.sh"
cp "$REPO_ROOT/scripts/install-skills.sh" "$TARGET_DIR/scripts/install-skills.sh"
chmod +x "$TARGET_DIR/scripts/daily-maintenance.sh" "$TARGET_DIR/scripts/install-launchagent.sh" "$TARGET_DIR/scripts/install-skills.sh"
echo "  Updated scripts/"

mkdir -p "$TARGET_DIR/skills"
for skill_file in "$REPO_ROOT/skills/"*.md; do
    cp "$skill_file" "$TARGET_DIR/skills/$(basename "$skill_file")"
done
echo "  Updated skills/"

if [ -f "$REPO_ROOT/logo.png" ]; then
    cp "$REPO_ROOT/logo.png" "$TARGET_DIR/logo.png"
fi


# ── Wiki structure: only on fresh install ────────────────────────────
# Never overwrite wiki data (index.md, log.md, _knowledge-graph.json, page files).
if [ "$IS_UPDATE" = false ]; then
    for dir in sources wiki/sources wiki/concepts wiki/entities wiki/comparisons wiki/explorations; do
        mkdir -p "$TARGET_DIR/$dir"
        touch "$TARGET_DIR/$dir/.gitkeep"
    done

    if [ ! -f "$TARGET_DIR/wiki/_knowledge-graph.json" ]; then
        echo '{}' > "$TARGET_DIR/wiki/_knowledge-graph.json"
        echo "  Created wiki/_knowledge-graph.json"
    fi

    if [ ! -f "$TARGET_DIR/wiki/index.md" ]; then
        if [ -f "$REPO_ROOT/wiki/index.md" ]; then
            cp "$REPO_ROOT/wiki/index.md" "$TARGET_DIR/wiki/index.md"
        else
            printf "# Sage Wiki\n\nWiki index. Run \`sage ingest\` to populate.\n" > "$TARGET_DIR/wiki/index.md"
        fi
        echo "  Created wiki/index.md"
    fi

    if [ ! -f "$TARGET_DIR/wiki/log.md" ]; then
        if [ -f "$REPO_ROOT/wiki/log.md" ]; then
            cp "$REPO_ROOT/wiki/log.md" "$TARGET_DIR/wiki/log.md"
        else
            printf "# Sage Ingest Log\n\n" > "$TARGET_DIR/wiki/log.md"
        fi
        echo "  Created wiki/log.md"
    fi

    echo "  Wiki structure created at $TARGET_DIR"
else
    # On update: ensure directory structure exists (in case new dirs were added)
    for dir in sources wiki/sources wiki/concepts wiki/entities wiki/comparisons wiki/explorations; do
        mkdir -p "$TARGET_DIR/$dir"
    done
fi

echo "  Wiki ready at $TARGET_DIR"

# ── MCP server: install sage-mcp package ─────────────────────────────
echo ""
echo "  Setting up MCP server..."

if [ -d "$REPO_ROOT/mcp_package" ]; then
    echo "  Installing/upgrading sage-mcp from local checkout..."
    pip3 install --upgrade "$REPO_ROOT/mcp_package" --break-system-packages -q 2>/dev/null \
        || pip3 install --upgrade "$REPO_ROOT/mcp_package" -q 2>/dev/null \
        || true
else
    echo "  Installing/upgrading sage-mcp from PyPI..."
    pip3 install --upgrade sage-mcp --break-system-packages -q 2>/dev/null \
        || pip3 install --upgrade sage-mcp -q 2>/dev/null \
        || true
fi

# Verify installation
if python3 -c "import sage_mcp" 2>/dev/null; then
    echo "  ✓ sage-mcp installed"
    echo ""
    echo "  Add to your MCP client config:"
    echo '  {'
    echo '    "mcpServers": {'
    echo '      "sage": {'
    echo '        "command": "python3",'
    echo "        \"args\": [\"-m\", \"sage_mcp\", \"--wiki\", \"$TARGET_DIR/wiki\"]"
    echo '      }'
    echo '    }'
    echo '  }'
else
    echo "  · Could not install sage-mcp. Install manually: pip install sage-mcp"
fi
