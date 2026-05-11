---
name: sage-init
description: Onboarding wizard — creates sage memory layer and seeds wiki with web content. Triggers on "sage init", "/sage-init".
---

# sage init

Set up sage for the first time. Creates the memory layer (`wiki/sage-memory/`) and seeds the wiki with real web content.

---

## Step 0 — re-run check

Check if `~/sage/wiki/sage-memory/` exists and contains any files.

If yes, ask:
> "Memory layer exists. What would you like to do?
> **(a)** Update profile — redo questions, rewrite SOUL.md and USER.md
> **(b)** Re-seed topics — fetch fresh web content for your domain interests (reads existing SOUL.md)
> **(c)** Both
> **(d)** Cancel"

Proceed only with the chosen scope. If **(d)**: stop.

---

## Step 1 — questionnaire

Ask these questions **one at a time**. Wait for a complete answer before moving on.

**Q1.** "What do you do? (Name is optional — skip it if you prefer.)"
*(→ USER.md: Identity)*

**Q2.** "Any domain background worth noting — years of experience, things you're new to, areas you want to go deeper in?"
*(→ USER.md: Background)*

**Q3.** "Why are you building this wiki? What problem does it solve for you day-to-day?"
*(→ SOUL.md: Why sage)*

**Q4.** "List 3–5 topics you want to track. These will seed your wiki with real content from the web."
*(→ SOUL.md: Domain Interests — also drives Step 3)*

**Q5.** "Preferred depth: quick summaries that get you up to speed fast, or deep technical dives that go into the how and why?"
*(→ SOUL.md: Depth Preference — answer: "summary" or "deep-dive")*

**Q6.** "Any specific people, projects, or organisations you're already tracking or want to follow? (Press Enter to skip)"
*(→ USER.md: Tracked Entities)*

**Scope shortcuts:**
- Re-seed only (scope b): skip Q1, Q2, Q6 — read existing USER.md instead
- Profile update only (scope a): skip Q4 — no web seeding

---

## Step 2 — write memory layer

> **Scope (b) — re-seed only:** skip this step entirely. Proceed directly to Step 3 and read Domain Interests from existing SOUL.md.

Create `~/sage/wiki/sage-memory/` if it doesn't exist.

**Scope-aware writes:**
- Scope (a) — profile update: overwrite SOUL.md and USER.md with new answers. Preserve MEMORY.md and HEARTBEAT.md unchanged.
- Scope (c) — both: rewrite SOUL.md and USER.md as in scope (a), then proceed with Step 3.
- First run: write all four files as below.

Write all four files:

### `SOUL.md`

```
---
type: soul
created: <today YYYY-MM-DD>
updated: <today YYYY-MM-DD>
---

# Soul

> What this wiki is for. Informs every sage operation.

## Why sage
<Q3 answer, written as a clean paragraph in the user's own words>

## Domain Interests
<Q4 answers, one bullet per topic>

## Depth Preference
<"summary" or "deep-dive" based on Q5>

## Focus Rules
<!-- Add constraints here as you discover them, e.g. "always cite sources", "prefer first-principles explanations" -->
```

### `USER.md`

```
---
type: user
created: <today YYYY-MM-DD>
updated: <today YYYY-MM-DD>
---

# User

> Who is using this wiki. Informs framing, assumed knowledge, and entity tracking.

## Identity
**Role:** <Q1 role / occupation>
**Name:** <Q1 name, or omit this line entirely if user skipped it>
**Background:** <Q2 answer>

## Tracked Entities
- People: <Q6 people, or "none yet">
- Projects: <Q6 projects, or "none yet">
- Orgs: <Q6 orgs, or "none yet">
```

### `MEMORY.md`

```
---
type: memory
updated: <today YYYY-MM-DD>
---

# Memory

> High-signal decisions and lessons. Append-only. Each entry must clear the bar: would this change future sage behavior or a user decision?

**Does not belong here:** facts already in wiki pages, article summaries, transient context.

<!-- newest first -->
```

### `HEARTBEAT.md`

```
---
type: heartbeat
updated: <today YYYY-MM-DD>
---

# Heartbeat

> Wiki health snapshot. Auto-updated by sage lint and daily maintenance.

## Health — <today YYYY-MM-DD>
- Pages: 0 total
- Sources: 0
- Issues: run `sage lint` to populate

## Issues to Resolve
<!-- Auto-populated by sage lint -->

## Research Queue
<!-- Claude appends here during sage research when gaps are found. Edit freely. -->

## Last Lint
Not yet run — run `/sage-lint` to populate.
```

---

## Step 3 — web seeding

For each topic in `SOUL.md → Domain Interests`:

1. **Search:** `WebSearch("<topic> explained OR overview OR deep-dive", n=5)`
   Prefer: substack.com, medium.com, arxiv.org, well-known technical blogs.

2. **Select:** Pick 2–3 results most relevant to the user's role (USER.md) and motivation (SOUL.md). Quality over quantity.

3. **Fetch:** `WebFetch(<url>)` — extract title, author, publish date, full content.

4. **Save** to `~/sage/sources/seed/<topic-slug>/<article-slug>.md`:

```
---
title: "<article title>"
author: "<author or Unknown>"
date_published: "<YYYY-MM-DD or best estimate>"
source_url: "<URL>"
fetched_by: sage-init
topic: "<topic-slug>"
---

<full article content>
```

Slug rules: lowercase, spaces → hyphens, strip special characters.

**Failure handling:**
- No search results for a topic → create stub and continue:
  Save to `sources/seed/<topic-slug>/<topic-slug>-stub.md`:
  ```
  ---
  title: "<Topic Name> — Stub"
  fetched_by: sage-init
  topic: "<topic-slug>"
  status: stub
  ---
  # <Topic Name>
  No seed content fetched automatically. Add sources manually to this folder.
  ```
- WebFetch fails on a URL → skip it, try next search result.
- All fetches fail for a topic → create stub, continue to next topic.

---

## Step 4 — ingest

Run `sage ingest` on all new seed files. Full pipeline: source pages, concept pages, entity pages, backlinks, index, log.

---

## Step 5 — report

```
✓ Memory layer created (or updated) at ~/sage/wiki/sage-memory/
  SOUL.md · USER.md · MEMORY.md · HEARTBEAT.md

✓ Topics seeded:
  <topic 1>: N articles fetched
  <topic 2>: N articles fetched
  ...

✓ Wiki pages created:
  <list from ingest report>

Next: /sage-research <topic> to go deeper · /sage-lint to populate HEARTBEAT
```

---

## Memory — proactive flagging

During any sage operation, if you surface something that clears this bar — *"would this change how sage serves this user, or how the user makes decisions in their domain?"* — pitch it before writing:

> "I think this is worth remembering: **[what]**. It will help me [specific benefit — e.g. 'not re-surface this as a new finding', 'stay aligned with your position on X']. Should I add it to MEMORY.md?"

Append only after confirmation. Never write to MEMORY.md silently.

**`sage remember <thing>`** → append immediately, no confirmation needed:

```
## [<today YYYY-MM-DD>] <short title derived from <thing>> `[<topic-tag>]`
<thing, written as 1–3 clear sentences: what was learned/decided and why it matters>
*Flagged during: explicit request*

---
```
*Topic tag: use the closest slug from SOUL.md Domain Interests, or create a short one-word tag.*
