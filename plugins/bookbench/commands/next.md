---
description: Рекомендует следующий шаг воркфлоу для текущей книги на основе workflow.md, STATE.md и состояний глав. Ядро рекомендации — правила, объяснение опционально подмешивает LLM. Без флагов показывает рекомендацию; --execute сразу запускает рекомендованную команду; --explain добавляет развёрнутое обоснование выбора.
argument-hint: "[--execute] [--explain] [--from-block <name>]"
allowed-tools: [Read, Bash, Glob, Task, AskUserQuestion]
---

# /book:next

<purpose>
Single navigation entrypoint of BookBench: «what should I do right now?». Reads the workflow DAG and current state, applies a Decision Tree to pick the next pending block, returns a recommendation (default) or runs the matching command (`--execute`).
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный дизайн — `next-design.md` этапа 7.2 -->

## Inputs

- `.book/workflow.md` — DAG-config for the book.
- `.book/STATE.md` — current section, last action, history.
- `.book/sections/*/` — listing + section-state.yaml per section.
- `.book/INGEST-DECISIONS.md` (if exists) — for unresolved competing variants.
- `.book/config.yaml` — defaults.

## Outputs

- One-line recommendation + 2–5 lines of reasoning + optional alternatives (with `--explain`).
- With `--execute`: side effects of the dispatched command.
- Always: a one-line `STATE.md` history append.

<execution>

This is the runtime navigation core. Implements the Decision Tree from `next-design.md` § 2. Eight steps with a hybrid rule-based + LLM-explanation core.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory. Run /book:start first."; exit 0; }
[ -f .book/STATE.md ] || { echo "No STATE.md. Run /book:start to initialise."; exit 0; }
[ -f .book/workflow.md ] || {
  echo "No workflow.md. Defaults will apply, but /book:next is more accurate with a workflow."
  echo "Run /book:research-genre <genre> or accept the built-in popular-science preset."
}

# Parse flags
EXECUTE=0
EXPLAIN=0
FROM_BLOCK=""
for arg in $ARGUMENTS; do
  case "$arg" in
    --execute)        EXECUTE=1 ;;
    --explain)        EXPLAIN=1 ;;
    --from-block=*)   FROM_BLOCK="${arg#--from-block=}" ;;
    *)                : ;;
  esac
done
```

### Step 2 — Read state (rule-based core inputs)

```bash
# Current section from STATE.md
CURRENT_SECTION=$(awk -F: '/^- `current_section`/ { gsub(/[ `]/, "", $3); print $3; exit }' .book/STATE.md)
[ -z "$CURRENT_SECTION" ] && CURRENT_SECTION="unknown"

LAST_ACTION=$(awk -F: '/^- `last_action`/ { sub(/^[^:]*:[^:]*: */, ""); print; exit }' .book/STATE.md)

# Last touched timestamp (for the "long break" heuristic)
LAST_TOUCHED=$(awk -F: '/^- `last_touched_at`/ { sub(/^[^:]*:[^:]*: */, ""); print; exit }' .book/STATE.md)

# Section directory listing
SECTION_DIRS=$(find .book/sections -maxdepth 1 -type d -name 'section-*' 2>/dev/null | sort)
```

### Step 3 — Apply Decision Tree (rule-based)

Apply the 5 navigation branches from `next-design.md` § 2. Pseudocode:

```
if INGEST-DECISIONS.md has unresolved V-items:
    RECOMMENDATION = "/book:resolve V-XX"
    REASON = "$N unresolved competing variants from /book:import."
    return

if last_touched > 14 days ago:
    RECOMMENDATION = "/book:resume"
    REASON = "Last session was N days ago. Resume first to refresh context."
    return

case CURRENT_SECTION:
    "unknown" | "":
        if no section dirs and no ROADMAP.md:
            RECOMMENDATION = "/book:plan-book"
            REASON = "Book just initialised. Plan the sections list first."
        else:
            RECOMMENDATION = "/book:status"
            REASON = "State unclear. Check status to see where we are."
    "book_level":
        if all book_level blocks done:
            RECOMMENDATION = "/book:plan-section 1"
            REASON = "Book-level done. Move into section loop."
        elif pending gate awaiting_author:
            RECOMMENDATION = "respond at the gate"
            REASON = "Author gate <gate-name> is pending. Approve / revise."
        elif failed block:
            RECOMMENDATION = "/book:debug" or "investigate STATE.md"
            REASON = "Block <X> failed. Investigate before proceeding."
        else:
            FIRST_PENDING = first pending book_level block
            if all requires done:
                RECOMMENDATION = block_to_command(FIRST_PENDING)
                REASON = "Next pending book_level block is <X>."
            else:
                RECOMMENDATION = block_to_command(unresolved-require)
                REASON = "Block <X> requires <Y>. Run <Y> first."
    "section_loop":
        determine current_section (first section without summary.md)
        if no sections started:
            RECOMMENDATION = "/book:plan-section 1"
        elif section has spec.md but no draft.md:
            RECOMMENDATION = "/book:write-section <N>"
        elif section has draft.md but no edited.md:
            RECOMMENDATION = "/book:write-section <N>  (resumes from factcheck-post)"
        elif section has edited.md but no summary.md:
            RECOMMENDATION = "/book:write-section <N>  (finalises)"
        elif section has summary.md (section complete):
            if last section and ROADMAP indicates more sections:
                RECOMMENDATION = "/book:plan-section <N+1>"
            elif all sections done:
                CURRENT_SECTION = "post_book"   # promote
                RECOMMENDATION = "/book:audit-book"
    "post_book":
        first pending post_book block (audit-book, ship)
        RECOMMENDATION = block_to_command(...)
```

The mapping table is in `next-design.md` § 3. Implementation reuses helpers in `bookbench/lib/` (the parser is small enough to inline here).

### Step 4 — (Optional) `--from-block <name>` what-if

If `--from-block` was passed, ignore the actual current state and assume `<name>` was just completed; re-run the tree from that state. Useful for «what if I skipped to block X?».

### Step 5 — Compose explanation (LLM-augmented)

For the default mode, format as:

```
Recommended next: <RECOMMENDATION>

Why: <REASON> (one to three lines).
```

With `--explain`, optionally invoke `book-coordinator` via `Task` to expand the explanation. Pass the rule-based RECOMMENDATION and REASON as inputs; the coordinator writes a richer 8–12 line block adding alternatives. Per `next-design.md` § 8.1, the LLM never overrides the rule-based decision — it only fills the explanation template.

```
Task(
  subagent_type: book-coordinator,
  description: "Explain the /book:next recommendation",
  prompt: """
    The rule-based engine recommends: <RECOMMENDATION>
    Reason: <REASON>
    Current state summary: <STATE>
    Use the Decision Tree pattern (Part V of methodology guide) to expand this
    into a 5-12 line explanation with up to 2 alternatives. Do NOT override the
    recommendation; you are filling a template.
  """,
  files_to_read: [
    .book/STATE.md,
    .book/workflow.md,
    .book/ROADMAP.md (if exists),
    .book/sections/*/section-state.yaml (compact: only the active section)
  ]
)
```

### Step 6 — (Optional) `--execute`

If `--execute` was passed:

- Print: `Executing: <RECOMMENDATION>`.
- Dispatch the recommended command. Implementation note: in Claude Code commands cannot directly invoke other slash commands. Instead, the orchestrator runs the equivalent inline body OR returns a clear final message that asks the author to run it. For stage 14, this command is allowed to **describe** the dispatch but the actual execution is the author's responsibility — the rule-based recommendation IS the contract.

For stage 15+, when slash-command nesting is verified in Claude Code 2.x, this step will dispatch the command directly.

### Step 7 — STATE.md history append

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '\n%s — `/book:next` — recommended: %s (reason: %s)\n' \
  "$NOW" "$RECOMMENDATION" "$REASON" >> .book/STATE.md
```

### Step 8 — Next-step message

For default mode:

```
Recommended next: <RECOMMENDATION>

Why: <REASON>

To run it now:           <RECOMMENDATION>
To see full reasoning:   /book:next --explain
To see overall status:   /book:status
```

For `--execute` mode (stage 15+ feature):

```
Executing: <RECOMMENDATION>...

[output of the dispatched command]
```

### Constitutional rules

- **MUST** be deterministic in the rule-based core — same state must yield same recommendation.
- **MUST** never override the rule-based decision via the LLM-augmentation step (that step only fills the explanation).
- **MUST** detect long breaks (>14 days) and recommend `/book:resume` first.
- **NEVER** edit `workflow.md`, `section-state.yaml`, or `sections/` content.
- **NEVER** invoke writer / factchecker / editor — only at most `book-coordinator` for explanation expansion.

</execution>
