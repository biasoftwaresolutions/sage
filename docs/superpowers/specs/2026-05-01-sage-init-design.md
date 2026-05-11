# sage-init Design Spec

**Date:** 2026-05-01
**Status:** Approved
**Command:** `sage init` / `/sage-init`

---

## Overview

`sage-init` is an onboarding wizard that runs once after installation. It asks questions about the user, writes four memory layer files into `wiki/sage-memory/`, fetches seed content from the web for each declared topic interest, and auto-ingests everything so the wiki has real pages immediately after first run.

Inspired by OpenClaw's memory layer — SOUL (what you want), USER (who you are), MEMORY (what you've learned), HEARTBEAT (wiki health) — assembled into every agent operation to personalize behavior without modifying core skill logic.

---

## Architecture

### New files

```
sage/
├── raw/
│   └── seed/
│       └── <topic-slug>/            ← web-fetched articles per topic
│           └── <article-slug>.md
├── wiki/
│   └── sage-memory/                 ← memory layer (never linted as wiki pages)
│       ├── SOUL.md                  ← what: goals, motivations, domain interests, depth
│       ├── USER.md                  ← who: name, role, background, tracked entities
│       ├── MEMORY.md                ← selective: high-signal decisions & lessons
│       └── HEARTBEAT.md             ← wiki health snapshot + research queue
└── skills/
    └── sage-init.md                 ← the wizard skill
```

### Modified files

| File | Change |
|------|--------|
| `skills/sage-ingest.md` | Add Context section: read sage-memory/ first |
| `skills/sage-research.md` | Add Context section: read sage-memory/ first |
| `skills/sage-capture.md` | Add Context section: read sage-memory/ first |
| `scripts/install-skills.sh` | Add `sage-init` to install loop |
| `integrations/_shared/sage-instructions.md` | Add `sage init` + `sage remember` trigger rows |
| `integrations/_shared/sage-instructions-project.md` | Add `sage init` + `sage remember` trigger rows |
| `~/.claude/CLAUDE.md` | Add `sage init` + `sage remember` rows to trigger table |
| `README.md` | Document `sage init`, memory layer, and `sage remember` |

---

## Memory Layer Schema

All four files live at `~/sage/wiki/sage-memory/`. Plain markdown — read and edit freely at any time.

---

### SOUL.md — *what* the user wants

```markdown
---
type: soul
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Soul

> What this wiki is for. Informs every sage operation.

## Why sage
<one paragraph — motivation, the problem sage solves for this user>

## Domain Interests
- <topic 1>
- <topic 2>
- <topic 3>

## Depth Preference
<summary | deep-dive>

## Focus Rules
<optional: constraints on how sage should behave, e.g. "always cite sources", "prefer first-principles explanations">
```

---

### USER.md — *who* the user is

```markdown
---
type: user
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# User

> Who is using this wiki. Informs framing, assumed knowledge, and entity tracking.

## Identity
**Name:** <name>
**Role:** <role / occupation>
**Background:** <domain expertise, e.g. "10 years backend, new to ML">

## Tracked Entities
- People: <names>
- Projects: <names>
- Orgs: <names>
```

---

### MEMORY.md — *what* has been learned (selective, append-only)

High bar for entry. Only stores things that would change future sage behavior or user decisions. Article summaries don't qualify — those belong in wiki pages.

**Qualifies:**
- A research conclusion that shifts how a topic should be understood
- A decision the user made and why (so sage doesn't re-litigate it)
- A pattern noticed across multiple sources
- Something the user explicitly flagged

**Does not qualify:**
- Facts already captured in wiki concept/source pages
- Transient session context
- Summaries of individual articles

```markdown
---
type: memory
updated: YYYY-MM-DD
---

# Memory

> High-signal decisions and lessons. Append-only. Each entry must clear the bar: would this change future behavior?

<!-- newest first -->

## [YYYY-MM-DD] <short title> `[<topic-tag>]`
<1-3 sentences: what was learned or decided, and why it matters>
*Flagged during: <sage research | sage ingest | explicit request>*

---
```

**Update triggers:**

1. **Explicit** — user says `sage remember <thing>` → Claude writes immediately, no confirmation needed
2. **Proactive** — during any sage operation, if Claude surfaces something worth keeping, it pitches before writing:

> "I think this is worth remembering: [reason]. It will help me serve you better over time by [specific benefit]. Should I add it to MEMORY.md?"

Claude only appends after user confirms. Never writes silently.

---

### HEARTBEAT.md — wiki health + research queue

Updated automatically by `sage lint` and the daily maintenance script. User can edit the Research Queue manually.

```markdown
---
type: heartbeat
updated: YYYY-MM-DD
---

# Heartbeat

> Wiki health snapshot. Auto-updated by sage lint and daily maintenance.

## Health — <YYYY-MM-DD>
- Pages: <N> total (<N> seed, <N> mature)
- Sources: <N>
- Issues: <N> orphan, <N> thin, <N> stale

## Issues to Resolve
- [ ] <page-slug> — <issue type> — <suggested fix>

## Research Queue
<!-- Claude appends here during sage research when gaps are found. User can also edit directly. -->
- [ ] <topic or question to dig into>

## Last Lint
`<ISO timestamp>` — `<N> issues found, <N> auto-fixed`
```

**Update triggers:**

| Trigger | What updates |
|---------|-------------|
| `sage lint` run | Health snapshot, Issues list, Last Lint |
| `sage research` completes | Appends to Research Queue if gaps found |
| Daily maintenance script | Health snapshot refresh |
| User manual edit | Research Queue (always editable) |

---

## Wizard Flow

`sage-init` is a pure Claude skill. Claude conducts the questionnaire in chat, one at a time.

### Step 0 — Re-run check

If `~/sage/wiki/sage-memory/` already has any files:
- Ask: "Memory layer exists. What would you like to do? (a) Update profile, (b) Re-seed topics, (c) Both, (d) Cancel"
- Proceed only with the chosen scope.

### Step 1 — Questionnaire (6 questions, one at a time)

| # | Question | Maps to |
|---|----------|---------|
| 1 | "What's your name and what do you do?" | `USER.md → Identity` |
| 2 | "Any domain background worth noting? (e.g. years of experience, what you're new to)" | `USER.md → Background` |
| 3 | "Why are you building this wiki — what problem does it solve for you?" | `SOUL.md → Why sage` |
| 4 | "List 3–5 topics you want to track." | `SOUL.md → Domain Interests` + seed trigger |
| 5 | "Preferred depth: quick summaries or deep technical dives?" | `SOUL.md → Depth Preference` |
| 6 | "Any specific people, projects, or orgs you're already tracking? (optional)" | `USER.md → Tracked Entities` |

### Step 2 — Write memory layer

Create `~/sage/wiki/sage-memory/` and write all four files:
- `SOUL.md` from Q3, Q4, Q5
- `USER.md` from Q1, Q2, Q6
- `MEMORY.md` — empty skeleton (no entries yet)
- `HEARTBEAT.md` — empty skeleton (populated after first lint)

### Step 3 — Web seeding

For each topic in `SOUL.md → Domain Interests`:

1. `WebSearch("<topic> explained OR overview OR deep-dive site:substack.com OR site:medium.com OR site:arxiv.org", n=5)`
2. Pick top 2–3 results by relevance to user's declared role and motivation.
3. `WebFetch` each chosen URL — extract title, author, publish date, full content.
4. Write to `raw/seed/<topic-slug>/<article-slug>.md`:

```markdown
---
title: "<article title>"
author: "<author>"
date_published: "<YYYY-MM-DD or best estimate>"
source_url: "<URL>"
fetched_by: sage-init
topic: "<topic-slug>"
---

<full article content>
```

### Step 4 — Ingest

Run `sage ingest` on all new seed files. Full pipeline: source pages, concept pages, entity pages, backlinks, index, log.

### Step 5 — Report

- Memory layer written: SOUL.md, USER.md, MEMORY.md, HEARTBEAT.md
- N articles fetched across M topics
- N wiki pages created (list them)
- "Run `/sage-research <topic>` to go deeper. Run `/sage-lint` to populate HEARTBEAT."

---

## Memory Layer Integration with Existing Skills

Each existing skill (`sage-ingest`, `sage-research`, `sage-capture`) gains this section at the top:

```markdown
## Context
If `~/sage/wiki/sage-memory/` exists, read these files before proceeding:
- `SOUL.md` — what this wiki is for: use to prioritize framing, depth, and focus
- `USER.md` — who the user is: calibrate assumed knowledge and entity tracking
- `MEMORY.md` — past decisions and lessons: don't re-litigate settled conclusions
- `HEARTBEAT.md` — wiki health: be aware of gaps and queue items

Skills work identically if these files are absent.
```

---

## `sage remember` Command

New trigger added to all instruction files:

> **sage remember `<thing>`** → Append entry to `MEMORY.md` immediately, no confirmation.

Claude also proactively pitches during operations when it surfaces something worth keeping:

> "I think this is worth remembering: [what]. It will help me serve you better over time by [specific benefit — e.g. 'not re-surfacing X as a new finding']. Should I add it to MEMORY.md?"

Appends only after user confirms. Never writes silently.

---

## Error Handling

| Failure | Behavior |
|---------|----------|
| WebSearch returns no results for a topic | Log "No seed content found for <topic>" — continue with next topic |
| WebFetch fails on a URL | Skip, try next search result |
| All fetches fail for a topic | Create stub `raw/seed/<topic-slug>/<topic-slug>-stub.md` with note to add sources manually |
| Memory layer write fails | Abort with clear error — do not proceed to web seeding |
| sage ingest fails | Report failure, leave seed files in place for manual retry |

---

## Install Integration

`install-skills.sh` loop:

```bash
for skill in sage-init sage-ingest sage-lint sage-research sage-capture; do
```

`sage-instructions.md` trigger rows:

```markdown
| **sage init** | Read `~/sage/skills/sage-init.md` then follow it exactly |
| **sage remember `<thing>`** | Append entry to `~/sage/wiki/sage-memory/MEMORY.md` immediately |
```

---

## ops.py Compatibility

`wiki/sage-memory/` excluded from lint, backlink, and discover scans. In `ops.py`'s `_load_wiki_pages()`:

```python
if rel.parts[0] == "sage-memory":
    continue
```

`sage lint` reads HEARTBEAT.md separately to update it — it is not treated as a wiki page.

---

## Out of Scope

- `sage soul` / `sage memory` commands for viewing/editing memory layer via chat — future feature
- Adaptive questionnaire branching — future feature
- ops.py `init` subcommand for structured validation — future feature
- Vector search over MEMORY.md entries — future feature
