---
name: sage-capture
description: Capture current conversation knowledge into sage sources/ under a named project folder. Triggers on "sage capture", "/sage-capture".
---

## Memory context

If `~/sage/wiki/sage-memory/` exists, read these files before capturing:
- `SOUL.md` — domain focus: use to filter what from the conversation is worth capturing
- `USER.md` — background: calibrate detail level in captured pages
- `MEMORY.md` — past decisions: if the conversation revisits a settled conclusion, note the memory entry rather than creating a duplicate page

---

# sage capture

Capture knowledge from the current conversation into `~/sage/sources/<project>/`.

---

## Steps

1. **Get project name**
   - If user provided it (`sage capture <project>`), use it as-is, lowercased, spaces → hyphens
   - If not provided, infer from: current working directory name, dominant topic in conversation, or ask the user

2. **Scan conversation**
   - Review full conversation for substantive knowledge: decisions made, patterns discovered, architecture choices, debugging insights, how-to knowledge, gotchas
   - Skip: small fixes, typo corrections, trivial back-and-forth, anything already documented in the codebase

3. **Show preview**
   Present a bullet-point summary of what will be captured. Wait for user confirmation before saving.

   If nothing worth capturing: say so. Don't create empty/thin files.

4. **Save file**

   Path: `~/sage/sources/<project>/<YYYY-MM-DD>-<slug>.md`

   Where `<slug>` is a 3-5 word kebab-case summary of the topic (e.g. `auth-middleware-token-expiry`).

   ```markdown
   ---
   title: "<descriptive title>"
   source_type: conversation
   project: "<project>"
   date_captured: "<YYYY-MM-DD>"
   participants: human + AI
   ---

   <synthesized knowledge — NOT a raw transcript>
   <extract the insight, decision, or pattern — not the back-and-forth>
   <use headers to organize if multiple distinct topics>
   ```

5. **Offer to ingest**

   Ask: "Ingest now or save for later?"
   - **Now** → immediately run ingest skill on this file
   - **Later** → tell user: "Saved to `sources/<project>/<filename>`. Run `ingest` when ready."

6. **Log**

   Append to `~/sage/wiki/log.md`:
   ```
   ## [<ISO timestamp>] capture | <project>: "<title>"

   - File: sources/<project>/<filename>
   - Ingested: yes/no

   ---
   ```

---

## Rules

- Project folder is created automatically if it doesn't exist
- One file per conversation topic — don't merge unrelated things into one file
- Synthesize knowledge, never dump raw transcript
- If conversation spans multiple distinct topics, offer to split into separate files
- Never capture without user seeing the preview first
