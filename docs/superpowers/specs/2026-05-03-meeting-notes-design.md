# sage meeting — Design Spec

**Date:** 2026-05-03  
**Status:** Approved  
**Command:** `sage meeting` / `/sage-meeting`

---

## Overview

New first-class command that captures meeting notes (pasted or dictated), creates structured wiki pages, extracts action items, and manages their lifecycle — all in one shot.

Meetings become searchable, cross-referenceable nodes in sage, not raw dumps.

---

## Architecture & Data Flow

```
User pastes notes/transcript
        ↓
Claude extracts structured data
        ↓
raw/meetings/YYYY-MM-DD-<slug>.md   ← raw archive
        ↓
wiki/meetings/YYYY-MM-DD-<slug>.md  ← new "meeting" page type
        ↓
wiki/action-items/open.md           ← new items appended
        ↓
auto-closure scan                   ← notes mention anything done? move to closed.md
        ↓
purge closed.md                     ← items > 7 days old deleted
        ↓
wiki/index.md updated
```

Input sources: Zoom/Teams transcript dumps, in-person notes, voice dictation, pre-formatted bullets — all accepted. Claude structures them uniformly.

---

## Data Structures

### `raw/meetings/YYYY-MM-DD-<slug>.md`

Raw archive. Never edited after creation.

```markdown
---
title: "<Meeting Title>"
source_type: meeting
date: YYYY-MM-DD
attendees: [name, name]
meeting_type: standup | planning | 1on1 | review | other
tags: []
---
<raw notes or transcript — verbatim from user>
```

### `wiki/meetings/YYYY-MM-DD-<slug>.md`

New `meeting` page type. Lives in `wiki/meetings/`.

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
- [ ] <item> — owner: X | due: YYYY-MM-DD → [[open]]

## Raw Source
raw/meetings/YYYY-MM-DD-<slug>.md
```

### `wiki/action-items/open.md`

All open items, grouped by source meeting.

```markdown
# Open Action Items

## YYYY-MM-DD — [Meeting Name](../meetings/slug.md)
- [ ] Action text | owner: X | due: YYYY-MM-DD
- [ ] Action text | owner: X
```

### `wiki/action-items/closed.md`

Closed items. Items older than 7 days are purged on every `sage meeting` run.

```markdown
# Closed Action Items

## YYYY-MM-DD — [Meeting Name](../meetings/slug.md)
- [x] Action text | closed: YYYY-MM-DD | source: meeting-slug
```

---

## Action Item Lifecycle

**New** — extracted from meeting notes, appended to `open.md` under a meeting header.

**Explicit closure** — `sage meeting close <description>`:
- Claude fuzzy-matches description against `open.md`
- Moves matched item(s) to `closed.md` with `closed: YYYY-MM-DD`

**Auto-closure** — on every `sage meeting` run:
- Claude scans new notes for past-tense completions ("shipped X", "finished Y", "done with Z")
- Fuzzy-matches against `open.md`
- Auto-moves matches to `closed.md`, reports: "auto-closed N items"

**Purge** — on every `sage meeting` run:
- Reads `closed.md`, removes items where `closed:` date > 7 days ago
- Reports: "purged N items older than 7 days"

---

## Command Interface

| Command | Action |
|---------|--------|
| `sage meeting` | Start new meeting note — Claude collects title/attendees then waits for notes |
| `sage meeting close <description>` | Explicit closure — fuzzy-match open items, move to closed |
| `sage meeting list` | Print `open.md` to terminal |
| `/sage-meeting` | Claude Code slash equivalent |

**Run flow for `sage meeting`:**
1. Claude asks for meeting title + attendees (or infers from pasted notes)
2. User pastes notes or dictates
3. Claude shows preview: summary + decisions + extracted action items
4. User confirms → files written
5. Auto-closure scan runs
6. Purge runs
7. `wiki/index.md` updated
8. Report: pages created, items added, items auto-closed, items purged

---

## Integration with Existing Sage

**`sage ingest`** — meeting raw files are discovered like any other raw source. If `wiki/meetings/<slug>.md` already exists (created by `sage meeting`), ingest skips re-creating it.

**`sage lint`** — extended to check `wiki/action-items/open.md` for malformed entries and orphaned meeting links.

**`wiki/index.md`** — new `Meetings` section:
```
## Meetings
- [[2026-05-03-product-sync]] — Product sync · 2 decisions · 3 open items
```

**`_shared/sage-instructions.md`** — new trigger row:
```
sage meeting   →   sage-meeting skill
```

**Unchanged:** sage capture, sage research, sage relocate.

---

## New Files to Create

| File | Purpose |
|------|---------|
| `skills/sage-meeting.md` | New skill definition |
| `wiki/action-items/open.md` | Open action items (created on first run) |
| `wiki/action-items/closed.md` | Closed action items (created on first run) |

## Files to Update

| File | Change |
|------|--------|
| `integrations/_shared/sage-instructions.md` | Add `sage meeting` trigger row |
| `integrations/_shared/sage-instructions-project.md` | Add `sage meeting` trigger row |
| `scripts/install-skills.sh` | Register `sage-meeting` skill |
| `~/.claude/CLAUDE.md` | Add `sage meeting` to global table |
| `README.md` | Document new command |

---

## Out of Scope

- External task tool sync (Todoist, Linear, Notion) — future
- Auto-joining calls or bot transcription — manual paste only
- Action item assignment notifications — future
