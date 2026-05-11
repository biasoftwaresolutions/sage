---
name: sage-lint
description: Run sage wiki health checks and auto-fix deterministic issues. Triggers on "sage lint", "/sage-lint".
---

## Memory context

If `~/sage/wiki/sage-memory/HEARTBEAT.md` exists, you will update it in Step 5b after running checks. No need to read it before linting.

---

# sage lint

Run deterministic checks, auto-fix what needs no judgment, flag the rest.

## Step 1 — run checks

```bash
python3 ~/sage/scripts/sage-operations.py lint
```

Parse the JSON output. Group issues by `type`.

## Step 2 — auto-fix (no confirmation needed)

Apply these fixes silently without asking:

### `index_drift` — page exists but missing from `wiki/index.md`

Open `wiki/index.md`. Add under the correct category:
```
- [[<slug>]] — <tldr from page frontmatter>. <maturity> · <source_count> sources
```
If no matching category exists, add under the closest match or create one.

### `confidence_gap` — Key Fact bullet missing `[confidence: ...]`

Open the page. Append `` `[confidence: medium]` `` to the end of the flagged line.
(Medium = safe default when confidence is unknown.)

### `dead_link` — `[[link]]` pointing to a non-existent page

- If the link is clearly a typo or alias for an existing page: fix the link target.
- If no matching page exists: remove the `[[brackets]]`, leave plain text.

## Step 3 — rebuild knowledge graph

```bash
python3 ~/sage/scripts/sage-operations.py rebuild-knowledge-graph
```

Always run this after applying any fixes.

## Step 4 — flag for review (report, don't touch)

Report these to the user. Do not modify pages without being asked:

| Issue | What to report |
|-------|---------------|
| `orphan` | Page has no inbound links. List them. Suggest which pages might link to them. |
| `thin` | Page has only 1 source (maturity: seed). List them. Note they need more raw material. |
| `bloated` | Page >100 lines. Flag with line count. Suggest what section to split into a new page. |
| `stale` | Source published >2 years ago. List with date. Ask if still relevant. |
| `misclassified` | Page in wrong directory (entity in concepts/, etc.). List with suggested move. |
| `gap` | Structural knowledge gap. Two subtypes: (a) concept page with no entity examples — list concepts, suggest which entity pages to create or link; (b) entity linked by no concept page — list entities, suggest which concept to add it to. |
| `duplicate_candidate` | Two pages with overlapping names/aliases or 3+ shared tags. List pairs. Review each: if they describe the same thing under different names, propose a merge (keep the more complete page, redirect the other). |
| `contradiction` | (LLM-detected, see Step 4b below) Two pages with conflicting claims about the same subject. List which pages and what claims conflict. Flag for human review — do not auto-resolve. |

## Step 4b — Contradiction scan (LLM judgment)

For pages sharing 2+ tags, scan their **Key Facts** sections for conflicting claims:
- Conflicting numbers (e.g., "founded in 2018" vs "founded in 2019")
- Conflicting status (e.g., "open source" vs "proprietary")
- Conflicting relationships (e.g., "acquired by X" vs "merged with Y")

If a conflict is found:
- Add `{"type": "contradiction", "pages": ["a", "b"], "claim_a": "...", "claim_b": "..."}` to your report
- Do NOT modify either page — flag for human review only

## Step 5 — append to log

Append to `wiki/log.md`:
```
## [<ISO timestamp>] lint | health check

- Checks run: orphan, dead_link, thin, bloated, confidence_gap, stale, index_drift, misclassified, gap, duplicate_candidate, contradiction
- Auto-fixed: <list what was fixed, or "none">
- Flagged for review: <N> issues

---
```

## Step 5b — update HEARTBEAT.md

If `~/sage/wiki/sage-memory/HEARTBEAT.md` exists:

1. Open it.
2. Replace the `## Health — <date>` section with today's stats from the lint output:

```
## Health — <today YYYY-MM-DD>
- Pages: <total page count from sage-operations.py lint output>
- Sources: <source page count>
- Issues: <N> found, <N> auto-fixed, <N> flagged
```

3. Replace `## Issues to Resolve` content with current flagged issues (orphan, thin, bloated, stale, misclassified, gap, duplicate_candidate, contradiction). Format as checkboxes:

```
## Issues to Resolve
- [ ] <page-slug> — <issue type> — <one-line suggested fix>
```

Clear resolved items (issues that no longer appear in lint output).

4. Append new gaps to `## Research Queue` if the lint found `gap` issues:

```
- [ ] <concept or entity name> — needs <more sources | entity page | concept link>
```

Do not duplicate items already in the queue.

5. Update `## Last Lint`:

```
## Last Lint
`<ISO timestamp>` — `<N> issues found, <N> auto-fixed`
```

6. Update the frontmatter `updated:` field to today's date.

---

## Step 6 — report summary

```
N issues found. N auto-fixed. N flagged for review.

Flagged:
- <N>x orphan: <page list>
- <N>x thin: <page list>
...
```

If zero issues: "Wiki is clean."

---

## sage-operations.py reference

`scripts/sage-operations.py` handles all deterministic checks without LLM.
The LaunchAgent runs `sage-operations.py lint --fix` daily — auto-fixes confidence_gap, index_drift, dead_link automatically at the scheduled time.

```bash
python3 ~/sage/scripts/sage-operations.py lint          # check only, JSON output
python3 ~/sage/scripts/sage-operations.py lint --fix    # check + auto-apply deterministic fixes
python3 ~/sage/scripts/sage-operations.py discover      # find raw files not yet ingested
python3 ~/sage/scripts/sage-operations.py rebuild-knowledge-graph
python3 ~/sage/scripts/sage-operations.py status        # quick wiki stats
python3 ~/sage/scripts/sage-operations.py trends           # surface topics accumulating sources
python3 ~/sage/scripts/sage-operations.py trends --months 6  # shorter lookback window
```

Requires LLM judgment (not handled by sage-operations.py): `gap`, `duplicate_candidate`, `contradiction`.

`SAGE_ROOT` env var overrides the default path detection.
