# sage Brain Architecture

How the sage knowledge brain works — from first run to daily use.

Diagram source: [`sage-brain-architecture.mmd`](./sage-brain-architecture.mmd)

Preview with the [Mermaid Live Editor](https://mermaid.live) or any Mermaid-aware viewer (VS Code extension: _Markdown Preview Mermaid Support_).

---

## Data Flow Summary

| Phase | Trigger | Reads | Writes |
|-------|---------|-------|--------|
| **Setup** | `sage init` | — | `wiki/sage-memory/` + `raw/seed/` |
| **Ingest** | `sage ingest` | `sage-memory/`, `raw/` | `wiki/sources,concepts,entities` |
| **Research** | `sage research <topic>` | `sage-memory/`, `wiki/` | `raw/seed/`, `HEARTBEAT.md` (queue) |
| **Capture** | `sage capture <project>` | `sage-memory/`, conversation | `raw/<project>/` |
| **Lint** | `sage lint` / daily | `wiki/`, `ops.py` output | `wiki/` fixes, `HEARTBEAT.md` |
| **Remember** | `sage remember <thing>` | — | `MEMORY.md` (append) |
| **Query** | `sage query <topic>` | `wiki/` | — |

## Memory Layer Purpose

```
SOUL.md      →  shapes HOW sage writes and prioritises (depth, focus, domain)
USER.md      →  shapes FOR WHOM (assumed knowledge, entity auto-linking)
MEMORY.md    →  shapes WHAT to skip (settled conclusions) and remember (key decisions)
HEARTBEAT.md →  shapes WHAT needs attention (health issues, research queue)
```

## Key Invariants

- `ops.py` never touches `wiki/sage-memory/` — it is excluded from all scans
- `MEMORY.md` is **append-only** and **selective** — only things that change future behavior
- All skills are **additive** — they work identically if `sage-memory/` is absent
- `raw/` is **immutable** — skills read it, never modify it
- Wiki pages are **LLM-maintained** — humans curate sources, AI writes and maintains articles
