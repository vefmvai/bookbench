---
description: Lists all books in the global registry. Without flags shows only active books. --all includes archived; --archived shows only archived; --genre filters by genre name. Reads ${CLAUDE_PLUGIN_DATA}/registry.yaml. Read-only.
argument-hint: "[--all] [--archived] [--genre <name>] [--status active|completed|archived]"
allowed-tools: [Read, Bash, Glob]
---

# /bookbench:list

<purpose>
Multi-book overview for authors who run several projects in parallel. Read-only summary listing of every book registered with the BookBench plugin.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `${CLAUDE_PLUGIN_DATA}/registry.yaml` — list of registered books.
- `${CLAUDE_PLUGIN_DATA}/installation.yaml` — used only to confirm the plugin data path is set up.

## Outputs

- Formatted listing on stdout: `id | title | genre | status | last_touched | path`.
- Optional summary line: `N active, M archived` (always shown).

<execution>

Read-only command. Pure listing — no AskUserQuestion, no state mutation.
Six steps: validate → resolve paths → read registry → parse args → render table → next-step.

### Step 1 — Pre-flight

```bash
# resolve_plugin_data_path (helper H1 from bookbench/lib/plugin-data-helpers.md)
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  PLUGIN_DATA="$CLAUDE_PLUGIN_DATA"
elif [ -n "${LOCALAPPDATA:-}" ]; then
  PLUGIN_DATA="$LOCALAPPDATA/bookbench"
else
  PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"
fi
REGISTRY="$PLUGIN_DATA/registry.yaml"

if [ ! -f "$REGISTRY" ]; then
  echo "Registry is empty (no books registered yet)."
  echo ""
  echo "Recommended next:"
  echo "  /bookbench:start            — initialise your first book."
  echo "  /bookbench:register <path>  — register an existing .book/ folder."
  exit 0
fi
```

### Step 2 — Parse arguments

Parse `$ARGUMENTS` into four optional filters:

- `FILTER_ALL=1` if `--all` is present (default: only active).
- `FILTER_ARCHIVED=1` if `--archived` is present (mutually exclusive with `--all`).
- `FILTER_GENRE=<name>` if `--genre <name>` is given.
- `FILTER_STATUS=<value>` if `--status active|completed|archived` is given (overrides `--all` / `--archived`).

If both `--all` and `--archived` are passed, prefer `--archived` and emit a one-line warning.

### Step 3 — Parse the registry

Use a defensive single-pass parser since registry.yaml is a flat list. Per H4 helper schema, each entry is a YAML map with fields `id`, `title`, `path`, `genre`, `language`, `created`, `last_touched`, `bookbench_version`, `status`. The parser tolerates missing optional fields.

```bash
# Quick awk-based extraction for stage 14 (helper-style; matches H4 sketch).
# Outputs lines: id<TAB>title<TAB>genre<TAB>status<TAB>last_touched<TAB>path
awk '
  /^  - id:/        { if(have){ print rec_id"\t"rec_title"\t"rec_genre"\t"rec_status"\t"rec_touched"\t"rec_path } ; have=1; rec_id=substr($0,index($0,":")+2); rec_title=""; rec_genre=""; rec_status="active"; rec_touched=""; rec_path="" ; next }
  /^    title:/     { rec_title=substr($0,index($0,":")+2); next }
  /^    path:/      { rec_path=substr($0,index($0,":")+2); next }
  /^    genre:/     { rec_genre=substr($0,index($0,":")+2); next }
  /^    last_touched:/ { rec_touched=substr($0,index($0,":")+2); next }
  /^    status:/    { rec_status=substr($0,index($0,":")+2); next }
  END { if(have) { print rec_id"\t"rec_title"\t"rec_genre"\t"rec_status"\t"rec_touched"\t"rec_path } }
' "$REGISTRY"
```

If the registry is malformed (no `books:` key, no records) — emit a friendly fallback:

```
The registry exists but contains no parsable entries.
Run `/bookbench:doctor` for diagnostics or `/bookbench:register <path>` to add a book.
```

### Step 4 — Apply filters

In-memory filtering on the parsed lines:

- Default: keep entries where `status == active`.
- `--all`: keep all entries (active + archived + completed).
- `--archived`: keep only `status == archived`.
- `--status <value>`: keep only entries with that status.
- `--genre <name>`: additionally keep only entries whose `genre` field equals `<name>` (case-insensitive trim).

If after filtering the list is empty, print:

```
No books match the filter (active=N, archived=M total).
Use --all to include archived.
```

### Step 5 — Render table

Format columns with column-aligned spacing. Truncate `id` to 32 chars, `title` to 40 chars, `path` to 48 chars (right side, with leading `…`). Show only year-month-day from `last_touched` (drop time). Example:

```
N active, 1 archived (2 total)

ID                              TITLE                  GENRE              STATUS    LAST_TOUCHED  PATH
my-book-2026-05-06              My Book                popular-science    active    2026-05-06    /Users/x/Books/my-book
detective-2026-04-30            Detective Story        detective          active    2026-05-04    /Users/x/Books/detective
memoir-2026-03-12               Memoir                 memoir             archived  2026-03-30    /Users/x/Books/memoir
```

If a row has missing data, render `—` (em-dash placeholder).

### Step 6 — Next-step message

```
Recommended next:
  /bookbench:status     — see what is happening in the current book (cwd-based detection).
  /bookbench:doctor     — diagnose registry / disk drift.
  /bookbench:register   — add a found-on-disk .book/ folder to the registry.
  /bookbench:archive    — soft-hide a finished book.
```

### Constitutional rules for this command

- **MUST** be read-only — never edit `registry.yaml` here.
- **MUST** tolerate a missing or malformed registry without exiting non-zero.
- **MUST** filter to `status == active` by default; `--all` is the explicit opt-in.
- **NEVER** open section content, guidelines, or memory files of any registered book — this command never crosses into book-local data.
- **NEVER** invoke any subagent — pure helper-driven listing.

</execution>
