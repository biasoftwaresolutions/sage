## Rules

- Whenever any code, config, or behavior changes in this codebase, update README.md and any relevant docs in the same commit.
- All user-facing commands follow the `sage <verb>` pattern: `sage ingest`, `sage lint`, `sage research`, `sage query`, `sage capture`. Never introduce bare verbs (e.g. just `ingest`) or inconsistent prefixes. Claude Code slash equivalents: `/sage-ingest`, `/sage-lint`, `/sage-research`, `/sage-capture`.
- The single source of truth for command definitions is `connectors/_shared/sage-instructions.md`. When adding a new command: (1) create the skill file in `skills/`, (2) add the trigger row to `sage-instructions.md` (project mode generated automatically via sed), (3) add the skill to `scripts/install-skills.sh`, (4) update `~/.claude/CLAUDE.md` global table, (5) update README.
