---
description: Runs external research on a topic via book-factchecker — uses MCP search servers (Tavily / Brave / Exa / Perplexity), WebSearch, WebFetch, citation verification. Stores synthesis in chapters/<N>/research/external/<slug>.md if --chapter N is given, else in .book/research/external/<slug>.md. UX-05 from stage 7.2.
argument-hint: "<topic> [--chapter <N>] [--depth quick|standard|deep] [--prefer-sources <comma-sep>] [--max-results <K>]"
allowed-tools: [Task, Read, Write, Bash, AskUserQuestion]
---

# /book:research-external

<purpose>
External research about a topic via the internet. Distinct from `/book:research-internal` (which searches inside the book) and from `/book:research-genre` (which builds a genre methodology). Delegated to `book-factchecker` because it owns the MCP / WebSearch / citation tools.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный дизайн — `research-design.md` § 2 этапа 7.2 -->

## Inputs

- `<topic>` — required; the search query.
- `--chapter <N>` — optional; scopes the output to a specific chapter folder.
- `--depth quick|standard|deep` — optional; default `standard`.
- `--prefer-sources <comma-sep>` — optional; preferred URLs / DOIs / source names.
- `--max-results <K>` — optional; default 8.
- `.book/agent-guidelines/factchecker/trusted-sources.md` (read).
- `.book/agent-guidelines/factchecker/outdated-sources.md` (read, optional).
- `.book/context/parameters.md` (read).
- `${CLAUDE_PLUGIN_DATA}/settings.yaml` (read) — for available MCP servers.

## Outputs

- `.book/chapters/<N>/research/external/<slug>.md` — if `--chapter`.
- `.book/research/external/<slug>.md` — if no `--chapter`.

<execution>

Eight-step orchestrator: validate → resolve paths → confirm → Task to factchecker → verify → state mutation → next-step.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory. Run /book:start first."; exit 0; }

if [ -z "${ARGUMENTS:-}" ]; then
  echo "Error: /book:research-external requires a topic."
  echo "Usage: /book:research-external \"<topic>\" [--chapter <N>] [--depth quick|standard|deep]"
  exit 0
fi

# Parse arguments — first positional is topic (may contain spaces if quoted)
TOPIC=""
CHAPTER_N=""
DEPTH="standard"
PREFER=""
MAX_RESULTS=8

# Best-effort arg parsing (the actual command receives $ARGUMENTS as a single string)
while [ $# -gt 0 ]; do
  case "$1" in
    --chapter)         CHAPTER_N="$2"; shift 2 ;;
    --chapter=*)       CHAPTER_N="${1#--chapter=}"; shift ;;
    --depth)           DEPTH="$2"; shift 2 ;;
    --depth=*)         DEPTH="${1#--depth=}"; shift ;;
    --prefer-sources)  PREFER="$2"; shift 2 ;;
    --prefer-sources=*) PREFER="${1#--prefer-sources=}"; shift ;;
    --max-results)     MAX_RESULTS="$2"; shift 2 ;;
    --max-results=*)   MAX_RESULTS="${1#--max-results=}"; shift ;;
    *)                 TOPIC="${TOPIC:+$TOPIC }$1"; shift ;;
  esac
done

[ -z "$TOPIC" ] && { echo "Error: empty topic."; exit 0; }
case "$DEPTH" in quick|standard|deep) ;; *) DEPTH="standard" ;; esac
```

### Step 2 — Resolve output path

```bash
slugify() {
  printf '%s' "$1" \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-50
}
SLUG=$(slugify "$TOPIC")
[ -z "$SLUG" ] && SLUG="research-$(date -u +%s)"

if [ -n "$CHAPTER_N" ]; then
  CHAPTER_DIR=$(printf '.book/chapters/chapter-%03d' "$CHAPTER_N")
  [ -d "$CHAPTER_DIR" ] || {
    echo "Error: chapter $CHAPTER_N does not exist ($CHAPTER_DIR)."
    echo "Run /book:plan-chapter $CHAPTER_N first or omit --chapter."
    exit 0
  }
  OUT_DIR="$CHAPTER_DIR/research/external"
else
  OUT_DIR=".book/research/external"
fi
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/$SLUG.md"

# Idempotency: warn if file already exists
if [ -f "$OUT_FILE" ]; then
  echo "Note: previous research at $OUT_FILE will be overwritten on confirmation."
fi
```

### Step 3 — Confirmation gate (depth + sources)

Present an `AskUserQuestion`:

- Title: «External research plan»
- Body:
  - `Topic:    <TOPIC>`
  - `Depth:    <DEPTH>` (quick ≈ 1 min, standard ≈ 3 min, deep ≈ 8 min)
  - `Output:   <OUT_FILE>`
  - `Max results: <MAX_RESULTS>`
- Options:
  - `Run research` — proceed.
  - `Change depth` — re-prompt for depth (quick / standard / deep).
  - `Cancel` — exit.

### Step 4 — Delegate to book-factchecker via Task

```
Task(
  subagent_type: book-factchecker,
  description: "External research: <TOPIC>",
  prompt: """
    You are book-factchecker in research mode (skill: factcheck-protocol).
    Topic: «<TOPIC>»
    Depth: <DEPTH> (quick / standard / deep)
    Max results to synthesize: <MAX_RESULTS>
    Preferred sources (if non-empty): <PREFER>

    Required steps:
      1. Read trusted-sources.md and outdated-sources.md from agent-guidelines/factchecker.
      2. Use available MCP servers (Tavily / Brave / Exa / Perplexity) and WebSearch /
         WebFetch. Respect outdated-sources.md exclusions.
      3. Find at least 3 high-relevance sources (5+ for standard, 8+ for deep).
      4. Synthesize 2-3 paragraphs covering the topic.
      5. List sources in a table with URL/DOI, citation, relevance label.
      6. Write notes for the writer (suggestions on how to use this in a draft).

    Output file: <OUT_FILE>
    Use the template in research-design.md § 2.5 (etap 7.2).
    Return a 5-line summary; do NOT return the full body in the response.
  """,
  files_to_read: [
    .book/agent-guidelines/factchecker/trusted-sources.md (if exists),
    .book/agent-guidelines/factchecker/outdated-sources.md (if exists),
    .book/context/parameters.md (if exists),
    ${CLAUDE_PLUGIN_DATA}/settings.yaml (for MCP server configuration)
  ]
)
```

### Step 5 — Verify output

```bash
[ -s "$OUT_FILE" ] || {
  echo "Factchecker did not write the research file. Inspect the Task output."
  exit 1
}
N_SOURCES=$(grep -cE '^\| [0-9]+ \|' "$OUT_FILE" || echo 0)
[ "$N_SOURCES" -lt 3 ] && echo "Warning: only $N_SOURCES sources synthesized (minimum recommended: 3)."
```

### Step 6 — STATE.md history append

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SCOPE="general"
[ -n "$CHAPTER_N" ] && SCOPE="chapter $CHAPTER_N"
printf '\n%s — `/book:research-external` — topic «%s», %d sources, scope %s\n' \
  "$NOW" "$TOPIC" "$N_SOURCES" "$SCOPE" >> .book/STATE.md
```

### Step 7 — Optional memory note

Optionally append the new sources to `.book/agent-memory/factchecker/MEMORY.md` for future use. The factchecker does this itself per its memory protocol; the orchestrator does not duplicate.

### Step 8 — Next-step message

```
External research done: <OUT_FILE>
Sources: <N_SOURCES>

Recommended next:
  /book:plan-chapter <N>      — feed the research into chapter spec.
  /book:write-chapter <N>     — writer will pick up the research file automatically.
  /book:research-external "<another topic>"  — extend the research.
```

### Constitutional rules

- **MUST** delegate research to `book-factchecker` — never call WebSearch from the coordinator.
- **MUST** validate `--chapter <N>` if given; refuse if the chapter does not exist.
- **MUST** confirm depth and output path with the author before launching.
- **NEVER** modify chapter draft.md or edited.md — research is read-only input for writer.
- **NEVER** cite sources in chapter text directly — that is the writer's job.

</execution>
