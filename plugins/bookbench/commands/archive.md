---
description: Archives a registered book in the global registry — sets status from active to archived, fixes archived_at timestamp, hides it from default /book:list. Does not touch the .book/ folder on disk; reversible by editing registry.yaml or running /book:register again.
argument-hint: "[<id-or-path>]"
allowed-tools: [Read, Edit, Bash, AskUserQuestion]
---

# /book:archive

<purpose>
Soft-hide a finished or paused book from active listings without losing the registry entry. Symmetric with `/book:register` (which sets `status: active`).
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `<id-or-path>` (positional, optional): registry id like `my-book-2026-05-06` OR an absolute path. Defaults to current `$PWD` if both make sense.
- `${CLAUDE_PLUGIN_DATA}/registry.yaml`.

## Outputs

- `${CLAUDE_PLUGIN_DATA}/registry.yaml` updated: matching entry has `status: archived` and `archived_at: <ISO 8601>`.

<execution>

Eight-step pattern: validate → resolve paths → locate target → confirm → write registry → verify → state mutation → next-step.

### Step 1 — Pre-flight

```bash
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
  echo "Registry is empty. Nothing to archive."
  exit 0
fi
```

### Step 2 — Parse argument

`$ARGUMENTS` may be:
- A registry id (matches `^[a-z0-9-]+$`).
- An absolute path (starts with `/`).
- Empty — fall back to `$PWD` (treat as path).

```bash
TARGET="${ARGUMENTS:-$PWD}"
LOOKUP_KEY=""
LOOKUP_VAL=""

if [[ "$TARGET" == /* ]]; then
  LOOKUP_KEY="path"
  LOOKUP_VAL="$(cd "$TARGET" 2>/dev/null && pwd -P || echo "$TARGET")"
else
  LOOKUP_KEY="id"
  LOOKUP_VAL="$TARGET"
fi
```

### Step 3 — Locate target entry

Find the matching record by either `id` or `path`. If not found:

```
Error: no registry entry matches '<TARGET>'.
Run /book:list to see available ids.
```

If multiple matches by path (should not happen for normalised paths but defensively check) — print:

```
Error: multiple entries match path '<TARGET>'. Run /book:doctor to clean up.
```

```bash
MATCH_ID=""
MATCH_TITLE=""
MATCH_STATUS=""
awk -v key="$LOOKUP_KEY" -v val="$LOOKUP_VAL" '
  /^  - id:/        { rec_id=substr($0,index($0,":")+2); rec_title=""; rec_path=""; rec_status=""; sub(/^[ ]+|[ ]+$/, "", rec_id) }
  /^    title:/     { rec_title=substr($0,index($0,":")+2); sub(/^[ ]+|[ ]+$/, "", rec_title) }
  /^    path:/      { rec_path=substr($0,index($0,":")+2); sub(/^[ ]+|[ ]+$/, "", rec_path) }
  /^    status:/    { rec_status=substr($0,index($0,":")+2); sub(/^[ ]+|[ ]+$/, "", rec_status) ;
                      if ((key=="id" && rec_id==val) || (key=="path" && rec_path==val)) {
                        printf("%s\t%s\t%s\n", rec_id, rec_title, rec_status); exit
                      }
                    }
' "$REGISTRY" > /tmp/bookbench-archive-match.txt

MATCH_ID=$(awk -F'\t' '{print $1; exit}' /tmp/bookbench-archive-match.txt)
MATCH_TITLE=$(awk -F'\t' '{print $2; exit}' /tmp/bookbench-archive-match.txt)
MATCH_STATUS=$(awk -F'\t' '{print $3; exit}' /tmp/bookbench-archive-match.txt)

if [ -z "$MATCH_ID" ]; then
  echo "Error: no registry entry matches '$LOOKUP_VAL'."
  exit 0
fi

if [ "$MATCH_STATUS" = "archived" ]; then
  echo "Book '$MATCH_ID' is already archived."
  exit 0
fi
```

### Step 4 — Confirmation gate

Present an `AskUserQuestion`:

- Title: «Archive book?»
- Body:
  - `id:     <MATCH_ID>`
  - `title:  <MATCH_TITLE>`
  - `status: active → archived`
  - Note: «files on disk are not touched; only the registry entry changes.»
- Options:
  - `Archive` — proceed.
  - `Cancel` — exit.

### Step 5 — Update registry

For the matching record, change `status: active` → `status: archived` and append `archived_at: <ISO>`. Use awk to keep the file readable.

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
awk -v id="$MATCH_ID" -v ts="$NOW" '
  /^  - id:/ { cur_id=substr($0,index($0,":")+2); sub(/^[ ]+|[ ]+$/, "", cur_id); in_match = (cur_id == id) }
  in_match && /^    status:/ { sub(/status: .*/, "status: archived"); print; next }
  /^    bookbench_version:/ && in_match { print; print "    archived_at: " ts; next }
  { print }
' "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
```

If the `archived_at:` line already exists for some reason, do not duplicate it — defensively check with grep before the awk runs and use the matching branch only when needed.

### Step 6 — Verify

Re-read the registry; confirm the entry now has `status: archived`. If the change did not take effect, print:

```
Warning: archive update did not commit. Inspect $REGISTRY by hand.
```

### Step 7 — State (no STATE.md change here)

This command does not write to any `.book/STATE.md` because it only touches the global registry. Stage 14 deliberately keeps registry-changes out of book-local logs.

### Step 8 — Next-step message

```
Archived: $MATCH_ID
  files on disk: untouched at <path>

Recommended next:
  /book:list                 — confirm it no longer shows in default listing.
  /book:list --archived      — see all archived books.
  /book:register <path>      — re-register if you want to resume work later.
```

### Constitutional rules

- **MUST** check the entry exists and is currently active. No-op if already archived.
- **MUST** ask the author to confirm (Brief-Then-Execute, Part VII methodology).
- **MUST** preserve the original entry — only flip `status` and append `archived_at`.
- **NEVER** delete the registry entry (that is `/book:forget`).
- **NEVER** touch any file inside the book's `.book/` directory.

</execution>
