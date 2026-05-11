# sage — schema

This file documents the wiki's architecture, page schema, and conventions. Operational instructions (ingest, lint, research protocols) live in `skills/` and are loaded on demand.

## Architecture

```
sage/
├── sage.md              ← you are here (architecture + schema reference)
├── sources/                 ← immutable source documents (human adds; subdirectories OK)
├── wiki/                ← LLM-maintained structured articles
│   ├── index.md         ← master catalog by category
│   ├── _knowledge-graph.json  ← page connection graph (auto-generated)
│   ├── log.md           ← chronological record of all operations
│   ├── sources/         ← one summary page per ingested source
│   ├── concepts/        ← concept/topic articles
│   ├── entities/        ← people, orgs, projects, tools
│   ├── comparisons/     ← side-by-side analyses
│   └── explorations/    ← filed-back query results
├── skills/              ← operational instructions, loaded on demand
│   ├── sage-ingest.md   ← full ingest protocol + all page templates
│   ├── sage-lint.md     ← lint checks + sage-operations.py commands
│   └── sage-research.md ← research modes
├── scripts/
│   ├── sage-operations.py           ← deterministic wiki ops (lint, discover, backlinks) — no LLM
│   ├── daily-maintenance.sh
│   ├── install-launchagent.sh
│   └── install-skills.sh
└── wiki_server.py       ← local web viewer + HTTP API
```

### Three layers

1. **sources/** — Human-curated source collection. Immutable — read only, never modify.
2. **wiki/** — LLM-maintained. Structured pages, cross-references, index, log.
3. **skills/** — Operational instructions. Loaded on demand when a command is triggered.

---

## Page schema

Every wiki page uses YAML frontmatter + consistent markdown. Common fields:

| Field | Values | Description |
|-------|--------|-------------|
| `type` | `source \| concept \| entity \| comparison \| exploration` | Page type |
| `maturity` | `seed \| growing \| mature \| established` | seed=1 src, growing=2-3, mature=4-6, established=7+ |
| `source_count` | integer | Number of sources this page draws from |
| `aliases` | list | Alternate names / abbreviations |
| `tags` | list | Topic tags |
| `date_created` | ISO date | When page was created |
| `date_updated` | ISO date | When page was last updated |

Full page templates (source, concept, entity, comparison, exploration) are in `skills/sage-ingest.md`.

---

## Conventions

- **File naming:** lowercase, hyphens, no spaces. `example-concept.md`
- **Wiki links:** `[[page-name]]` syntax (Obsidian-compatible). Link to filename without extension.
- **Confidence tags:** inline after claims: `[confidence: high]` `[confidence: medium]` `[confidence: low]`
  - `high` = explicitly stated in source
  - `medium` = reasonable inference
  - `low` = speculative
- **Dates:** ISO 8601. `2026-04-09` for dates, `2026-04-09T14:30:00Z` for timestamps.
- **Idempotent ingest:** ingesting the same source twice must not duplicate content.
- **Every claim links to its source.** No orphan claims.
- **Obsidian-compatible:** `[[wikilinks]]`, YAML frontmatter, directory structure all work natively.

---

## Index structure (`wiki/index.md`)

```markdown
# sage Wiki Index

> Last updated: 2026-04-09 | 42 pages | 15 sources

## Categories

### Category Name
- [[example-concept]] — One-line summary. mature · 6 sources · also: alt-name
- [[another-concept]] — One-line summary. growing · 3 sources

## Recent

| Date | Operation | Pages Touched |
|------|-----------|---------------|
| 2026-04-09 | ingest: "Example Source" | 8 pages |
```

---

## Log structure (`wiki/log.md`)

Append-only. Never rewrite history. Each entry starts with `## [timestamp] operation | description`.

```markdown
## [2026-04-09T14:30:00Z] ingest | "Example Source Title"

- Source: sources/example-source.md
- Created: sources/example-source.md, concepts/example-concept.md
- Updated: entities/example-entity.md
- Pages touched: 4

---
```

---

## Backlinks (`wiki/_knowledge-graph.json`)

Auto-generated after every ingest and lint by `scripts/sage-operations.py rebuild-knowledge-graph`.

```json
{
  "backlinks": { "example-concept": ["another-concept", "example-source"] },
  "forward":   { "another-concept": ["example-concept"] }
}
```

---

## sage-operations.py commands

`scripts/sage-operations.py` runs deterministic operations without LLM. Used by the daily LaunchAgent.

```bash
python3 scripts/sage-operations.py lint                # check only, JSON output
python3 scripts/sage-operations.py lint --fix          # check + auto-apply deterministic fixes
python3 scripts/sage-operations.py scan                # scan sources/ for secrets before ingest
python3 scripts/sage-operations.py discover            # find sources/ files not yet ingested
python3 scripts/sage-operations.py rebuild-knowledge-graph   # regenerate _knowledge-graph.json
python3 scripts/sage-operations.py status              # quick wiki stats
```

`SAGE_ROOT` env var overrides auto-detected path.

**Auto-fixable by `lint --fix` (no LLM):** `confidence_gap`, `index_drift`, `dead_link`

**Requires LLM judgment:** `orphan`, `thin`, `bloated`, `stale`, `misclassified`

---

## Local server API

`wiki_server.py` exposes `http://localhost:3000`:

| Endpoint | Description |
|----------|-------------|
| `GET /api/context?topic=X` | Best matching page + graph neighborhood in one call |
| `GET /api/search?q=X` | Ranked search (title, alias, tag, fulltext) |
| `GET /api/pages` | All pages with metadata |
| `GET /api/graph` | All nodes + edges |
| `GET /api/backlinks` | Reverse + forward link index |
| `GET /api/rebuild-knowledge-graph` | Rebuild `_knowledge-graph.json` |
