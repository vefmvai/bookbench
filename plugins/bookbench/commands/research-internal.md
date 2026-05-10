---
description: Searches inside the book — sections, glossary, registries, worldbuilding — for a query. Read-only. Uses Glob and Grep to find every occurrence; assembles a concise report grouped by source. UX-05 from stage 7.2. Distinct from /bookbench:research-external (internet search) and /bookbench:research-genre (genre methodology research).
argument-hint: "<query> [--section <N>] [--scope sections|context|memory|all]"
allowed-tools: [Read, Glob, Grep, Bash, Write]
---

# /bookbench:research-internal

<purpose>
Internal research — searching inside what is already written or imported into the book. For checking cross-references, finding earlier mentions of a concept, locating where a character appeared first, etc. Read-only search through sections, context files, and (optionally) agent memory.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный дизайн — `research-design.md` § 3 этапа 7.2 -->

## Inputs

- `<query>` — required; the search string or simple regex.
- `--section <N>` — optional; restrict to one section.
- `--scope sections|context|memory|all` — default `sections+context` (a.k.a. "user-visible content").

## Outputs

- A formatted report on stdout grouped by source: section, context file, memory file.
- Optional `.book/research/internal/<slug>.md` with the same content (only if the result is large; default — stdout only).

<execution>

Read-only command. Six-step pattern (no AskUserQuestion, no state mutation by default).

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory. Run /bookbench:start first."; exit 0; }

if [ -z "${ARGUMENTS:-}" ]; then
  echo "Error: /bookbench:research-internal requires a query."
  echo "Usage: /bookbench:research-internal \"<query>\" [--section <N>] [--scope <scope>]"
  exit 0
fi

# Parse arguments
QUERY=""
SECTION_N=""
SCOPE="sections+context"

while [ $# -gt 0 ]; do
  case "$1" in
    --section)        SECTION_N="$2"; shift 2 ;;
    --section=*)      SECTION_N="${1#--section=}"; shift ;;
    --scope)          SCOPE="$2"; shift 2 ;;
    --scope=*)        SCOPE="${1#--scope=}"; shift ;;
    *)                QUERY="${QUERY:+$QUERY }$1"; shift ;;
  esac
done

[ -z "$QUERY" ] && { echo "Error: empty query."; exit 0; }
```

### Step 2 — Build search paths from scope

```bash
PATHS=""
case "$SCOPE" in
  sections)
    PATHS=".book/sections" ;;
  context)
    PATHS=".book/context" ;;
  memory)
    PATHS=".book/agent-memory" ;;
  sections+context|"")
    PATHS=".book/sections .book/context" ;;
  all)
    PATHS=".book/sections .book/context .book/agent-memory" ;;
  *)
    echo "Error: unknown scope '$SCOPE'."
    echo "Valid: sections | context | memory | sections+context | all."
    exit 0 ;;
esac

# Restrict to one section
if [ -n "$SECTION_N" ]; then
  SECTION_DIR=$(printf '.book/sections/section-%03d' "$SECTION_N")
  [ -d "$SECTION_DIR" ] || {
    echo "Error: section $SECTION_N does not exist ($SECTION_DIR)."
    exit 0
  }
  PATHS="$SECTION_DIR"
fi
```

### Step 3 — Run grep

Use `Grep` (the platform tool) with case-insensitive matching, multi-line context, and grouping by file:

```
Grep(
  pattern: <QUERY>,
  path: <each path in PATHS>,
  -i: true,
  -n: true,
  -C: 2,
  output_mode: content
)
```

Aggregate hits per file. Tolerate missing directories (skip silently).

```bash
TOTAL_HITS=0
for p in $PATHS; do
  [ -d "$p" ] || continue
  HITS=$(grep -rEn -i -C 2 "$QUERY" "$p" 2>/dev/null | wc -l)
  TOTAL_HITS=$((TOTAL_HITS + HITS))
done
```

### Step 4 — Group and render

Build a report grouped by file. Sort: section directories first (in section order), then `context/`, then `agent-memory/`. For each file: print path + line numbers + 2-line context per hit.

```
== Internal research: «<QUERY>» ==

Scope: <SCOPE> (section <N>)
Total hits: <TOTAL_HITS> across <FILE_COUNT> files

── sections/section-001/edited.md (3 hits) ──
  L:42-44   ...context...
  L:118-120 ...context...
  L:201-203 ...context...

── sections/section-005/spec.md (1 hit) ──
  L:18-20   ...context...

── context/glossary.md (2 hits) ──
  ...

── agent-memory/strategist/MEMORY.md (1 hit) ──
  ...
```

### Step 5 — (Optional) save to file if result is large

If `TOTAL_HITS > 50` or `--save` was passed (future feature), write the same content to `.book/research/internal/<slug>.md`:

```bash
slugify() {
  printf '%s' "$1" \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-50
}
SLUG=$(slugify "$QUERY")

if [ "$TOTAL_HITS" -gt 50 ]; then
  mkdir -p .book/research/internal
  OUT_FILE=".book/research/internal/$SLUG.md"
  # Write the rendered report to OUT_FILE
fi
```

### Step 6 — Next-step message

```
Internal research done.
Hits: <TOTAL_HITS> across <FILE_COUNT> files.

Recommended next:
  /bookbench:research-internal "<refined query>"  — refine.
  /bookbench:research-external "<topic>"           — branch into external research.
  /bookbench:plan-section <N>                       — use findings in a section spec.
```

### Constitutional rules

- **MUST** be read-only. No edits to any file.
- **MUST** tolerate missing directories — empty scope is not an error.
- **MUST** support both literal strings and simple regex (default: ERE — extended regex).
- **NEVER** invoke any subagent — pure search.
- **NEVER** read inputs that are not under the requested scope (e.g. with `--scope sections`, do not read context).

</execution>
