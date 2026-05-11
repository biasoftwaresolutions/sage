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

### Step 2b — Memory extraction

Before writing any files, scan the notes for personal context signals. If `wiki/sage-memory/` doesn't exist, skip this step.

**Bar: high.** Default is to skip. Only update when signal is unambiguous, durable, and not already captured.

**USER.md** — update only if notes clearly reveal:
- A project the user owns or leads (durable, not a one-off task from this meeting)
- A key person by stable relationship (manager, co-founder, long-term client) — not just "someone who attended"
- User's own role or responsibility, explicitly stated — never infer or store their name

Skip casual mentions, one-time attendees, tasks that are already done.

**SOUL.md** — update only if notes reveal an explicit, durable priority or goal — not a meeting agenda item. High bar: something that reframes what future advice should emphasize.

**Merge, don't append.** Rewrite existing lines if info updates them. Keep files short.

For USER.md and SOUL.md: update silently if bar is cleared. Report briefly at end: "Memory updated: USER.md (project X)". If nothing clears the bar, say nothing.

**MEMORY.md** — pitch only if a concrete decision was made that settles a recurring question, or a specific lesson emerged that would change future behavior. Ask before writing: "Found something worth remembering: [X]. Add to MEMORY.md? (y/n)"

### Step 3 — Save raw archive

Path: `~/sage/sources/meetings/YYYY-MM-DD-<slug>.md`

Slug = meeting title lowercased, spaces→hyphens, 3-5 words max.
Create `~/sage/sources/meetings/` if it doesn't exist.

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

`sources/meetings/YYYY-MM-DD-<slug>.md`
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
- If matched:
  - Write to `closed.md` FIRST (change `- [ ]` → `- [x]`, append `| closed: YYYY-MM-DD | source: <meeting-slug>` (today's date; slug is the originating meeting's slug from `open.md` section header)), then remove from `open.md`. This order ensures a failure leaves the item in `open.md` rather than nowhere.
  - In `closed.md`, find an existing header matching `## YYYY-MM-DD — [Meeting Title]` and append items under it. If no matching header exists, create one.

If `~/sage/wiki/action-items/closed.md` doesn't exist, create it:
```markdown
# Closed Action Items
```

Report: "Auto-closed N items: [list]" (or "No auto-closures detected" if none matched).

### Step 7 — Purge closed.md

Read `~/sage/wiki/action-items/closed.md`.

Remove any item line where `closed: YYYY-MM-DD` is more than 7 days before today.
If an item line does not contain a parseable `closed: YYYY-MM-DD` pattern, skip it (do not remove).
After removing items, if a meeting section header (`## ...`) has no item lines beneath it, remove that header too.

Rewrite the file with remaining content.

Report: "Purged N items older than 7 days." (or "Nothing to purge.")

### Step 8 — Update wiki/index.md

Open `~/sage/wiki/index.md`. Find the `## Meetings` section; create it if absent (add before `## Uncategorized` or at end of file).

Add entry:
```
- [[YYYY-MM-DD-slug]] — <title> · <N> decisions · <N> action items
```

Update the header line's `Last updated:` date to today.

### Step 9 — Append to wiki/log.md

Create `~/sage/wiki/log.md` with header `# sage Wiki Log\n\n*Append-only record of all wiki operations.*\n\n---\n\n` if it doesn't exist.

```
## [<ISO timestamp>] meeting | "<title>"

- Raw: sources/meetings/YYYY-MM-DD-slug.md
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
2. Fuzzy-match `<description>` against open items: strip stop words (a, an, the, to, for, in, on, of, with), then check for 2+ meaningful words in common. Case-insensitive.
3. Show matched item(s):
   > Found: `- [ ] Ship widget | owner: Alice`
   > Close this? (y/n)
4. On confirmation: move item to `closed.md` under original meeting header, change `- [ ]` → `- [x]`, append `| closed: YYYY-MM-DD | source: <meeting-slug>` (slug extracted from the `open.md` section header the item lives under)
5. Report: `Closed: "<item text>"`
6. Run the Step 7 purge on `closed.md` to remove items older than 7 days.

If no match found: `No open items matched "<description>". Run "sage meeting list" to see all open items.`

---

## `sage meeting list`

Print the full contents of `~/sage/wiki/action-items/open.md`.

If the file doesn't exist: `No open action items.`
