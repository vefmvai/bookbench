---
description: Removes a book entry from the global registry. The .book/ folder on disk stays untouched. Asks the author to type the book id to confirm — Type-to-Confirm pattern — to avoid accidental loss. Symmetric with /book:register.
argument-hint: "<id-or-path>"
allowed-tools: [Read, Edit, Bash, AskUserQuestion]
---

# /book:forget

<purpose>
Hard-remove a book from the registry. Symmetric to `/book:register`. The disk content remains intact — re-register at any time. Use Type-to-Confirm to prevent accidents.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `<id-or-path>` — registry id or absolute path of the book.
- `${CLAUDE_PLUGIN_DATA}/registry.yaml`.

## Outputs

- `${CLAUDE_PLUGIN_DATA}/registry.yaml` — entry removed in place.

<execution>

Eight-step pattern with extra-strict confirmation: validate → resolve → locate → ask → type-to-confirm → write → verify → next-step.

### Step 1 — Pre-flight

```bash
if [ -z "${ARGUMENTS:-}" ]; then
  echo "Error: /book:forget requires an id or absolute path."
  echo "Usage: /book:forget <id-or-path>"
  echo "Run /book:list to see available ids."
  exit 0
fi

# H1: resolve plugin data
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  PLUGIN_DATA="$CLAUDE_PLUGIN_DATA"
elif [ -n "${LOCALAPPDATA:-}" ]; then
  PLUGIN_DATA="$LOCALAPPDATA/bookbench"
else
  PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"
fi
REGISTRY="$PLUGIN_DATA/registry.yaml"

if [ ! -f "$REGISTRY" ]; then
  echo "Registry is empty. Nothing to forget."
  exit 0
fi
```

### Step 2 — Parse argument and locate

Same locator logic as `/book:archive` Step 2-3:
- If starts with `/` — treat as path; normalise; find entry by `path`.
- Else — treat as id; find entry by `id`.

If no match:

```
Error: no registry entry matches '<TARGET>'.
Run /book:list to see available ids.
```

```bash
TARGET="$ARGUMENTS"
LOOKUP_KEY="id"
LOOKUP_VAL="$TARGET"
if [[ "$TARGET" == /* ]]; then
  LOOKUP_KEY="path"
  LOOKUP_VAL="$(cd "$TARGET" 2>/dev/null && pwd -P || echo "$TARGET")"
fi

# Find matching id (similar awk to archive.md)
MATCH_ID=$(awk -v key="$LOOKUP_KEY" -v val="$LOOKUP_VAL" '
  /^  - id:/  { rec_id=substr($0,index($0,":")+2); sub(/^[ ]+|[ ]+$/, "", rec_id) }
  /^    path:/{ rec_path=substr($0,index($0,":")+2); sub(/^[ ]+|[ ]+$/, "", rec_path) }
  /^    title:/{rec_title=substr($0,index($0,":")+2); sub(/^[ ]+|[ ]+$/, "", rec_title)
                if ((key=="id" && rec_id==val) || (key=="path" && rec_path==val)) {
                  print rec_id; exit
                }
              }
' "$REGISTRY")

if [ -z "$MATCH_ID" ]; then
  echo "Error: no registry entry matches '$TARGET'."
  exit 0
fi
```

### Step 3 — First confirmation gate

Present an `AskUserQuestion`:

- Title: «Forget this book from the registry?»
- Body:
  - `id:    <MATCH_ID>`
  - Note: «The .book/ folder on disk will NOT be deleted. Only the registry entry is removed.»
  - «To recover later, run `/book:register <path>`.»
  - «To soft-hide instead of hard-remove, prefer `/book:archive`.»
- Options:
  - `Continue (will ask for type-to-confirm next)` — proceed.
  - `Cancel` — exit.

### Step 4 — Type-to-Confirm gate

Show a second `AskUserQuestion`:

- Title: «Type the book id to confirm forget»
- Body: «Type exactly: `<MATCH_ID>` (any other value cancels).»
- Options: free-text input.

Compare verbatim. If the typed text does not equal `<MATCH_ID>`:

```
Type-to-confirm failed. The forget was cancelled.
```

Exit. The Type-to-Confirm pattern is taken from Part VII of the methodology guide.

### Step 5 — Remove the entry from the registry

Use awk to drop the contiguous block of lines starting at `  - id: <MATCH_ID>` and ending just before the next `  - id:` line (or EOF).

```bash
awk -v id="$MATCH_ID" '
  BEGIN { skip=0 }
  /^  - id:/ {
    cur_id=substr($0,index($0,":")+2); sub(/^[ ]+|[ ]+$/, "", cur_id)
    skip = (cur_id == id) ? 1 : 0
    if (!skip) print
    next
  }
  /^  - / && skip { skip=0 }   # safety: any other top-level dash ends the skip
  { if (!skip) print }
' "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
```

### Step 6 — Verify

Confirm the id no longer appears in the registry:

```bash
if grep -F "  - id: $MATCH_ID" "$REGISTRY" >/dev/null 2>&1; then
  echo "Warning: forget did not commit. The entry still exists in $REGISTRY."
else
  echo "Forgotten: $MATCH_ID"
fi
```

### Step 7 — No state mutation in `.book/`

This command does not write to the book's `.book/STATE.md` because the operation is purely on the global registry.

### Step 8 — Next-step message

```
Forgotten: $MATCH_ID
  files on disk at <path>: untouched

Recommended next:
  /book:list             — confirm the book is no longer listed.
  /book:register <path>  — re-add later if needed.
```

### Constitutional rules

- **MUST** require Type-to-Confirm — typing the exact id is mandatory.
- **MUST** be idempotent at the disk-content level — the `.book/` folder is never touched.
- **MUST** verify the removal actually committed before claiming success.
- **NEVER** invoke this destructively from automation — Type-to-Confirm is an explicit human gate.
- **NEVER** read inside the book's sections / inputs / agent-memory — pure registry operation.

</execution>
