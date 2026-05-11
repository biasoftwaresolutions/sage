---
name: sage-research
description: Find wiki gaps and surface research topics. Triggers on "sage research", "/sage-research".
---

## Memory context

If `~/sage/wiki/sage-memory/` exists, read these files before researching:
- `SOUL.md` — domain interests and depth preference: focus search on declared interests, match depth to preference
- `USER.md` — background: pitch sources at the right level; note entity connections
- `MEMORY.md` — past decisions: don't re-surface settled conclusions as new findings
- `HEARTBEAT.md` — research queue: check if the requested topic is already queued; append new gaps found

If research surfaces a conclusion that clears the MEMORY.md bar, pitch it before writing.

---

# sage research

Three modes depending on the argument given.

---

## `research <topic>` — web discovery

Find sources on the web for a specific topic.

1. Search the web for `<topic>`
2. Find 5-8 candidate sources (articles, papers, blog posts, docs)
3. For each candidate present:
   - Title
   - URL
   - 2-3 sentence summary
   - Relevance to existing wiki pages (which pages would benefit)
4. User picks which to keep
5. For each approved source, save to `~/sage/sources/<slug>.md`:

```markdown
---
title: "<title>"
source_url: "<url>"
author: "<author>"
date_published: "<date>"
date_captured: "<today>"
---

<full content of the source>
```

6. Do NOT auto-ingest. Tell user: "Saved to sources/. Run `ingest` when ready."

Append to `wiki/log.md`:
```
## [<ISO timestamp>] research | web: "<topic>"

- Candidates found: <N>
- Saved to sources/: <list of filenames>

---
```

---

## `research chat` — conversation capture

Capture insights from the current conversation into sources/.

1. Review the current conversation for key insights, decisions, ideas, or knowledge worth preserving
2. Present a bullet-point summary of what would be captured
3. If user approves, save to `~/sage/sources/conversation-<topic>-<date>.md`:

```markdown
---
title: "<descriptive name for the conversation topic>"
source_type: conversation
date_captured: "<today>"
participants: human + AI
---

<synthesized knowledge from the conversation — NOT a raw transcript>
<extract the knowledge, not the back-and-forth>
```

4. Do NOT auto-ingest. Tell user: "Saved. Run `ingest` when ready."

Only capture if the conversation has substantive knowledge worth preserving. If it was just debugging or small tasks, say so and skip.

---

## `research wiki` — gap analysis (default if no argument)

Find what the wiki is missing and prioritize research targets.

1. Run status:
```bash
python3 ~/sage/scripts/sage-operations.py status
```

2. Read `wiki/index.md` and `wiki/_knowledge-graph.json`

3. Identify gaps:
   - **Thin pages** (maturity: seed) that need more sources
   - **Concepts mentioned across multiple pages** but lacking their own page (scan for repeated `[[links]]` to missing pages)
   - **Open Questions** listed in existing pages — explicit research gaps
   - **Adjacent topics** the wiki doesn't cover yet

4. Present a prioritized table:

| Priority | Topic | Why | Thin page? | Suggested search terms |
|----------|-------|-----|------------|----------------------|
| 1 | ... | pages X, Y would benefit | yes/no | "..." |

5. User picks which to pursue, then run `research <topic>` for each.

Append to `wiki/log.md`:
```
## [<ISO timestamp>] research | wiki gap analysis

- Pages reviewed: <N>
- Thin pages: <N>
- Open questions found: <N>
- Topics suggested: <N>

---
```

---

## Research rules

- **Research proposes, user approves.** Nothing enters `sources/` without confirmation.
- **Every saved file needs clear attribution:** source URL, date, author.
- **Conversation captures:** synthesize knowledge, don't dump transcripts.
- **No auto-ingest.** The user controls what gets ingested and when.
