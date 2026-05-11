# Connectors

One-step setup for your AI tool. Default is global — one central wiki at `~/sage/` that works across all projects.

## Quick start

```bash
git clone https://github.com/biaadmin/sage.git ~/sage-repo
bash ~/sage-repo/connectors/kiro/install.sh
```

That's it. Kiro now knows about sage in every project, and your wiki lives at `~/sage/`.

## All integrations

| Tool | Command | Global location |
|------|---------|----------------|
| Kiro | `bash connectors/kiro/install.sh` | `~/.kiro/steering/sage.md` |
| Claude Code | `bash connectors/claude-code/install.sh` | `~/.claude/CLAUDE.md` |
| Antigravity | `bash connectors/antigravity/install.sh` | `~/.gemini/GEMINI.md` |
| Codex | `bash connectors/codex/install.sh` | `~/AGENTS.md` |
| Cursor | `bash connectors/cursor/install.sh` | `~/.cursor/rules/sage.mdc` |
| Copilot | `bash connectors/copilot/install.sh` | `.github/copilot-instructions.md` |
| VS Code | `bash connectors/vscode/install.sh` | `.vscode/settings.json` |

## Two modes

- **Default (global):** `bash install.sh` — installs tool instructions globally + scaffolds central wiki at `~/sage/`. One wiki for everything.

- **Project-local:** `bash install.sh --project` — installs instructions in current project + scaffolds wiki here. For team projects that need their own wiki.

## What the install does

1. Writes a small instruction file for your tool (so it knows sage exists)
2. Scaffolds wiki structure at `~/sage/` (or current dir with `--project`)

The instruction file is minimal (~10 lines) — it tells the agent that sage exists and which skill file to read for each operation. It doesn't interfere with normal coding work.

## Uninstall

Each folder has an `uninstall.sh`. Same `--project` flag applies.
