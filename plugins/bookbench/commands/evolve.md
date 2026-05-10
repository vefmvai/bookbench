---
description: Cross-book pattern miner for the plugin maintainer. Reads metadata only (TUNING-LOG, REJECTIONS-LOG, agent-guidelines, config) from opted-in registered books, finds patterns recurring in three or more books, then proposes a diff or applies it to plugin sources with a git commit (apply is local-dev only). Status mode lists pending, applied and conflicts. Never reads sections, inputs, intel, debug, or agent-memory.
argument-hint: "<propose|apply|status> [<change-id>] [--no-commit] [--genre <name>] [--books <id-list>] [--min-books <N>]"
allowed-tools: [Read, Write, Bash, Glob, Grep, Task, AskUserQuestion]
---

# /bookbench:evolve

<purpose>
Maintainer-side cross-book pattern miner. Strictly dev-only — produces diffs against the plugin sources and triggers a git commit when applied. The implementation is embedded in this command (EV-1 closure: no separate subagent on 0.1 — analyzer logic lives in the command body, leveraging Task delegation to a nested book-tuner-style analyzer for the pattern detection sub-step). Honours strict privacy guarantees enumerated in `evolver-design.md` § 5.
</purpose>

<!-- Stage 14, Wave B, T5: full implementation. Closes EV-1..EV-6. -->

## Visibility (PS-12-02 dual mechanism)

The `description` is intentionally generic (no `dev-only:` token) so that listing-time filters in older Claude Code versions stay backwards-compatible. The runtime guard below is the authoritative gate.

### Step 0 — Runtime visibility guard

```bash
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
[ -z "$PLUGIN_DATA" ] && {
  if [ -n "${LOCALAPPDATA:-}" ]; then PLUGIN_DATA="$LOCALAPPDATA/bookbench"
  else PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"; fi
}
INST="$PLUGIN_DATA/installation.yaml"
SOURCE="local-dev"
[ -f "$INST" ] && SOURCE="$(awk '/^source:/ {print $2; exit}' "$INST" 2>/dev/null || echo local-dev)"

# `apply` is local-dev only. `propose` and `status` work in any installation
# but emit a soft warning outside local-dev (because outside a git checkout
# the diff cannot be applied later).
case "$ARGUMENTS" in
  apply*|*--apply*)
    if [ "$SOURCE" != "local-dev" ]; then
      echo "/bookbench:evolve apply is available only in local-dev mode (current source: $SOURCE)."
      echo "Run /bookbench:evolve propose to inspect potential changes; apply requires a git checkout of the plugin."
      exit 0
    fi
    ;;
esac
echo "evolve: installation.source=$SOURCE; PLUGIN_DATA=$PLUGIN_DATA"
```

## Argument parsing

### Step 1 — Parse `$ARGUMENTS`

```bash
RAW="${ARGUMENTS:-}"
MODE=""
CHANGE_ID=""
NO_COMMIT=0
GENRE=""
BOOKS_FILTER=""
MIN_BOOKS=""

# First positional token is the mode.
set -- $RAW
MODE="${1:-}"
shift 2>/dev/null || true

# Consume positional change-id only when in apply mode.
if [ "$MODE" = "apply" ] && [ -n "${1:-}" ] && [ "${1#--}" = "$1" ]; then
  CHANGE_ID="$1"
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --no-commit) NO_COMMIT=1 ;;
    --genre)     GENRE="$2"; shift ;;
    --books)     BOOKS_FILTER="$2"; shift ;;
    --min-books) MIN_BOOKS="$2"; shift ;;
    *) echo "evolve: unknown flag '$1' — ignored" 1>&2 ;;
  esac
  shift
done

case "$MODE" in
  propose|apply|status) ;;
  *)
    echo "Usage: /bookbench:evolve <propose|apply|status> [args]"
    exit 0
    ;;
esac
echo "evolve: mode=$MODE change_id=$CHANGE_ID no_commit=$NO_COMMIT genre=$GENRE books=$BOOKS_FILTER min_books=$MIN_BOOKS"
```

## Step 2 — Resolve plugin paths and ensure evolver tree

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && {
  for c in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    [ -f "$c/manifest.json" ] && PLUGIN_ROOT="$c" && break
  done
}
[ -z "$PLUGIN_ROOT" ] && {
  echo "evolve: cannot resolve CLAUDE_PLUGIN_ROOT. Set the env var or reinstall the plugin."
  exit 0
}

EVOLVER_DIR="$PLUGIN_DATA/evolver"
mkdir -p \
  "$EVOLVER_DIR/analysis-history" \
  "$EVOLVER_DIR/pending-changes" \
  "$EVOLVER_DIR/applied" \
  "$EVOLVER_DIR/conflicts"

REGISTRY="$PLUGIN_DATA/registry.yaml"
SETTINGS="$PLUGIN_DATA/settings.yaml"

# EV-3 default: minimum 3 active books needed for an analysis run.
DEFAULT_MIN_BOOKS=3
EFFECTIVE_MIN_BOOKS="${MIN_BOOKS:-}"
if [ -z "$EFFECTIVE_MIN_BOOKS" ] && [ -f "$SETTINGS" ]; then
  EFFECTIVE_MIN_BOOKS="$(awk '/^[[:space:]]*min_books_for_analysis:/ {print $2; exit}' "$SETTINGS" 2>/dev/null || true)"
fi
[ -z "$EFFECTIVE_MIN_BOOKS" ] && EFFECTIVE_MIN_BOOKS="$DEFAULT_MIN_BOOKS"

TS="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
echo "evolve: plugin_root=$PLUGIN_ROOT evolver_dir=$EVOLVER_DIR ts=$TS min_books=$EFFECTIVE_MIN_BOOKS"
```

## Mode dispatch

### Step 3 — Dispatch on `$MODE`

```bash
case "$MODE" in
  status)  : ;;  # Step 4S
  propose) : ;;  # Steps 4P-9P
  apply)   : ;;  # Steps 4A-7A
esac
```

---

## Mode `status`

### Step 4S — List the evolver tree

```bash
echo "== Pending changes =="
ls -1t "$EVOLVER_DIR/pending-changes" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo "== Applied =="
ls -1t "$EVOLVER_DIR/applied" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo "== Conflicts (manual review) =="
ls -1t "$EVOLVER_DIR/conflicts" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo "== Recent analysis history =="
ls -1t "$EVOLVER_DIR/analysis-history" 2>/dev/null | head -5 | sed 's/^/  /' || echo "  (none)"
```

End the command after `status`.

---

## Mode `propose`

### Step 4P — Validate registry

```bash
[ -f "$REGISTRY" ] || {
  echo "evolve: $REGISTRY not found. Register at least $EFFECTIVE_MIN_BOOKS books before running propose."
  exit 0
}
```

### Step 5P — Build the eligible-books list (privacy filter)

Read `$REGISTRY` and select records that are eligible for cross-book analysis:

- `status: active` or `status: completed`;
- `private: true` is **absent or false**;
- `include_in_evolver: false` is **absent or false** (default opt-in is true on a per-book basis only when the book registered with explicit consent — for stage 14 we treat the absence of either flag as opt-out for safety);
- if `--genre <name>` was passed, `genre` matches.

Use Read on `$REGISTRY` with the YAML structure `books: [ {id, path, genre, status, private?, include_in_evolver?}, ... ]`. Construct an in-memory list `$ELIGIBLE` of `(id, path, genre)` tuples. If `--books <list>` was passed, intersect with the comma-separated list.

Pseudocode (executed by the model after reading the file):

```
read_yaml(REGISTRY)
eligible = []
for book in books:
    if book.status not in ("active", "completed"): continue
    if book.get("private", False): continue
    if not book.get("include_in_evolver", False): continue   # safety default
    if GENRE and book.genre != GENRE: continue
    if BOOKS_FILTER and book.id not in BOOKS_FILTER.split(","): continue
    eligible.append(book)
```

### Step 6P — Pre-flight on count

```bash
# After building $ELIGIBLE in the model's working memory, materialise count:
COUNT="${ELIGIBLE_COUNT:-0}"
if [ "$COUNT" -lt "$EFFECTIVE_MIN_BOOKS" ]; then
  echo "evolve: only $COUNT eligible books found; minimum is $EFFECTIVE_MIN_BOOKS (EV-3)."
  echo "Eligibility requires status=active|completed, private!=true, include_in_evolver=true, and matching --genre/--books filters."
  exit 0
fi
```

### Step 7P — Read metadata only (privacy guarantee)

For each eligible book, the model reads **only** these paths via the Read tool:

- `<book.path>/.book/TUNING-LOG.md`
- `<book.path>/.book/REJECTIONS-LOG.md`
- `<book.path>/.book/UPDATE-LOG.md` (if present)
- `<book.path>/.book/config.yaml`
- `<book.path>/.book/agent-guidelines/<role>/*.md` (recursive Glob; YAML frontmatter + body of guideline files only)
- `<book.path>/.book/.claude/agents/<role>.md` — **frontmatter only** (the model parses YAML and discards the body to detect template drift; the body is not retained or processed for content patterns)

The model **must not** Read any of these:

- `<book.path>/.book/sections/**`
- `<book.path>/.book/inputs/**`
- `<book.path>/.book/intel/**`
- `<book.path>/.book/debug/**`
- `<book.path>/.book/.claude/agent-memory/**`

If, due to a tool error or path traversal, the model finds itself about to access one of the forbidden paths — **STOP**, write a record to `$EVOLVER_DIR/conflicts/$TS-privacy-violation.md` describing the attempted access and the source book, and abort the run with exit message «evolve: privacy guard tripped — see evolver/conflicts/».

### Step 8P — Detect cross-book patterns (Task delegation)

The actual pattern detection — clustering identical or near-identical TUNING-LOG entries across books, computing rejection-category overlaps, and identifying recurring guideline additions — is delegated to a `Task` invocation. Stage 14 EV-1 closure: this is **not** a new subagent; we re-use the existing `book-tuner` agent in **cross-book analysis mode** by passing `mode: cross-book` and an explicit list of pre-collected metadata payloads as the prompt input.

```text
Task(
  subagent_type="book-tuner",
  prompt="""
  You are running in cross-book analysis mode (EV-1, stage 14).
  Below is a JSON list of book metadata payloads. Each payload has:
    - id, genre, plugin_version
    - tuning_log: list of entries
    - rejections_log: list of entries
    - guidelines_summary: list of (role, file, top_lines)
  Your task:
    1. Cluster TUNING-LOG entries across books by (role, target_file, change_summary).
    2. For each cluster of size >= max(min_books_for_analysis, 3), propose a level
       (L-1 defaults.yaml | L-2 agent template | L-3 new skill | L-4 new genre)
       per evolver-design.md § 3.1.
    3. For each cluster, classify priority: critical (>=80% of eligible books),
       important (>=40%), optional (>=20%).
    4. For conflicting patterns (3 books add a rule, 2 remove it), apply DEC-08
       (majority -> date -> manual review) and emit a conflicts record.
    5. Produce a unified diff against PLUGIN_ROOT for each cluster with a clear level.
  Output strictly:
    - JSON block "patterns": [...]
    - JSON block "conflicts": [...]
    - One unified diff per pattern, ready to apply with `git apply`.
  Do not hallucinate book contents; rely only on the payloads provided.
  """
)
```

The Task call returns three artefacts that the command body persists:

- `patterns` — list of pattern objects (id, level, priority, books, diff_path)
- `conflicts` — list of conflict objects (id, books_for, books_against, candidate_diffs)
- `diff_text` — the full unified diff (concatenated per-pattern diffs)

### Step 9P — Persist artefacts

```bash
ANALYSIS="$EVOLVER_DIR/analysis-history/$TS-analysis.md"
PENDING="$EVOLVER_DIR/pending-changes/$TS-pending.diff"

# The model writes the analysis report (markdown, ~150-400 lines) and the
# pending diff (unified diff) using the Write tool. Conflict records (if any)
# go to $EVOLVER_DIR/conflicts/$TS-conflict-<NN>.md.
echo "evolve: wrote $ANALYSIS"
echo "evolve: wrote $PENDING"
echo "evolve: conflicts (if any) under $EVOLVER_DIR/conflicts/"
```

The `analysis.md` template (one block per pattern):

```markdown
# Evolver analysis — <ISO timestamp>

## Resume
- Eligible books: <N>
- Patterns found: <K>  (critical: <K1>, important: <K2>, optional: <K3>)
- Conflicts: <C>

## Patterns

### Pattern P-1 (priority: critical, level: L-1)
- Books: <id1>, <id2>, <id3> (<N>/<eligible> books)
- Genre filter: <none|popular-science|...>
- Diff target: ${CLAUDE_PLUGIN_ROOT}/defaults.yaml
- Rationale: <why this rule belongs in defaults>

### Pattern P-2 ...

## Conflicts (need manual review)

### Conflict C-1
- Books for: <id1>, <id2>, <id3>
- Books against: <id4>, <id5>
- DEC-08 resolution: majority -> date -> manual
- See: evolver/conflicts/<TS>-conflict-01.md

## Coverage check
- All TUNING-LOG entries from <N> books read.
- Books skipped: <count> (private: true)
```

### Step 10P — Author gate (interactive review)

Use AskUserQuestion to show the patterns summary and ask:

- `Apply now (apply <pending-id>)`
- `Save for later (no action)`
- `Discard (delete pending diff)`

If the user picks `Save for later` (default in stage 14), exit with the next-step message:

```text
evolve propose: <K> patterns staged at $PENDING.
Run `/bookbench:evolve apply $TS` (in local-dev only) to apply, or `/bookbench:evolve status` to inspect.
```

End of `propose`.

---

## Mode `apply`

### Step 4A — Resolve the pending diff

```bash
if [ -z "$CHANGE_ID" ]; then
  CHANGE_ID="$(ls -1t "$EVOLVER_DIR/pending-changes" 2>/dev/null | head -1)"
  CHANGE_ID="${CHANGE_ID%.diff}"
  CHANGE_ID="${CHANGE_ID%-pending}"
fi
PENDING="$EVOLVER_DIR/pending-changes/$CHANGE_ID-pending.diff"
[ -f "$PENDING" ] || PENDING="$EVOLVER_DIR/pending-changes/$CHANGE_ID.diff"
[ -f "$PENDING" ] || {
  echo "evolve apply: pending diff for change-id '$CHANGE_ID' not found in $EVOLVER_DIR/pending-changes/"
  exit 0
}
echo "evolve apply: using $PENDING"
```

### Step 5A — Pre-flight on git checkout

```bash
cd "$PLUGIN_ROOT" || { echo "evolve apply: cannot cd to $PLUGIN_ROOT"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "evolve apply: $PLUGIN_ROOT is not a git work tree. Apply requires local-dev with git."
  exit 0
}
DIRTY="$(git status --porcelain | wc -l | tr -d ' ')"
if [ "$DIRTY" -gt 0 ] && [ "$NO_COMMIT" -eq 0 ]; then
  echo "evolve apply: working tree has $DIRTY uncommitted changes."
  echo "Either commit / stash them, or pass --no-commit (EV-5) to apply without committing."
  exit 0
fi
```

### Step 6A — Apply the diff

```bash
APPLIED_LOG="$EVOLVER_DIR/applied/$TS-applied.log"
{
  echo "change_id: $CHANGE_ID"
  echo "applied_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "no_commit: $NO_COMMIT"
  echo "---"
} > "$APPLIED_LOG"

git apply --check "$PENDING" 2>>"$APPLIED_LOG" || {
  echo "evolve apply: diff does not apply cleanly. See $APPLIED_LOG."
  echo "Possible causes: plugin sources changed since propose; conflicting concurrent apply; stale diff."
  exit 0
}
git apply "$PENDING" 2>>"$APPLIED_LOG"
```

### Step 7A — Commit (or skip with --no-commit)

```bash
if [ "$NO_COMMIT" -eq 0 ]; then
  COMMIT_MSG="evolver: apply pattern set $CHANGE_ID

See $EVOLVER_DIR/analysis-history/$CHANGE_ID-analysis.md for the rationale.
Honoured privacy filter (registry.private != true; include_in_evolver == true).
"
  git add -A
  git commit -m "$COMMIT_MSG" >>"$APPLIED_LOG" 2>&1
  echo "evolve apply: committed."
else
  echo "evolve apply: --no-commit set (EV-5); changes left staged in working tree."
fi

echo "evolve apply: done. Log at $APPLIED_LOG."
```

End of `apply`.

---

## Privacy guarantees (structural)

This command **never** reads from any of the following paths in any registered book:

- `<book>/.book/sections/**`
- `<book>/.book/inputs/**`
- `<book>/.book/intel/**`
- `<book>/.book/debug/**`
- `<book>/.book/.claude/agent-memory/**`

Enforcement is layered:

1. The pseudocode in Step 7P explicitly enumerates allowed paths.
2. The Task delegation in Step 8P passes only metadata-derived payloads, never raw section content.
3. Privacy unit tests live under `bookbench/tests/eval-cases/commands/evolve/privacy-test-{01..04}.md` and assert that any path traversal into the forbidden list produces a `conflicts/<TS>-privacy-violation.md` record and aborts.

## CI mode (EV-6)

Not implemented in stage 14 / 0.1. Future versions may add a `--ci` flag that disables AskUserQuestion gates and writes the apply outcome to a fixed log file. For 0.1 the command is interactive-only.

## Closure of EV-1..EV-6

| Open question | Closure (PS-14-XX in decisions-14.md) |
|---|---|
| EV-1 — separate subagent or embedded logic? | **Embedded logic** in this command body; pattern detection step delegates via `Task` to the existing `book-tuner` in cross-book analysis mode. Rationale: no persistent state for evolver across runs; rare invocation; preserves TR-06 (9 roles fixed). |
| EV-2 — conflicting patterns? | **DEC-08 inheritance** — majority -> date -> manual review. Conflicts are written to `evolver/conflicts/<TS>-conflict-NN.md` and force `manual-review` status (no auto-apply). |
| EV-3 — minimum books for analysis? | **>= 3 eligible books** by default; configurable via `${CLAUDE_PLUGIN_DATA}/settings.yaml`'s `min_books_for_analysis` field; below threshold the command exits with a clear message. |
| EV-4 — plugin version conflicts? | The command reads each book's `.book/config.yaml` `bookbench_version` and groups books by version when running pattern detection; cross-version patterns are surfaced as warnings in the analysis report; no books are silently skipped. |
| EV-5 — apply without commit? | `--no-commit` flag is supported (Step 7A); without it `git commit` runs automatically. |
| EV-6 — CI mode? | Not implemented in 0.1. Stub only. |

## Notes

- `propose` mode runs in any installation; `apply` mode runs only in `local-dev`.
- All operations require human confirmation through AskUserQuestion at the gate; no silent applies.
- The `analysis-history/` tree is append-only — old runs are kept for the audit trail.
- `pending-changes/` files survive until they are applied or explicitly discarded with a future `evolve discard` (not in 0.1).
