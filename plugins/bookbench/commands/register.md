---
description: Registers an existing .book/ folder in the global registry. Reads .book/PROJECT.md and .book/config.yaml to derive id, title, genre, then upserts into ${CLAUDE_PLUGIN_DATA}/registry.yaml. Without arguments uses the current working directory. Idempotent on path — running twice updates last_touched but does not duplicate.
argument-hint: "[<path>]"
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

# /bookbench:register

<purpose>
Pull a found-on-disk book into the registry without re-running `/bookbench:start`. Useful after `git clone`, after migrating from another machine, or after creating a `.book/` folder manually.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `<path>` (positional, optional): path to the book root (with `.book/` inside). Defaults to `$PWD`.
- `<path>/.book/config.yaml` (read).
- `<path>/.book/PROJECT.md` (read, optional — for title fallback).

## Outputs

- New (or updated) entry in `${CLAUDE_PLUGIN_DATA}/registry.yaml`.

<execution>

Eight-step pattern: validate → resolve paths → read book metadata → confirm with user → write registry → verify → state mutation → next-step.

### Step 1 — Pre-flight

```bash
BOOK_PATH="${ARGUMENTS:-$PWD}"
# Normalise to absolute path
BOOK_PATH="$(cd "$BOOK_PATH" 2>/dev/null && pwd -P || echo "$BOOK_PATH")"

if [ ! -d "$BOOK_PATH/.book" ]; then
  echo "Error: '$BOOK_PATH' does not contain a .book/ folder."
  echo "Run /bookbench:start to initialise a new book."
  exit 0
fi

if [ ! -f "$BOOK_PATH/.book/config.yaml" ]; then
  echo "Error: '$BOOK_PATH/.book/config.yaml' is missing."
  echo "This may not be a valid BookBench book. Run /bookbench:doctor for diagnostics."
  exit 0
fi
```

### Step 2 — Resolve plugin data path (H1)

```bash
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  PLUGIN_DATA="$CLAUDE_PLUGIN_DATA"
elif [ -n "${LOCALAPPDATA:-}" ]; then
  PLUGIN_DATA="$LOCALAPPDATA/bookbench"
else
  PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"
fi
mkdir -p "$PLUGIN_DATA"
REGISTRY="$PLUGIN_DATA/registry.yaml"
```

### Step 3 — Extract metadata from the book

```bash
# title from PROJECT.md or config.yaml (best-effort)
TITLE=""
if [ -f "$BOOK_PATH/.book/PROJECT.md" ]; then
  TITLE=$(awk '/^# /{sub(/^# /, ""); print; exit}' "$BOOK_PATH/.book/PROJECT.md" || true)
fi
if [ -z "$TITLE" ]; then
  TITLE=$(awk -F: '/^title:/ {gsub(/^[ "]+|[" ]+$/, "", $2); print $2; exit}' "$BOOK_PATH/.book/config.yaml" || true)
fi
[ -z "$TITLE" ] && TITLE="$(basename "$BOOK_PATH")"

GENRE=$(awk -F: '/^genre:/ {gsub(/^[ "]+|[" ]+$/, "", $2); print $2; exit}' "$BOOK_PATH/.book/config.yaml" || true)
[ -z "$GENRE" ] && GENRE="unknown"

LANG=$(awk -F: '/^language:/ {gsub(/^[ "]+|[" ]+$/, "", $2); print $2; exit}' "$BOOK_PATH/.book/config.yaml" || true)
[ -z "$LANG" ] && LANG="en"

BB_VERSION=$(awk -F: '/^bookbench_version:/ {gsub(/^[ "]+|[" ]+$/, "", $2); print $2; exit}' "$BOOK_PATH/.book/config.yaml" || true)
[ -z "$BB_VERSION" ] && BB_VERSION="unknown"
```

### Step 4 — Generate id (slug + date)

```bash
slugify() {
  printf '%s' "$1" \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}
SLUG=$(slugify "$TITLE")
[ -z "$SLUG" ] && SLUG="book"
ID="${SLUG}-$(date -u +%Y-%m-%d)"
```

### Step 5 — Idempotency check

If `registry.yaml` already contains an entry with `path: $BOOK_PATH`, do not duplicate. Update `last_touched` field instead and emit:

```
Book is already registered as <existing-id>.
Updated last_touched. No new entry created.
```

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ -f "$REGISTRY" ] && grep -F "  path: $BOOK_PATH" "$REGISTRY" >/dev/null 2>&1; then
  EXISTING_ID=$(awk -v p="$BOOK_PATH" '
    /^  - id:/ {cur_id=$3}
    /^    path:/ {if(substr($0,index($0,":")+2) ~ p) {print cur_id; exit}}
  ' "$REGISTRY")
  awk -v p="$BOOK_PATH" -v ts="$NOW" '
    BEGIN{found=0}
    {
      print
      if ($0 ~ ("  path: " p)) found=1
      if (found && $0 ~ /^    last_touched: /) { sub(/last_touched: .*/, "last_touched: " ts); found=0 }
    }
  ' "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
  echo "Book is already registered as $EXISTING_ID. Updated last_touched."
  exit 0
fi
```

### Step 6 — Confirmation gate

Before writing the new entry, present an `AskUserQuestion`:

- Title: «Register this book?»
- Body:
  - `Title: <TITLE>`
  - `Genre: <GENRE>`
  - `Path:  <BOOK_PATH>`
  - `Generated id: <ID>`
- Options:
  - `Confirm` — proceed.
  - `Edit title first` — prompt for a new title; recompute slug and id; ask again.
  - `Cancel` — exit.

### Step 7 — Append to registry (H4)

```bash
# Initialise file if absent
if [ ! -f "$REGISTRY" ]; then
  printf 'books:\n' > "$REGISTRY"
fi

cat >> "$REGISTRY" <<YAML
  - id: $ID
    title: $TITLE
    path: $BOOK_PATH
    genre: $GENRE
    language: $LANG
    created: $NOW
    last_touched: $NOW
    bookbench_version: $BB_VERSION
    status: active
YAML
```

Verify by re-reading `$REGISTRY` and confirming the new id appears.

### Step 8 — Next-step message

```
Registered: $ID
  path: $BOOK_PATH
  genre: $GENRE

Recommended next:
  /bookbench:list             — verify the new entry shows.
  /bookbench:status           — overview of this book (run from the book directory).
  /bookbench:doctor           — verify there are no consistency issues.
```

### Constitutional rules

- **MUST** check `.book/config.yaml` exists before recording — refuse to register a non-book directory.
- **MUST** be idempotent on `path` — running twice in the same directory is a no-op except for `last_touched`.
- **MUST** ask the author before writing (Brief-Then-Execute pattern, Part VII methodology).
- **NEVER** create or modify any file inside `<path>/.book/` — only the global registry.
- **NEVER** read section content. Only frontmatter / metadata files.

</execution>
