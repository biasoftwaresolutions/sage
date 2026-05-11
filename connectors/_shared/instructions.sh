#!/bin/bash
# Helpers for safely installing sage instruction blocks into existing files.

# Generate project-mode instructions from sage-instructions.md on the fly.
# Strips ~/sage/ prefix from all paths — no separate project file needed.
sage_project_instructions() {
    local source_file="$1"
    sed \
        -e 's|Wiki at `~/sage/`\. Sources in `~/sage/sources/`, compiled wiki in `~/sage/wiki/`\.|This project has a sage wiki. Sources in `sources/`, compiled wiki in `wiki/`.|' \
        -e 's|`python3 ~/sage/scripts/sage-operations\.py`|`python3 scripts/sage-operations.py`|' \
        -e 's|`~/sage/wiki/sage-memory/|`wiki/sage-memory/|g' \
        -e 's|`~/sage/skills/|`skills/|g' \
        -e 's|`~/sage/wiki/index\.md`|`wiki/index.md`|g' \
        "$source_file"
}

sage_upsert_instructions() {
    local target="$1"
    local source_file="$2"
    local label="$3"

    mkdir -p "$(dirname "$target")"
    LINK_TARGET="$target" LINK_SOURCE="$source_file" python3 - <<'PYEOF'
import os
import re
from pathlib import Path

target = Path(os.environ["LINK_TARGET"]).expanduser()
source = Path(os.environ["LINK_SOURCE"]).read_text(encoding="utf-8").rstrip()
header = "## sage — Personal Knowledge Wiki"

existing = ""
if target.exists():
    existing = target.read_text(encoding="utf-8", errors="replace")

pattern = re.compile(rf"(^|\n){re.escape(header)}\n.*?(?=\n## |\Z)", re.DOTALL)
match = pattern.search(existing)
if match:
    prefix = "\n" if match.group(1) else ""
    updated = pattern.sub(prefix + source, existing).rstrip() + "\n"
else:
    separator = "\n\n" if existing.strip() else ""
    updated = existing.rstrip() + separator + source + "\n"

target.write_text(updated, encoding="utf-8")
PYEOF
    echo "$label → $target"
}
