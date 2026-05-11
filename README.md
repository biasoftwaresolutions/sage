<div align="center">
  <img src="assets/sage-icon2.png" alt="sage" width="300" />

  # sage

  A personal knowledge wiki maintained by AI. Drop sources in, get a structured, cross-referenced wiki out. Knowledge compounds — every source makes the wiki richer, every question gets filed back.

  Implements the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) with a production-ready local server, agent-optimized search API, interactive graph visualization, and daily automated maintenance.

</div>

> **Product vision, value proposition, and design brief:** [docs/value-proposition.md](docs/value-proposition.md)

---

## How it works

1. **Drop** sources (articles, papers, notes, images, PDFs) into `sources/`
2. **Ingest** — your AI agent reads the source and compiles structured wiki pages
3. **Query** — ask questions, get synthesized answers from your own knowledge
4. **Lint** — daily automated health checks keep the wiki clean without you thinking about it

You never write the wiki. The AI writes and maintains all of it. You curate sources and ask questions.

---

## Memory layer

sage personalises itself to you via four files in `wiki/sage-memory/`:

| File | What it stores |
|------|---------------|
| `SOUL.md` | Why you built this wiki, your domain interests, depth preference |
| `USER.md` | Your name, role, background, people and projects you track |
| `MEMORY.md` | High-signal decisions and lessons — only things that change future behavior |
| `HEARTBEAT.md` | Wiki health snapshot, auto-updated by `sage lint` |

Edit these files any time. `sage init` creates them; every skill reads them.

**`sage remember <thing>`** — explicitly add a lesson to MEMORY.md. sage also proactively pitches entries during research when something clears the bar.

---

## Quickstart

**1. Clone**

```bash
git clone https://github.com/biaadmin/sage.git
cd sage
```

**2. Install for your AI tool**

```bash
bash connectors/claude/install.sh         # Claude Code + Claude Desktop
bash connectors/kiro/install.sh           # Kiro
bash connectors/antigravity/install.sh    # Google Antigravity (Gemini CLI)
bash connectors/codex/install.sh          # Codex / OpenCode
bash connectors/cursor/install.sh         # Cursor
bash connectors/copilot/install.sh        # GitHub Copilot
bash connectors/vscode/install.sh         # VS Code (Copilot Chat)
```

Each install script does everything in one shot:
- Injects sage instructions into your AI tool's config
- Scaffolds a central wiki at `~/sage/` (wiki/, sources/, scripts/, skills/)
- Copies `scripts/sage-operations.py` → `~/sage/scripts/sage-operations.py` (the deterministic ops tool)
- Copies skill files → `~/sage/skills/`
- Installs the `sage-mcp` MCP server and registers it
- **(macOS)** Installs a daily maintenance LaunchAgent — automated lint at 6:00pm, no AI required
- **(Claude)** Installs `/sage-init`, `/sage-ingest`, `/sage-lint`, `/sage-research`, `/sage-capture`, `/sage-meeting` slash commands; auto-configures both Claude Code and Claude Desktop — skips whichever isn't installed

For project-specific wikis (wiki lives alongside the code), add `--project`:
```bash
bash connectors/claude/install.sh --project
```

**Updating:** re-run `install.sh` after `git pull`. It copies the latest `sage-operations.py` and skills — never touches your wiki data (`wiki/`, `sources/`, `sage-memory/`).

**3. Run the onboarding wizard**

```bash
sage init   # or type: /sage-init in Claude Code
```

Asks 6 questions about you and your goals, then:
- Creates `wiki/sage-memory/` with SOUL.md, USER.md, MEMORY.md, and HEARTBEAT.md
- Fetches seed articles from the web for each topic you declare
- Ingests everything so your wiki has real pages immediately

**4. Add your own sources**

```bash
# Drop any file into the sources/ folder
cp ~/Downloads/some-article.md ~/sage/sources/
```

**5. Ingest it**

*In Claude Code:* type `sage ingest` or `/sage-ingest`

*In any other AI tool:* type `sage ingest`

The agent reads the source, creates structured wiki pages, cross-references concepts, and updates the index.

---

## Commands

| What to say | What happens |
|---|---|
| `sage init` | Onboarding wizard — creates memory layer and seeds wiki with web content |
| `sage ingest` | Process new files from `sources/` into wiki pages |
| `sage lint` | Health check + auto-fix deterministic issues |
| `sage research <topic\|chat\|wiki>` | Find sources on the web, capture a chat, or analyze wiki gaps |
| `sage query <topic>` | Search the wiki; optionally file the answer back |
| `sage capture <project>` | Capture current conversation knowledge into `sources/<project>/` |
| `sage remember <thing>` | Append a high-signal lesson directly to `wiki/sage-memory/MEMORY.md` |
| `sage relocate <path>` | Move sage wiki root to a new directory (updates `~/.config/sage/config.json`) |
| `sage meeting` | Capture meeting notes, extract action items, manage lifecycle |
| `sage memory <propose\|inbox\|archive\|restore\|forget\|explain>` | Memory lifecycle — propose entries from sources, review inbox, archive/restore/forget/explain |

> **Claude Code slash commands:** `/sage-init`, `/sage-ingest`, `/sage-lint`, `/sage-research`, `/sage-capture`, `/sage-meeting`, `/sage-memory` — same behavior, shorter to type.

### Ingest

Supported source types:
- Markdown, text, transcripts
- Images (screenshots, diagrams, whiteboards) — AI uses vision to extract content
- PDFs (paste content as `.md` if your agent can't read PDFs directly)

The agent creates a source page in `wiki/sources/`, then creates or updates concept, entity, and comparison pages as needed.

During ingest, the agent scans for durable personal context — your role, active projects, key relationships — and selectively updates `wiki/sage-memory/USER.md` and `SOUL.md` (high bar: only unambiguous, non-transient facts; merges into existing lines rather than appending). Name is never inferred or stored automatically. High-signal decisions or lessons are pitched for `MEMORY.md` before writing.

### Query

```
what is X?
what do I know about Y?
compare X and Y
```

The agent searches the wiki, synthesizes an answer from your pages, and offers to file it back as an exploration page.

### Lint

```
sage lint       # any AI tool
/sage-lint      # Claude Code shorthand
```

Checks run automatically, but you can trigger manually at any time. Two categories:

**Auto-fixed** (no judgment needed, no AI required):
- Missing `[confidence: medium]` tags on Key Facts
- Pages missing from `index.md`
- Dead wikilinks with no matching page

**Flagged for review** (reported, not touched):
- Thin pages (1 source) — need more raw material
- Orphan pages — linked from nowhere
- Bloated pages (>100 lines) — may need splitting
- Stale sources (published >2 years ago)

### Capture

Save knowledge from the current conversation into a project-scoped folder:

```
sage capture my-project
sage capture sage
sage capture work/client-name
```

The agent scans the conversation, shows you a preview of what will be captured, and saves to `sources/<project>/YYYY-MM-DD-<topic>.md`. You can ingest immediately or defer. Works from any AI tool (Claude, Kiro, Copilot, etc.) — just say `sage capture <project>`.

---

### Research

Find new sources to add to the wiki:

```
research X              # web search for X, pick sources to save to sources/
research chat           # capture insights from current conversation into sources/
research wiki           # gap analysis — what should I add next?
```

---

## Daily Automation (macOS)

The install script sets up a macOS LaunchAgent that runs every evening without any AI involvement.

**What it does:**
1. Runs `scripts/sage-operations.py lint --fix` — deterministic fixes applied automatically
2. Checks for new unprocessed files in `sources/`
3. Sends a macOS notification with results

**Notification examples:**
- `"2 auto-fixed | 6 flagged: 6x thin | No new files"`
- `"Wiki is clean | 1 new file ready — say 'sage ingest' to process"`

**If your Mac was off at the scheduled time,** you'll get a dialog with three options when it wakes up:

| Option | What happens |
|--------|-------------|
| **Run Now** | Runs immediately |
| **Postpone 2h** | Runs 2 hours from now in the background |
| **Skip Today** | Skips — runs again tomorrow at the scheduled time |

### Configure the time

Default is 6:00pm. To change:

```bash
# Change to 9pm
bash scripts/install-launchagent.sh ~/sage --time 21:00

# Change to 8:30am
bash scripts/install-launchagent.sh ~/sage --time 08:30
```

Re-running `install-launchagent.sh` is idempotent — safe to run any time.

### Manual control

```bash
# Run maintenance right now
SAGE_ROOT=~/sage bash scripts/daily-maintenance.sh

# Check the log
cat /tmp/sage-maintenance.log

# Uninstall
bash scripts/install-launchagent.sh --uninstall
```

---

## Viewing the wiki

**Obsidian:** open `wiki/` as a vault. Wikilinks, graph view, and tags work natively.

**Web browser:**

```bash
python wiki_server.py
# → http://localhost:3000
```

Features:
- Full-text search with highlighting (`/` to focus)
- Interactive knowledge graph at `/graph` — force-directed, click to navigate
- Dark mode, keyboard navigation (`j`/`k` to move, `Escape` to blur)

---

## MCP Server

sage is on the [MCP Registry](https://registry.modelcontextprotocol.io/?q=io.github.gowtham0992%2Fsage) as `io.github.gowtham0992/sage`.

```bash
pip install sage-mcp
```

Add to your MCP client config:

```json
{
  "mcpServers": {
    "sage": {
      "command": "python3",
      "args": ["-m", "sage_mcp", "--wiki", "~/sage/wiki"]
    }
  }
}
```

The install scripts register this automatically. Install `sage-mcp` standalone if you already have a wiki and just want the MCP server.

**Available tools:**

| Tool | Description |
|------|-------------|
| `get_context` | **Primary tool.** Full page + graph neighborhood in one call. |
| `search_wiki` | Ranked search — title, alias, tag, fulltext. Returns scores + snippets. |
| `get_pages` | List all pages. Filter by category, type, maturity. |
| `get_backlinks` | Inbound + forward links for a page. |
| `get_graph` | All nodes + edges for graph reasoning. |
| `rebuild_knowledge_graph` | Rebuild `_knowledge-graph.json` after ingest or lint. |

---

## HTTP API

`wiki_server.py` also exposes a local HTTP API at `http://localhost:3000`.

> **Local use only.** Binds to `127.0.0.1`. No auth. Do not expose to the internet.

| Endpoint | Description |
|----------|-------------|
| `GET /api/context?topic=X` | **Primary.** Best matching page + inbound/forward graph links |
| `GET /api/search?q=X` | Ranked search — title (20pts), alias (8pts), tag (5pts), fulltext (2pts) |
| `GET /api/pages` | All pages with metadata |
| `GET /api/graph` | All nodes + edges |
| `GET /api/backlinks` | Reverse + forward link index |
| `GET /api/rebuild-knowledge-graph` | Rebuild `_knowledge-graph.json` |

Search is O(1) via in-memory inverted token index — sub-millisecond at any wiki size.

---

## Structure

After install, your wiki lives at `~/sage/` (or project dir with `--project`):

```
~/sage/
├── sources/                       ← your source documents (immutable, you add these)
├── wiki/                      ← compiled knowledge (AI-maintained, never edit manually)
│   ├── index.md               ← master catalog by category
│   ├── _knowledge-graph.json        ← reverse + forward link index (auto-generated)
│   ├── log.md                 ← append-only operation history
│   ├── sources/               ← one page per ingested source
│   ├── concepts/              ← topic articles
│   ├── entities/              ← people, orgs, projects, tools
│   ├── comparisons/           ← side-by-side analyses
│   ├── explorations/          ← filed query results
│   ├── meetings/              ← one page per captured meeting
│   ├── action-items/          ← open.md and closed.md lifecycle tracking
│   └── sage-memory/           ← identity and memory files (created by sage init)
├── skills/                    ← AI agent instructions (loaded on demand)
│   ├── sage-init.md
│   ├── sage-ingest.md
│   ├── sage-lint.md
│   ├── sage-research.md
│   └── sage-capture.md
├── scripts/
│   ├── sage-operations.py                 ← deterministic wiki ops (lint, discover, rebuild-knowledge-graph)
│   ├── daily-maintenance.sh   ← runs by LaunchAgent
│   ├── install-launchagent.sh ← macOS daily automation setup
│   └── install-skills.sh      ← Claude Code skills installer
└── wiki_server.py             ← local web viewer + HTTP API
```

### Page schema

Every wiki page uses YAML frontmatter:

| Field | Values | Description |
|-------|--------|-------------|
| `type` | `source \| concept \| entity \| comparison \| exploration` | Page type |
| `maturity` | `seed \| growing \| mature \| established` | seed=1 src, growing=2–3, mature=4–6, established=7+ |
| `source_count` | integer | Sources this page draws from |
| `aliases` | list | Alternate names / abbreviations |
| `tags` | list | Topic tags |
| `date_created` / `date_updated` | ISO date | Lifecycle timestamps |

Pages use `[[wikilink]]` syntax (Obsidian-compatible) and inline confidence tags: `[confidence: high]`, `[confidence: medium]`, `[confidence: low]`.

---

## Data vs. code

The sage **codebase** (scripts, skills, integrations) and your **wiki data** (wiki/, sources/) are kept separate:

| Location | What lives here |
|----------|----------------|
| This repo | Scripts, skills, integrations, docs — no user data |
| `~/sage/` (default) | Your wiki — wiki/, sources/, sage-memory/ |

To move your wiki anywhere: `sage relocate ~/Documents/my-wiki`

Root resolution order (highest priority first):
1. `SAGE_ROOT` env var
2. `~/.config/sage/config.json` → `"root"` key (set by `sage relocate`)
3. `~/sage/` (default install location)
4. sage-operations.py parent directory (dev mode fallback)

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SAGE_ROOT` | `~/sage` | Path to sage root. Overrides config file. |
| `SAGE_LINT_HOUR` | `18` | Hour for daily maintenance (0–23). Set via `--time` flag. |
| `SAGE_LINT_MIN` | `0` | Minute for daily maintenance (0–59). Set via `--time` flag. |

---

## Design principles

- **Every claim links to its source.** No orphan claims. Confidence tags on every fact: `[confidence: high/medium/low]`.
- **Audit trail built-in.** `log.md` is append-only — every ingest, query, and lint is recorded.
- **Pages mature over time.** seed → growing → mature → established. Richer, not just bigger.
- **No LLM for deterministic work.** `scripts/sage-operations.py` runs lint and discovery without any AI — faster, cheaper, always consistent.
- **Agent-optimized search.** `/api/context` returns a page + its full graph neighborhood in one call. No re-deriving context every session.
- **No external dependencies.** Pure Python stdlib for `wiki_server.py` and `sage-operations.py`. No vector databases, no embedding APIs, no npm.
- **Just markdown in a git repo.** Version history, branching, and collaboration come free.

---

## Privacy

- No telemetry, no hosted backend, no external API calls from any sage component.
- Raw sources and wiki pages are git-ignored by default.
- Registry tokens (`.mcpregistry_*`, `*.token`) are ignored and excluded from PyPI packages.
