---
name: sage-memory
description: Memory lifecycle management — propose, archive, restore, forget, explain memory entries. Triggers on "sage memory", "/sage-memory".
---

# sage memory

Manage the lifecycle of entries in `wiki/sage-memory/MEMORY.md`.

## MEMORY.md structure

```markdown
---
type: memory
updated: <ISO date>
---

# Memory

> High-signal decisions and lessons...

## Active

- [<YYYY-MM-DD>] <entry text> — source: <sources/file.md>

## Archived

- [<YYYY-MM-DD>] <entry text> — archived: <YYYY-MM-DD>
```

If MEMORY.md has no `## Active` / `## Archived` sections (legacy flat format), add them before any operation: move existing bullets under `## Active`, add empty `## Archived` section at bottom.

---

## Commands

### `sage memory propose`

Scan recent sources and suggest new MEMORY.md entries.

1. Read `wiki/sage-memory/MEMORY.md` — know what's already captured
2. Read all files in `sources/` modified in the last 30 days (or all if fewer than 10 total)
3. For each file, ask: does this surface a concrete decision, hard lesson, or durable constraint that would change future behavior and isn't already in MEMORY.md?
4. Collect candidates. For each:
   - Show: `Proposed: [entry text] — from sources/<file>`
   - Ask: "Add to MEMORY.md? (y/n/edit)"
   - `y` → append under `## Active` with today's date and source citation
   - `edit` → let user rephrase, then append
   - `n` → skip, move on
5. If no candidates: say "No new entries to propose from recent sources."

Bar (same as ingest): concrete decision, hard lesson, or constraint. Not summaries, not facts already in wiki pages.

---

### `sage memory inbox`

Show all Active entries that have no source citation (orphaned) or were added more than 90 days ago without a review marker.

1. Read `## Active` section of MEMORY.md
2. Flag entries where:
   - No `— source:` citation
   - Date is more than 90 days ago
3. For each flagged entry, show it and ask: "Still relevant? (keep/archive/forget)"
4. Apply chosen action (see archive/forget below)
5. If nothing flagged: say "Memory inbox is clean."

---

### `sage memory archive <entry-keyword>`

Move a matching Active entry to the Archived section.

1. Read `## Active` section
2. Find entries containing `<entry-keyword>` (case-insensitive)
3. If multiple matches: show list, ask user to pick
4. Move matched entry from `## Active` to `## Archived`, appending `— archived: <today>`
5. Update `updated:` frontmatter date
6. Confirm: "Archived: [entry]"

---

### `sage memory restore <entry-keyword>`

Move a matching Archived entry back to Active.

1. Read `## Archived` section
2. Find entries containing `<entry-keyword>`
3. If multiple matches: show list, ask user to pick
4. Strip `— archived: <date>` suffix, move entry back to `## Active`
5. Update `updated:` frontmatter date
6. Confirm: "Restored: [entry]"

---

### `sage memory forget <entry-keyword>`

Permanently delete an entry (Active or Archived).

**Always confirm before deleting.**

1. Search both `## Active` and `## Archived` for entries containing `<entry-keyword>`
2. Show the matched entry and ask: "Permanently delete this entry? This cannot be undone. (y/n)"
3. If `y`: remove the line, update `updated:` frontmatter
4. If `n`: abort, say "Cancelled."

---

### `sage memory explain <entry-keyword>`

Trace why an entry exists and what evidence supports it.

1. Find matching entry in `## Active` (or Archived if not found)
2. Extract `source:` citation from the entry
3. If source file exists: read it, show relevant excerpts that support the entry
4. If no source citation: say "No source recorded for this entry — it may have been added manually."
5. Show:
   ```
   Entry: [full entry text]
   Added: [date from entry]
   Source file: sources/<file>
   Supporting excerpt: "<relevant passage from source>"
   ```
6. If the entry contradicts or is superseded by something now in the wiki, flag it: "Note: wiki page [[X]] now covers this — consider archiving."
