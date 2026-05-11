# sage meeting — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `sage meeting` command that captures meeting notes, creates `wiki/meetings/` pages, extracts action items into `wiki/action-items/open.md`, and manages their lifecycle (auto-close, purge, explicit close).

**Architecture:** New skill file drives all logic (no code changes needed for the core flow). ops.py gets one new lint check (`action_item_orphan`) for health monitoring. Install scripts and instruction files wire the command into all integrations.

**Tech Stack:** Python (ops.py for lint check), Markdown skill files (sage convention), bash (install-skills.sh)

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `skills/sage-meeting.md` | Full meeting command skill (capture, close, list) |
| Create | `tests/test_meeting_lint.py` | TDD tests for action_item_orphan lint check |
| Modify | `scripts/ops.py` | Add `_check_action_item_orphans()` + wire into `cmd_lint` |
| Modify | `scripts/install-skills.sh` | Register sage-meeting in both skill loops |
| Modify | `integrations/_shared/sage-instructions.md` | Add `sage meeting` trigger row |
| Modify | `integrations/_shared/sage-instructions-project.md` | Add `sage meeting` trigger row |
| Modify | `~/.claude/CLAUDE.md` | Add `sage meeting` to global trigger table |
| Modify | `README.md` | Document new command in Commands table and slash commands line |

---

## Task 1: TDD — action_item_orphan lint check

**Files:**
- Create: `tests/test_meeting_lint.py`
- Modify: `scripts/ops.py` (after tests pass)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_meeting_lint.py`:

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))


def _setup_wiki(tmp: Path):
    wiki = tmp / "wiki"
    (wiki / "action-items").mkdir(parents=True)
    (wiki / "meetings").mkdir(parents=True)
    return wiki


def test_action_item_orphan_detected(monkeypatch, tmp_path):
    import ops
    wiki = _setup_wiki(tmp_path)
    # open.md references a meeting page that doesn't exist
    (wiki / "action-items" / "open.md").write_text(
        "# Open Action Items\n\n"
        "## 2026-05-03 — [Product Sync](../meetings/2026-05-03-product-sync.md)\n"
        "- [ ] Ship widget | owner: Alice\n"
    )
    monkeypatch.setattr(ops, "WIKI_DIR", wiki)
    issues = ops._check_action_item_orphans()
    assert len(issues) == 1
    assert issues[0]["type"] == "action_item_orphan"
    assert issues[0]["slug"] == "2026-05-03-product-sync"


def test_action_item_orphan_not_reported_when_meeting_exists(monkeypatch, tmp_path):
    import ops
    wiki = _setup_wiki(tmp_path)
    # meeting page exists
    (wiki / "meetings" / "2026-05-03-product-sync.md").write_text(
        "---\ntype: meeting\ntitle: Product Sync\n---\n# Product Sync\n"
    )
    (wiki / "action-items" / "open.md").write_text(
        "# Open Action Items\n\n"
        "## 2026-05-03 — [Product Sync](../meetings/2026-05-03-product-sync.md)\n"
        "- [ ] Ship widget | owner: Alice\n"
    )
    monkeypatch.setattr(ops, "WIKI_DIR", wiki)
    issues = ops._check_action_item_orphans()
    assert issues == []


def test_action_item_orphan_scans_closed_too(monkeypatch, tmp_path):
    import ops
    wiki = _setup_wiki(tmp_path)
    # closed.md references a missing meeting
    (wiki / "action-items" / "open.md").write_text("# Open Action Items\n")
    (wiki / "action-items" / "closed.md").write_text(
        "# Closed Action Items\n\n"
        "## 2026-04-01 — [Old Meeting](../meetings/2026-04-01-old-meeting.md)\n"
        "- [x] Done thing | closed: 2026-04-01\n"
    )
    monkeypatch.setattr(ops, "WIKI_DIR", wiki)
    issues = ops._check_action_item_orphans()
    assert len(issues) == 1
    assert issues[0]["slug"] == "2026-04-01-old-meeting"


def test_action_item_orphan_no_action_items_dir(monkeypatch, tmp_path):
    import ops
    wiki = tmp_path / "wiki"
    wiki.mkdir()
    monkeypatch.setattr(ops, "WIKI_DIR", wiki)
    issues = ops._check_action_item_orphans()
    assert issues == []
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/dlabhesh/Documents/GitHub/sage
python -m pytest tests/test_meeting_lint.py -v
```

Expected: `AttributeError: module 'ops' has no attribute '_check_action_item_orphans'`

- [ ] **Step 3: Implement `_check_action_item_orphans` in ops.py**

Add this function after the `_get_wikilinks` function (around line 111 in ops.py):

```python
def _check_action_item_orphans() -> list[dict]:
    """Report meeting headers in action-items/ that point to missing wiki/meetings/ pages."""
    ai_dir = WIKI_DIR / "action-items"
    if not ai_dir.exists():
        return []
    meetings_dir = WIKI_DIR / "meetings"
    header_re = re.compile(r"^## \d{4}-\d{2}-\d{2} — \[.+?\]\(\.\./meetings/(.+?)\.md\)")
    issues: list[dict] = []
    for fname in ("open.md", "closed.md"):
        fpath = ai_dir / fname
        if not fpath.exists():
            continue
        for line in fpath.read_text(encoding="utf-8").splitlines():
            m = header_re.match(line)
            if m:
                slug = m.group(1)
                if not (meetings_dir / f"{slug}.md").exists():
                    issues.append({
                        "type": "action_item_orphan",
                        "file": fname,
                        "slug": slug,
                    })
    return issues
```

- [ ] **Step 4: Wire into `cmd_lint`**

In `cmd_lint`, after the existing `type_tags` duplicate_candidate loop (around line 392), add:

```python
    # action item orphans
    issues += _check_action_item_orphans()
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /Users/dlabhesh/Documents/GitHub/sage
python -m pytest tests/test_meeting_lint.py -v
```

Expected: 4 tests PASSED

- [ ] **Step 6: Run full test suite to catch regressions**

```bash
cd /Users/dlabhesh/Documents/GitHub/sage
python -m pytest -v
```

Expected: all tests PASSED

- [ ] **Step 7: Commit**

```bash
git add tests/test_meeting_lint.py scripts/ops.py
git commit -m "feat: add action_item_orphan lint check to ops.py"
```

---

## Task 2: Create `skills/sage-meeting.md`

**Files:**
- Create: `skills/sage-meeting.md`

- [ ] **Step 1: Create the skill file**

Create `skills/sage-meeting.md` with this exact content:

````markdown
---
name: sage-meeting
description: Capture meeting notes into sage wiki with action item extraction and lifecycle management. Triggers on "sage meeting", "/sage-meeting".
---

## Memory context

If `~/sage/wiki/sage-memory/` exists, read before running:
- `SOUL.md` — domain focus: filter what decisions are worth capturing
- `USER.md` — background: calibrate how much to expand sparse notes

---

# sage meeting

Capture meeting notes, extract decisions and action items, manage their lifecycle.

## Commands

| Command | Action |
|---------|--------|
| `sage meeting` | Capture new meeting notes |
| `sage meeting close <description>` | Explicitly close an open action item |
| `sage meeting list` | Print open action items to terminal |

---

## `sage meeting` — Capture Flow

### Step 1 — Collect meeting info

If the user has already pasted notes or a transcript, infer:
- Title (from subject/topic in the notes)
- Date (look for date mention; default: today YYYY-MM-DD)
- Attendees (names mentioned; if unclear, ask once)
- Meeting type: standup | planning | 1on1 | review | other

If no notes have been provided yet, ask:
> "Paste your meeting notes or transcript when ready. (Or tell me the title/attendees first.)"

### Step 2 — Extract structure

From the notes, identify:

**Summary** — 2-3 sentences, what was discussed and decided.

**Key Decisions** — explicit decisions made (not topics discussed). One bullet per decision.

**Action Items** — concrete tasks assigned or committed to. Format each as:
```
- [ ] <action> | owner: <name> | due: <YYYY-MM-DD>
```
Owner and due are optional if not mentioned. Extract only items with a clear owner or commitment — skip vague intentions.

**Auto-closure candidates** — scan for past-tense completions:
- Trigger phrases: "shipped", "finished", "completed", "done with", "closed", "resolved", "merged", "deployed", "released", "we did", "already", "is done"
- List these separately — used in Step 6.

Show the user a preview of: Summary, Key Decisions (N), Action Items (N), Auto-closure candidates (N).
Wait for confirmation before writing any files.

### Step 3 — Save raw archive

Path: `~/sage/raw/meetings/YYYY-MM-DD-<slug>.md`

Slug = meeting title lowercased, spaces→hyphens, 3-5 words max.
Create `~/sage/raw/meetings/` if it doesn't exist.

```markdown
---
title: "<Meeting Title>"
source_type: meeting
date: YYYY-MM-DD
attendees: [name, name]
meeting_type: standup | planning | 1on1 | review | other
tags: []
---

<raw notes or transcript — verbatim from user, unmodified>
```

### Step 4 — Save wiki/meetings/ page

Path: `~/sage/wiki/meetings/YYYY-MM-DD-<slug>.md`

Create `~/sage/wiki/meetings/` if it doesn't exist.

```markdown
---
type: meeting
title: "<Meeting Title>"
date: YYYY-MM-DD
attendees: [name, name]
meeting_type: standup | planning | 1on1 | review | other
tags: []
---

# <Meeting Title>

## Summary

<2-3 sentence synthesis>

## Key Decisions

- <decision>

## Action Items

- [ ] <item> | owner: X | due: YYYY-MM-DD

## Raw Source

`raw/meetings/YYYY-MM-DD-<slug>.md`
```

### Step 5 — Update open.md

Path: `~/sage/wiki/action-items/open.md`

If the file doesn't exist, create `~/sage/wiki/action-items/` and the file:
```markdown
# Open Action Items
```

If there are extracted action items, append:
```markdown

## YYYY-MM-DD — [Meeting Title](../meetings/YYYY-MM-DD-slug.md)
- [ ] Action text | owner: X | due: YYYY-MM-DD
- [ ] Action text
```

If no action items were extracted, skip this step.

### Step 6 — Auto-closure scan

Read `~/sage/wiki/action-items/open.md`.

For each auto-closure candidate from Step 2:
- Fuzzy-match against open items: match on key nouns and verbs (not exact text). A match requires 2+ meaningful words in common.
- If matched: move the item from `open.md` to `~/sage/wiki/action-items/closed.md`
  - Change `- [ ]` → `- [x]`
  - Append `| closed: YYYY-MM-DD` (today's date)
  - In `closed.md`, place under the same meeting header (create header if needed)

If `~/sage/wiki/action-items/closed.md` doesn't exist, create it:
```markdown
# Closed Action Items
```

Report: "Auto-closed N items: [list]" (or "No auto-closures detected" if none matched).

### Step 7 — Purge closed.md

Read `~/sage/wiki/action-items/closed.md`.

Remove any item line where `closed: YYYY-MM-DD` is more than 7 days before today.
After removing items, if a meeting section header (`## ...`) has no item lines beneath it, remove that header too.

Rewrite the file with remaining content.

Report: "Purged N items older than 7 days." (or "Nothing to purge.")

### Step 8 — Update wiki/index.md

Open `~/sage/wiki/index.md`. Find the `## Meetings` section; create it if absent (add before `## Uncategorized` or at end of file).

Add entry:
```
- [[YYYY-MM-DD-slug]] — <title> · <N> decisions · <N> action items
```

Update the header line: `Last updated: YYYY-MM-DD | <N> pages | <N> sources`

### Step 9 — Append to wiki/log.md

```
## [<ISO timestamp>] meeting | "<title>"

- Raw: raw/meetings/YYYY-MM-DD-slug.md
- Wiki: wiki/meetings/YYYY-MM-DD-slug.md
- Action items added: N
- Auto-closed: N
- Purged: N

---
```

### Step 10 — Report to user

```
Meeting captured: "<title>"

  Wiki:          wiki/meetings/YYYY-MM-DD-slug.md
  Action items:  N added
  Auto-closed:   N
  Purged:        N (older than 7 days)
```

---

## `sage meeting close <description>`

1. Read `~/sage/wiki/action-items/open.md`
2. Fuzzy-match `<description>` against open items (2+ meaningful words in common)
3. Show matched item(s):
   > Found: `- [ ] Ship widget | owner: Alice`
   > Close this? (y/n)
4. On confirmation: move item to `closed.md` under original meeting header, change `- [ ]` → `- [x]`, append `| closed: YYYY-MM-DD`
5. Report: `Closed: "<item text>"`

If no match found: `No open items matched "<description>". Run "sage meeting list" to see all open items.`

---

## `sage meeting list`

Print the full contents of `~/sage/wiki/action-items/open.md`.

If the file doesn't exist: `No open action items.`
````

- [ ] **Step 2: Verify the file was created**

```bash
head -5 /Users/dlabhesh/Documents/GitHub/sage/skills/sage-meeting.md
```

Expected: frontmatter with `name: sage-meeting`

- [ ] **Step 3: Commit**

```bash
git add skills/sage-meeting.md
git commit -m "feat: add sage-meeting skill"
```

---

## Task 3: Wire up integrations

**Files:**
- Modify: `scripts/install-skills.sh`
- Modify: `integrations/_shared/sage-instructions.md`
- Modify: `integrations/_shared/sage-instructions-project.md`
- Modify: `~/.claude/CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: Update `install-skills.sh` — uninstall loop**

In `scripts/install-skills.sh`, find this line (line 42):
```bash
    for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate; do
```

Change to:
```bash
    for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate sage-meeting; do
```

- [ ] **Step 2: Update `install-skills.sh` — install skills loop**

Find this line (line 65):
```bash
for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate; do
```

Change to:
```bash
for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate sage-meeting; do
```

- [ ] **Step 3: Update `install-skills.sh` — install slash commands loop**

Find this line (line 72):
```bash
for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate; do
```

Change to:
```bash
for skill in sage-init sage-ingest sage-lint sage-research sage-capture sage-relocate sage-meeting; do
```

- [ ] **Step 4: Update `install-skills.sh` — echo line**

Find:
```bash
echo "  Commands: /sage-init  /sage-ingest  /sage-lint  /sage-research  /sage-capture  /sage-relocate"
```

Change to:
```bash
echo "  Commands: /sage-init  /sage-ingest  /sage-lint  /sage-research  /sage-capture  /sage-relocate  /sage-meeting"
```

- [ ] **Step 5: Update `integrations/_shared/sage-instructions.md`**

Add one row to the table, after the `sage relocate` row:

```markdown
| **sage meeting** | Read `~/sage/skills/sage-meeting.md` then follow it exactly |
```

The full table should end with:
```markdown
| **sage remember `<thing>`** | Append entry to `~/sage/wiki/sage-memory/MEMORY.md` immediately, no confirmation needed |
| **sage relocate `<path>`** | Read `~/sage/skills/sage-relocate.md` then follow it exactly |
| **sage meeting** | Read `~/sage/skills/sage-meeting.md` then follow it exactly |
```

- [ ] **Step 6: Update `integrations/_shared/sage-instructions-project.md`**

Same change — add row after `sage relocate`:

```markdown
| **sage meeting** | Read `skills/sage-meeting.md` then follow it exactly |
```

- [ ] **Step 7: Update `~/.claude/CLAUDE.md` global table**

Find the table in `~/.claude/CLAUDE.md`. Add row after the `sage relocate` row:

```markdown
| **sage meeting** | Read `~/sage/skills/sage-meeting.md` then follow it exactly |
```

- [ ] **Step 8: Update `README.md` — Commands table**

In the Commands table, add after the `sage relocate` row:

```markdown
| `sage meeting` | Capture meeting notes, extract action items, manage lifecycle |
```

- [ ] **Step 9: Update `README.md` — slash commands line**

Find:
```
> **Claude Code slash commands:** `/sage-init`, `/sage-ingest`, `/sage-lint`, `/sage-research`, `/sage-capture` — same behavior, shorter to type.
```

Change to:
```
> **Claude Code slash commands:** `/sage-init`, `/sage-ingest`, `/sage-lint`, `/sage-research`, `/sage-capture`, `/sage-meeting` — same behavior, shorter to type.
```

- [ ] **Step 10: Update `.sageignore` to exclude raw/meetings/ from sage ingest**

`sage ingest` runs `ops.py discover` which picks up all raw files. Meeting raw files already have a wiki page created by `sage meeting` — ingest would create a redundant `wiki/sources/` page for the same content. Excluding the folder prevents this without changing the ingest skill.

Add one line to `.sageignore`:
```
raw/meetings/
```

- [ ] **Step 12: Verify install-skills.sh is syntactically valid**

```bash
bash -n /Users/dlabhesh/Documents/GitHub/sage/scripts/install-skills.sh
```

Expected: no output (no syntax errors)

- [ ] **Step 13: Commit all integration changes**

```bash
git add scripts/install-skills.sh \
        integrations/_shared/sage-instructions.md \
        integrations/_shared/sage-instructions-project.md \
        .sageignore \
        README.md
git commit -m "feat: wire sage-meeting into install scripts and integration instructions"
```

Note: `~/.claude/CLAUDE.md` is outside the repo — not committed to git.

---

## Task 4: Install and smoke test

- [ ] **Step 1: Run install script**

```bash
bash /Users/dlabhesh/Documents/GitHub/sage/scripts/install-skills.sh
```

Expected output includes:
```
✓ Skills installed → ~/sage/skills/
✓ Slash commands installed → ~/.claude/commands/
Commands: /sage-init  /sage-ingest  /sage-lint  /sage-research  /sage-capture  /sage-relocate  /sage-meeting
```

- [ ] **Step 2: Verify skill was installed**

```bash
head -3 ~/sage/skills/sage-meeting.md
```

Expected:
```
---
name: sage-meeting
```

- [ ] **Step 3: Verify slash command was installed**

```bash
ls ~/.claude/commands/ | grep sage-meeting
```

Expected: `sage-meeting.md`

- [ ] **Step 4: Run full test suite one final time**

```bash
cd /Users/dlabhesh/Documents/GitHub/sage
python -m pytest -v
```

Expected: all tests PASSED

- [ ] **Step 5: Final commit (if any loose changes)**

```bash
git status
```

If clean: nothing to do. If any tracked files changed unexpectedly, investigate before committing.
