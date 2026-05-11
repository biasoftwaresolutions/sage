#!/bin/bash
# Remove sage from Cursor
set -e

MODE="${1:---global}"

if [ "$MODE" = "--global" ]; then
    TARGET="$HOME/.cursor/rules/sage.mdc"
else
    TARGET=".cursor/rules/sage.mdc"
fi

if [ -f "$TARGET" ]; then
    rm "$TARGET"
    echo "Removed $TARGET"
else
    echo "No sage Cursor rule found at $TARGET"
fi
