---
description: Imports existing author materials (markdown, docx, txt, claude.ai chat exports, Obsidian vaults) into the BookBench structure via a two-stage pipeline — book-doc-classifier (parallel by file) followed by book-doc-synthesizer. Produces INGEST-DECISIONS.md with three buckets (auto-resolved, competing-variants, rejected) and asks the author for batch confirmation. Two modes — new (creates a fresh book from materials) and merge (folds materials into an existing book).
argument-hint: "[<path>] [--mode new|merge] [--from claudeai|obsidian|fs] [--manifest <file>]"
allowed-tools: [Task, Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# /book:import

<purpose>
Bring legacy notes into a structured book. Implements the second of the two starting scenarios — author has drafts, chat exports, or vault notes and wants them ingested into the BookBench structure. Two-stage pipeline: classifier sorts each file into one of 11 classes; synthesizer proposes a destination per item with an INGEST-DECISIONS gate.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `<path>` (positional, optional): file or directory; defaults to `.book/inputs/`.
- `--mode new` (default at `/book:start --from-existing`) or `--mode merge` (running on an established book).
- `--from <type>` for source-format hints (`claudeai`, `obsidian`, `fs`).
- `--manifest <file>` for an external manifest of files to consider (overrides `<path>` glob).

## Outputs

- `.book/intel/classifications/<filename>.json` — output of classifier per file.
- `.book/INGEST-DECISIONS.md` — synthesizer's proposed mapping with three buckets: `auto-resolved`, `competing-variants`, `rejected`.
- After author confirmation: writes into `agent-memory/<role>/MEMORY.md`, `context/`, `chapters/<id>/`, `agent-guidelines/<role>/`.

<execution>

This is the largest orchestrator in stage 14. It implements `import-scenario-flow.md` (etap 11) and DEC-04 of stage 10. Eight-step pattern with two Task delegations (classifier → synthesizer).

### Step 1 — Pre-flight

```bash
[ -d .book ] || {
  echo "No .book/ directory. Run /book:start first or use /book:start --from-existing."
  exit 0
}

# Parse arguments
MODE="merge"   # default for established books
SOURCE_PATH=""
FROM_TYPE=""
MANIFEST=""
for arg in $ARGUMENTS; do
  case "$arg" in
    --mode=*)     MODE="${arg#--mode=}" ;;
    --from=*)     FROM_TYPE="${arg#--from=}" ;;
    --manifest=*) MANIFEST="${arg#--manifest=}" ;;
    /* | ./*)     SOURCE_PATH="$arg" ;;
    *)            : ;;  # ignore unknown
  esac
done

# Default source path
[ -z "$SOURCE_PATH" ] && SOURCE_PATH=".book/inputs"

# Validate
if [ -n "$MANIFEST" ] && [ ! -f "$MANIFEST" ]; then
  echo "Error: --manifest file '$MANIFEST' does not exist."
  exit 0
fi
if [ -z "$MANIFEST" ] && [ ! -e "$SOURCE_PATH" ]; then
  echo "Error: source path '$SOURCE_PATH' does not exist."
  echo "Either pass an explicit <path> or place files into .book/inputs/."
  exit 0
fi

# Detect existing import (idempotency)
EXISTING_DECISIONS=""
[ -f .book/INGEST-DECISIONS.md ] && EXISTING_DECISIONS="yes"
```

### Step 2 — Mode interaction

If existing INGEST-DECISIONS.md is present and the new mode is `merge`, ask:

- Title: «Existing INGEST-DECISIONS.md detected»
- Options:
  - `Continue (append new pass)` — keep old, add new section dated today.
  - `Replace (start fresh)` — backup old to `.book/.backup/INGEST-DECISIONS-<TS>.md` and start clean.
  - `Cancel` — exit.

### Step 3 — Build the file list

If `--manifest` is given — read line-by-line. Otherwise, glob the source path. Limit to 100 files per invocation (per `/book:import` design); if the glob returns more, ask the author whether to take the first 100 alphabetically or to cancel and re-run with a manifest.

```bash
# Build file list
if [ -n "$MANIFEST" ]; then
  FILES=$(grep -v '^#' "$MANIFEST" | grep -v '^$')
elif [ -d "$SOURCE_PATH" ]; then
  FILES=$(find "$SOURCE_PATH" -maxdepth 4 -type f \( -name '*.md' -o -name '*.txt' -o -name '*.docx' -o -name '*.json' \) | head -100)
else
  FILES="$SOURCE_PATH"   # single file
fi
N_FILES=$(echo "$FILES" | grep -c .)
[ "$N_FILES" -eq 0 ] && { echo "No importable files found at $SOURCE_PATH."; exit 0; }
```

### Step 4 — Classification phase (book-doc-classifier)

For each file, invoke `Task` with `subagent_type: book-doc-classifier`. Classifier is `memory: none` per MEM-01 — every call is independent. Per `import-scenario-flow.md`, classifier produces JSON with class label (one of 11), confidence, and content snippets.

```
For each FILE in FILES:
  Task(
    subagent_type: book-doc-classifier,
    description: "Classify imported file <FILE>",
    prompt: """
      You are book-doc-classifier (memory: none).
      Classify the file <FILE> into one of 11 classes:
        glossary | character | concept | metaphor | example | voice-sample
        | chapter-fragment | research-note | rejected-claim
        | structural-decision | other.
      Output JSON: { class, confidence (0-1), tag_hints, fragments[] }.
      Write to .book/intel/classifications/<basename>.json.
    """,
    files_to_read: [
      <FILE>,
      .book/PROJECT.md,
      .book/config.yaml,
      .book/context/voice-profile.md (if exists),
      .book/context/glossary.md (if exists)
    ]
  )
```

For stage 14 the orchestrator runs classifier calls **sequentially** (one Task per file). Parallel batches are stage 15+ optimisation.

After all classifier runs:

```bash
[ -d .book/intel/classifications ] || mkdir -p .book/intel/classifications
N_CLASSIFIED=$(find .book/intel/classifications -name '*.json' -type f | wc -l)
[ "$N_CLASSIFIED" -lt "$N_FILES" ] && echo "Warning: $((N_FILES - N_CLASSIFIED)) files were not classified successfully."
```

### Step 5 — Synthesis phase (book-doc-synthesizer)

Single Task to synthesizer with the classification corpus as input.

```
Task(
  subagent_type: book-doc-synthesizer,
  description: "Synthesize import decisions for <N_FILES> files",
  prompt: """
    You are book-doc-synthesizer (memory: none).
    Read the classification JSONs and propose a destination per item:
      • auto-resolved bucket — high-confidence single-destination items (apply directly).
      • competing-variants bucket — items where 2+ destinations make sense
        OR 2+ files compete for the same destination slot.
      • rejected bucket — low-confidence / off-topic / duplicate items.

    Mode parameter: ${MODE}
      • new      — produce a full bootstrap proposal: PROJECT.md hints,
                   config.yaml hints, ROADMAP.md skeleton, voice-profile,
                   chapters/*/draft.md proposals.
      • merge    — fold into existing structure: extend glossary, add to
                   character/concept registries, optionally append chapters.

    Output: .book/INGEST-DECISIONS.md with three labelled bucket sections.
    For each item write: source-file → destination → rationale → confidence.
    For competing-variants give each variant a id like `V-01`.
  """,
  files_to_read: [
    .book/PROJECT.md,
    .book/config.yaml,
    .book/intel/classifications/   (directory listing — synthesizer reads each)
    .book/context/voice-profile.md,
    .book/context/glossary.md,
    .book/context/red-thread-keywords.md,
    .book/ROADMAP.md  (if exists)
  ]
)
```

After Task returns, verify INGEST-DECISIONS.md exists and has at least one bucket section. If empty:

```
Synthesizer returned no decisions. Inspect .book/intel/classifications/
manually or re-run /book:import.
```

### Step 6 — INGEST-DECISIONS gate (batch confirm)

Read INGEST-DECISIONS.md and extract the three bucket counters (e.g., `Auto-resolved: 12 items, Competing variants: 3, Rejected: 2`). Present an `AskUserQuestion`:

- Title: «Import decisions ready»
- Body: «Synthesizer proposes:
  - Auto-resolved: N items (will be applied directly)
  - Competing variants: M items (require manual `/book:resolve <V-id>`)
  - Rejected: K items (no destination found)»
- Options:
  - `Apply auto-resolved now` — proceed to Step 7.
  - `Show details first` — print INGEST-DECISIONS.md head (≈80 lines) and re-ask.
  - `Cancel (keep file, do not apply)` — exit; the author can review and re-run later.

### Step 7 — Apply auto-resolved items

For each item in the `auto-resolved` bucket, the synthesizer's output already contains a `destination_path` and an `action` (one of: `append`, `create`, `merge`). Apply each:

```
For each auto-resolved item:
  - destination=<path>, action=<append|create|merge>, payload=<text>
  - Backup existing <destination> to .book/.backup/<TS>/<flat-path>
  - Apply action
  - Write a one-line entry to INGEST-DECISIONS.md > "Applied" section
```

The synthesizer is the only role with permission to write into other roles' MEMORY.md per MEM-01. For `auto-resolved` items into `agent-memory/<role>/MEMORY.md`, the orchestrator delegates by re-invoking synthesizer with explicit `apply` mode (a small follow-up Task call). For all other destinations (`context/`, `chapters/`, `agent-guidelines/`), the orchestrator can `Write` / `Edit` directly.

### Step 8 — Atomic state mutation + next-step

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
APPLIED=$(grep -c '^\* applied' .book/INGEST-DECISIONS.md || echo 0)
PENDING=$(grep -c '^- V-' .book/INGEST-DECISIONS.md || echo 0)

# Update STATE.md
printf '\n%s — `/book:import` — applied %d auto-resolved; %d competing variants pending\n' \
  "$NOW" "$APPLIED" "$PENDING" >> .book/STATE.md

if [ "$PENDING" -gt 0 ]; then
  echo "Import done: $APPLIED items applied, $PENDING competing variants pending."
  echo ""
  echo "Recommended next:"
  echo "  /book:resolve V-01    — resolve the first competing variant."
  echo "  /book:resolve V-02    — and so on."
  echo "  /book:status          — overview after import."
else
  echo "Import done: $APPLIED items applied. No competing variants."
  echo ""
  echo "Recommended next:"
  echo "  /book:status         — overview after import."
  echo "  /book:plan-book      — (re-)plan now that material is in place."
fi
```

### Constitutional rules

- **MUST** call classifier and synthesizer with `memory: none` (per MEM-01).
- **MUST** treat classifier and synthesizer as the only roles permitted to read raw author materials (`<path>` content) — the orchestrator only reads them via the Tasks' `<files_to_read>`.
- **MUST** present an INGEST-DECISIONS gate before applying anything (Brief-Then-Execute, Part VII methodology).
- **MUST** keep competing variants pending — never auto-resolve them (that is `/book:resolve`).
- **NEVER** delete original files in `<path>` or `.book/inputs/` — they remain as authoritative source.
- **NEVER** invoke writer / editor / factchecker — these come later via `/book:write-chapter`.
- **NEVER** exceed the per-invocation limit of 100 files; for larger imports, ask the author for a manifest split.

</execution>
