---
name: sage-ingest
description: Ingest new raw sources into the sage wiki. Triggers on "sage ingest", "/sage-ingest".
---

## Memory context

If `~/sage/wiki/sage-memory/` exists, read these files before writing any pages:
- `SOUL.md` — depth preference and domain focus: use to frame summaries and calibrate detail level
- `USER.md` — background and tracked entities: use to calibrate assumed knowledge; auto-link tracked entities when they appear
- `MEMORY.md` — past decisions: don't contradict settled conclusions without flagging it
- `HEARTBEAT.md` — research queue: if a new source fills a queued gap, note it in the report

If a source surfaces something that clears the MEMORY.md bar (see sage-init for definition), pitch it before writing.

---

# sage ingest

Discover and process new raw files into structured wiki pages.

## Step 1 — scan for secrets

```bash
python3 ~/sage/scripts/sage-operations.py scan
```

If `safe` is false: **stop immediately.** Show the findings and say: "Found potential secrets in [files]. Redact before ingesting." Do not proceed until the user confirms the files are clean.

## Step 2 — discover

```bash
python3 ~/sage/scripts/sage-operations.py discover
```

If `new_count` is 0: say "No new files to ingest." Stop.

## Step 3 — for each new file

Read the full file.

### Memory extraction

Before creating any wiki pages, scan the source for personal context signals. If `wiki/sage-memory/` doesn't exist, skip this sub-step.

**Bar: high.** Default is to skip. Only update memory files when the signal is unambiguous, durable, and not already captured. Prefer missing something over adding noise.

**USER.md** — update only if the source clearly and directly reveals:
- The user's role or employer (not inferred, explicitly stated — never infer or store name)
- A project they own or are actively building (durable commitment, not a one-off task)
- A key person by name + stable relationship (manager, co-founder, longstanding collaborator — not every meeting attendee)

Skip if: the user is just discussing a topic, referencing someone else's work, or the fact is transient (a one-time event, a task they completed).

**SOUL.md** — update only if the source explicitly states:
- Why they are building this wiki or studying this domain
- A strongly stated depth preference ("I never need implementation detail, just concepts")
- A domain priority that reframes everything else they're reading

Skip if: it's an implied interest, a one-time curiosity, or something already reflected in existing SOUL.md content.

**Merge, don't append.** If the info updates an existing line, rewrite that line. Don't add a new bullet for something already captured in different words. Keep both files short and scannable.

For USER.md and SOUL.md: update silently if the bar is cleared. At the end of the ingest report, note: "Memory updated: USER.md (role)" — keep it brief. If nothing clears the bar, say nothing.

**MEMORY.md** — pitch only if:
- A concrete decision was made that should not be relitigated
- A hard lesson emerged from a failure or surprise — specific enough to change future behavior
- A constraint was established that should affect future recommendations
- Test: "Would this change what I recommend next time?" If no, skip it.

Show the proposed entry and ask: "Found something worth remembering: [X]. Add to MEMORY.md? (y/n)"

Then create or update wiki pages as described below.

---

### Source page

Path: `wiki/sources/<slug>.md`
Slug = title lowercased, spaces→hyphens, no special chars.

```markdown
---
type: source
title: "<title>"
author: "<author or Unknown>"
date_published: "<YYYY-MM-DD or best estimate>"
date_ingested: "<today ISO>"
source_url: "<URL or empty>"
tags: [<2-4 relevant tags>]
confidence: high
aliases: []
---

# <title>

> **TLDR:** <one sentence — the key takeaway>

## Summary

<2-4 paragraphs: what does it argue, what evidence, what is novel>

## Key Claims

- **<Claim>** — <description>. `[confidence: high]`
- **<Claim>** — <description>. `[confidence: medium]`

## Connections

- Related to [[<concept-slug>]] because...
- Contradicts [[<other-slug>]] on the topic of...

## Raw Source

`<relative path from sage root, e.g. sources/clippings/file.md>`
```

---

### Concept page

Path: `wiki/concepts/<slug>.md`

```markdown
---
type: concept
title: "<Concept Name>"
aliases: []
date_created: "<today>"
date_updated: "<today>"
source_count: 1
tags: [<tags>]
maturity: seed
---

# <Concept Name>

> **TLDR:** <one sentence definition accessible to a newcomer>

## Overview

<2-4 paragraphs, Wikipedia-style: neutral, clear, encyclopedic. Cite sources with [[source-slug]] links.>

## How It Works

<Technical explanation if applicable. Code blocks, step-by-step, or diagrams.>

## Key Facts

- **<Fact>** — <explanation>. *Source: [[<source-slug>]]* `[confidence: high]`
- **<Fact>** — <explanation>. *Source: [[<source-slug>]]* `[confidence: medium]`

## Open Questions

- <unanswered question from the source>
- <contradiction between sources if any>

## Related

- [[<related-slug>]] — <how they connect>

## Sources

- [[<source-slug>]]
```

---

### Entity page

Path: `wiki/entities/<slug>.md`
`entity_type`: `person | organization | project | tool | dataset`

```markdown
---
type: entity
title: "<Name>"
entity_type: <person|organization|project|tool|dataset>
aliases: []
date_created: "<today>"
date_updated: "<today>"
tags: [<tags>]
source_count: 1
maturity: seed
---

# <Name>

> **TLDR:** <one-line description: who/what is this>

## Overview

<Who or what is this entity, why they matter in this wiki's context>

## Key Contributions

- <contribution>. *Source: [[<source-slug>]]*
- <contribution>. *Source: [[<source-slug>]]*

## Connections

- Created [[<project-slug>]]
- Works on [[<concept-slug>]]
- Affiliated with [[<org-slug>]]

## Sources

- [[<source-slug>]]
```

---

### Comparison page

Path: `wiki/comparisons/<slug>.md`
Create only when source explicitly compares two or more things.

```markdown
---
type: comparison
title: "<X vs Y>"
date_created: "<today>"
date_updated: "<today>"
subjects: ["<X>", "<Y>"]
aliases: []
tags: [<tags>]
source_count: 1
maturity: seed
---

# <X vs Y>

> **TLDR:** <one-sentence verdict or key distinction>

## Overview

<Why compare these? What decision does this serve?>

## Comparison

| Dimension | <X> | <Y> |
|-----------|-----|-----|
| <Aspect>  | ... | ... |
| <Aspect>  | ... | ... |

## Analysis

<Deeper discussion of trade-offs, when each is better, nuances.>

## Verdict

<When to use X. When to use Y. Or: why the distinction matters.>

## Sources

- [[<source-slug>]]
```

---

### Exploration page

Path: `wiki/explorations/<slug>.md`
Create when user asks a question and wants the answer filed back.

```markdown
---
type: exploration
title: "<Question or Analysis Title>"
date_created: "<today>"
query: "<the original question>"
aliases: []
tags: [<tags>]
---

# <Question or Analysis Title>

> **Query:** <the original question>

## Answer

<Synthesized answer, citing wiki pages with [[wikilinks]].>

## Reasoning

<How the answer was derived. Which pages consulted. What connections made.>

## Sources Consulted

- [[<wiki-page-1>]]
- [[<wiki-page-2>]]
```

---

## Step 4 — create or update concept/entity pages

For each significant concept, entity, person, project, or tool in the source:

- Check if `wiki/concepts/<slug>.md` or `wiki/entities/<slug>.md` exists
- **If exists:** open it, add new claims under relevant sections, increment `source_count`, update `date_updated`, advance `maturity`:
  - seed → growing at 2 sources
  - growing → mature at 4 sources
  - mature → established at 7 sources
- **If not exists:** create with `maturity: seed`, `source_count: 1`

Only create a page if you can write a real TLDR + 2-paragraph Overview. Otherwise fold the mention into an existing page as a claim.

## Step 5 — check for contradictions

If a new claim contradicts an existing page, note it in both pages' **Open Questions** section.

## Step 6 — update index

Open `wiki/index.md`. Add any new pages under the correct category:
```
- [[slug]] — <tldr>. <maturity> · <source_count> sources
```
Update the header: `Last updated: <today> | <N> pages | <N> sources`

## Step 7 — rebuild knowledge graph

```bash
python3 ~/sage/scripts/sage-operations.py rebuild-knowledge-graph
```

## Step 8 — append to log

Append to `wiki/log.md`:
```
## [<ISO timestamp>] ingest | "<source title>"

- Source: <raw path>
- Created: <list new pages>
- Updated: <list updated pages with what changed>
- Pages touched: <N>

---
```

## Step 9 — report

List all pages created and updated. Note open questions or contradictions found.

---

## Writing standards

- **Wikipedia-neutral voice.** Flat, factual, encyclopedic.
- **Paraphrase over block quotes.** Direct quotes only when phrasing is the point.
- **Concrete over abstract.** "Reduces latency by 40%" not "significantly improves performance."
- **Active voice.** "The system extracts metrics" not "metrics are extracted."
- **No peacock words.** No "legendary", "groundbreaking", "revolutionary".
- **No editorial voice.** No "interestingly", "importantly", "it should be noted".
- **Confidence tags on all Key Fact bullets:** `[confidence: high|medium|low]`
  - high = explicitly stated in source
  - medium = reasonable inference
  - low = speculative
- **Every claim links to its source page.** No orphan claims.
- **File naming:** lowercase, hyphens, no spaces. `example-concept.md`
- **Dates:** ISO 8601. `2026-04-09` for dates, `2026-04-09T14:30:00Z` for timestamps.
