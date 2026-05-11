#!/bin/bash
# Remove sage from Kiro
#
# Usage:
#   bash uninstall.sh             → removes global ~/.kiro/steering/sage.md
#   bash uninstall.sh --project   → removes project .kiro/steering/sage.md
set -e

MODE="${1:---global}"

if [ "$MODE" = "--global" ]; then
    TARGET="$HOME/.kiro/steering/sage.md"
else
    TARGET=".kiro/steering/sage.md"
fi

if [ -f "$TARGET" ]; then
    rm "$TARGET"
    echo "Removed $TARGET"
else
    echo "No sage steering found at $TARGET"
fi
