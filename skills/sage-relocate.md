# sage relocate

Move the entire sage root (wiki, raw, scripts, skills, everything) to a new directory.

---

## Usage

The user will say something like:
- `sage relocate ~/Documents/my-wiki`
- `sage relocate /Volumes/ExternalDrive/sage`
- `/sage-relocate ~/new-path`

Extract the target path from the user's message.

---

## Step 1 — resolve current root

```bash
python3 ~/sage/scripts/sage-operations.py status
```

Note the current `sage_root` from the output.

---

## Step 2 — run relocate

```bash
python3 ~/sage/scripts/sage-operations.py relocate <target-path>
```

**Failure cases:**
- `"Target is already the current sage root."` → tell user nothing to do
- `"Target directory exists and is not empty"` → tell user to choose an empty or non-existent path
- `"Move failed: ..."` → report the error verbatim, suggest checking permissions

---

## Step 3 — confirm

On success, report:

```
✓ sage moved
  From: <old path>
  To:   <new path>

Config updated: ~/.config/sage/config.json

Note: ops.py is now at <new path>/scripts/sage-operations.py
```

If the user is in Claude Code, add:
> The `/sage-*` slash commands still work — they always resolve through the config file.
