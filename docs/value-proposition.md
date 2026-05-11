# sage — Value Proposition & Product Identity

> For image generation, UI design, and brand direction.

---

## What sage is

**sage is a personal knowledge wiki that your AI writes for you.**

You drop sources in. The AI turns them into a structured, cross-referenced, searchable wiki. You never write a single page. Knowledge compounds — every source you add makes the whole wiki richer. Every question you ask gets filed back as an answer page.

It is not a note-taking app. It is not a chatbot. It is a **second brain that builds itself**.

---

## The core problem it solves

Smart people consume enormous amounts of information — articles, papers, videos, conversations, research. Almost none of it sticks in a usable form. Notes get buried. Bookmarks rot. Key insights scatter across 12 different apps.

sage captures all of it, connects it, and makes it retrievable. Not as a search index. As a *structured knowledge graph* where concepts link to each other, sources cite claims with confidence levels, and contradictions between sources are surfaced and flagged.

The result: a wiki that knows what you know, organized the way a researcher would organize it — without you spending time organizing anything.

---

## What sage can do

### 1. Ingest anything into structured pages
Drop a raw file (article, PDF, transcript, screenshot, whiteboard photo, research paper) into `raw/`. Tell sage to ingest. It reads the source and automatically creates:
- A **source page** — TLDR, summary, key claims with confidence levels, connections to other pages
- **Concept pages** — encyclopedic entries for every significant idea (e.g. `product-market-fit`, `unit-economics`, `india-ai-market`)
- **Entity pages** — entries for people, organizations, tools, projects mentioned
- **Comparison pages** — structured tables when sources compare two things head-to-head

All pages cross-link. All claims cite their source. Confidence levels (`high / medium / low`) are tagged on every fact.

### 2. Research new topics from the web
Tell sage to research a topic. It searches the web, finds 5–8 candidate sources, shows you a summary and relevance rating for each, lets you pick which to keep, then saves them to `raw/` ready for ingestion.

Three research modes:
- **`sage research <topic>`** — web discovery for a specific topic
- **`sage research chat`** — capture insights from the current AI conversation into raw/
- **`sage research wiki`** — gap analysis: which pages are thin? what's missing? what should I add next?

### 3. Answer questions from your own knowledge
Ask sage anything. It searches the wiki, synthesizes an answer from your own pages, and offers to file it back as an **exploration page** — so the answer becomes part of the wiki.

```
what do I know about india-ai-market?
compare bootstrapping vs vc-funding
what are the strongest PMF signals?
```

### 4. Keep itself clean, automatically
Daily automated health checks (no AI needed, runs at 6pm via macOS LaunchAgent):
- Auto-fixes: missing confidence tags, dead wikilinks, pages missing from index
- Flags for review: thin pages needing more sources, orphan pages linked from nowhere, stale sources (>2 years old)
- Sends a macOS notification with results

### 5. Know who you are
sage personalizes to you via a memory layer (`wiki/sage-memory/`):
- **SOUL.md** — your domain interests, depth preference, why you built this wiki
- **USER.md** — your name, role, background, people and projects you track
- **MEMORY.md** — high-signal lessons and decisions; only things that change future sage behavior
- **HEARTBEAT.md** — wiki health snapshot, auto-updated by daily lint

Once seeded, every sage operation reads these files. Summaries are pitched at your level. Tracked entities get auto-linked. Research focuses on your declared interests.

### 6. Capture project knowledge from conversations
In any AI coding session, say `sage capture <project-name>`. sage scans the conversation, shows you a preview of what's worth preserving, and saves synthesized knowledge (not a transcript) to `raw/<project>/`. You can ingest it immediately or defer.

### 7. Work inside any AI tool
sage is not tied to one AI. Install scripts exist for:
Claude Code · Kiro · Gemini CLI (Google Antigravity) · Codex / OpenCode · Cursor · GitHub Copilot · VS Code Copilot Chat

One install script does everything: injects instructions, scaffolds `~/sage/`, installs the MCP server, sets up daily automation. **No manual config.**

---

## The wiki structure

```
~/sage/
├── raw/                    ← drop sources here
│   ├── seed/               ← seeded during init
│   └── <your files>        ← articles, PDFs, screenshots, notes
└── wiki/
    ├── sources/            ← one page per ingested source
    ├── concepts/           ← encyclopedic concept pages
    ├── entities/           ← people, orgs, tools, projects
    ├── comparisons/        ← X vs Y structured tables
    ├── explorations/       ← filed answers to questions asked
    ├── sage-memory/        ← personalization layer (SOUL, USER, MEMORY, HEARTBEAT)
    ├── index.md            ← all pages, one-line TLDR each, with maturity + link counts
    └── _backlinks.json     ← auto-maintained backlink graph
```

---

## Page maturity system

Every concept and entity page carries a maturity level that auto-advances as more sources confirm it:

| Level | Sources | Meaning |
|-------|---------|---------|
| `seed` | 1 | First encounter — single source, may be thin |
| `growing` | 2–3 | Multiple sources, concept taking shape |
| `mature` | 4–6 | Well-sourced, high confidence |
| `established` | 7+ | Deeply sourced, cross-referenced across wiki |

---

## Confidence system

Every key fact carries a confidence tag:
- `[confidence: high]` — explicitly stated in a source
- `[confidence: medium]` — reasonable inference from source
- `[confidence: low]` — speculative, needs more evidence

Contradictions between sources are surfaced in **Open Questions** sections on both pages.

---

## Who it's for

**Founders and researchers** who consume a high volume of information and need it usable — not just searchable.

**Builders** who want their AI agent to have long-term memory of their domain knowledge, not just the current conversation.

**Anyone** who has ever read something important, thought "I should remember this," and then lost it.
