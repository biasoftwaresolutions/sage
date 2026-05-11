#!/bin/bash
# Install sage into the user's environment.
#
# What this does:
#   1. Creates ~/sage/ directory structure (wiki/, sources/, scripts/, skills/)
#   2. Copies scripts/sage-operations.py → ~/sage/scripts/sage-operations.py  (single source of truth)
#   3. Copies skills/*.md → ~/sage/skills/*.md
#   4. Copies slash commands to ~/.claude/commands/ for Claude Code
#
# Usage:
#   bash install-skills.sh              # install / update
#   bash install-skills.sh --uninstall  # remove Claude Code commands only
#
# Re-run after pulling updates to get the latest sage-operations.py and skills.
#
# Requires Claude Code to be installed (~/.claude/ must exist).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
OPS_SRC="$REPO_ROOT/scripts/sage-operations.py"
COMMANDS_DIR="$HOME/.claude/commands"
SAGE_ROOT="${SAGE_ROOT:-$HOME/sage}"
SAGE_SCRIPTS="$SAGE_ROOT/scripts"
SAGE_SKILLS="$SAGE_ROOT/skills"

# ── check prereqs ─────────────────────────────────────────────────────
if [ ! -d "$HOME/.claude" ]; then
    echo "Error: ~/.claude not found — Claude Code must be installed first."
    exit 1
fi

if [ ! -d "$SKILLS_SRC" ]; then
    echo "Error: skills source not found at $SKILLS_SRC"
    exit 1
fi

# ── uninstall ─────────────────────────────────────────────────────────
if [ "${1:-}" = "--uninstall" ]; then
    for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate sage-meeting sage-memory; do
        rm -f "$COMMANDS_DIR/${skill}.md"
    done
    echo "  ✓ sage commands removed from Claude Code"
    echo "  Wiki data at $SAGE_ROOT was not touched."
    echo "  Restart Claude Code to apply."
    exit 0
fi

# ── scaffold sage root ────────────────────────────────────────────────
mkdir -p "$SAGE_ROOT/wiki" "$SAGE_ROOT/sources" "$SAGE_SCRIPTS" "$SAGE_SKILLS"

# Remove stale root-level ops.py if present (old layout)
if [ -f "$SAGE_ROOT/ops.py" ]; then
    rm "$SAGE_ROOT/ops.py"
    echo "  ✓ Removed stale $SAGE_ROOT/ops.py"
fi

# ── install sage-operations.py ────────────────────────────────────────
cp "$OPS_SRC" "$SAGE_SCRIPTS/sage-operations.py"
echo "  ✓ sage-operations.py installed → $SAGE_SCRIPTS/sage-operations.py"

# ── install skills ────────────────────────────────────────────────────
for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate sage-meeting sage-memory; do
    cp "$SKILLS_SRC/${skill}.md" "$SAGE_SKILLS/${skill}.md"
done
echo "  ✓ Skills installed → $SAGE_SKILLS/"

# ── install Claude Code slash commands ───────────────────────────────
mkdir -p "$COMMANDS_DIR"
for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate sage-meeting sage-memory; do
    cp "$SKILLS_SRC/${skill}.md" "$COMMANDS_DIR/${skill}.md"
done
echo "  ✓ Slash commands installed → $COMMANDS_DIR/"

echo ""
echo "  sage installed at: $SAGE_ROOT"
echo "  Commands: /sage-init  /sage-ingest  /sage-lint  /sage-research  /sage-capture  /sage-relocate  /sage-meeting  /sage-memory"
echo ""
echo "  !! Restart Claude Code now for commands to appear !!"
echo ""
echo "  To move your wiki: sage relocate ~/path/to/new-location"
echo "  Uninstall commands: bash $0 --uninstall"
