# Sage Security Policy (shared)

## What gets committed

`raw/` and `wiki/` are **intentionally tracked in git**. This is by design —
version history for the knowledge base is a feature. Skills that write to these
directories should assume their output may be pushed to a remote.

## What must never be committed

| Pattern | Reason |
|---------|--------|
| `.mcpregistry_*` | Local registry state, machine-specific |
| `*.token` | Auth/API tokens |
| `mcp_package/dist/` | Build artifacts |

All three are listed in `.gitignore`.

## Server exposure

`wiki_server.py` binds to `127.0.0.1` only, no auth. Skills must not suggest
binding to `0.0.0.0` or exposing the server to external networks.

## Sensitive content in raw sources

If a user's raw sources contain credentials, private notes, or PII, that is
their responsibility to filter before committing. Skills should remind users
to review `git diff` before pushing if writing to `raw/`.
