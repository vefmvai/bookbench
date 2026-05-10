---
description: Universal launcher for any block in workflow.md by name. Validates the block name against bookbench/blocks-catalog.md, picks the right executor (internal block logic vs. subagent delegation), and runs it. Used for atomic blocks that have no dedicated wrapper command (e.g. worldbuilding-init, methodology-research, ethical-review-init). UX-02 from stage 7.2.
argument-hint: "<block-name> [--section <N>] [--params <key=value>...]"
allowed-tools: [Read, Write, Edit, Bash, Glob, Task, AskUserQuestion]
---

# /bookbench:run

<purpose>
Generic block runner. Bridges the gap between «I want to run this specific block» and the curated wrappers (`/bookbench:plan-book`, `/bookbench:write-section`, etc.). For most popular blocks there is a dedicated command; `/bookbench:run` covers everything else in the catalog.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный дизайн — UX-02 в `tradeoffs-and-decisions.md` этапа 7.2 -->

## Inputs

- `<block-name>` — required. Must match a block in `${CLAUDE_PLUGIN_ROOT}/blocks-catalog.md`.
- `--section <N>` — optional, for section-scoped blocks.
- `--params <key=value>...` — optional parameter overrides.
- `${CLAUDE_PLUGIN_ROOT}/blocks-catalog.md` — block registry.
- `.book/workflow.md` — current book workflow (read for parameter defaults).
- `.book/config.yaml` — read for genre / language defaults.

## Outputs

- Side effects of the dispatched block (varies per block).
- A `STATE.md` history line.
- For blocks with `internal_logic_owner: <subagent>`, the subagent writes its own artefacts.

<execution>

Eight-step orchestrator. Most of the work is dispatch — the actual block logic is owned by the matching subagent or by an inline procedure.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory. Run /bookbench:start first."; exit 0; }

# Parse arguments
BLOCK_NAME=""
SECTION_N=""
PARAMS=""
for arg in $ARGUMENTS; do
  case "$arg" in
    --section=*)  SECTION_N="${arg#--section=}" ;;
    --params=*)   PARAMS="${arg#--params=}" ;;
    --*)          : ;;
    *)            [ -z "$BLOCK_NAME" ] && BLOCK_NAME="$arg" ;;
  esac
done

if [ -z "$BLOCK_NAME" ]; then
  echo "Error: /bookbench:run requires a block name."
  echo "Usage: /bookbench:run <block-name> [--section <N>] [--params key=value...]"
  echo "See $CLAUDE_PLUGIN_ROOT/blocks-catalog.md for the full list."
  exit 0
fi
```

### Step 2 — Validate block name against catalog

Read `${CLAUDE_PLUGIN_ROOT}/blocks-catalog.md` and confirm `<BLOCK_NAME>` is a registered block. If not — emit fuzzy suggestion:

```
Error: block '<BLOCK_NAME>' not found in catalog.

Did you mean:
  • <closest-match-1>
  • <closest-match-2>

See $CLAUDE_PLUGIN_ROOT/blocks-catalog.md for the full list.
```

If found, extract its metadata: `executor`, `internal_logic_owner` (if procedure), `inputs`, `outputs`, `params` (with defaults), `scope` (book / section / cross-cutting).

### Step 3 — Validate scope

If the block is section-scoped but `--section <N>` was not passed:

- If `STATE.md` has an active `current_section` — use that.
- Otherwise, ask via `AskUserQuestion`: «Which section for `<BLOCK_NAME>`?».

If the block is book-scoped, ignore `--section`.

### Step 4 — Show plan + confirmation gate

Present an `AskUserQuestion`:

- Title: «Run block `<BLOCK_NAME>`?»
- Body:
  - `executor: <executor>` (e.g. `book-strategist` or `inline`)
  - `inputs: <list>`
  - `outputs: <list>`
  - `params: <merged from defaults + overrides>`
  - `scope: <book | section <N> | cross-cutting>`
- Options:
  - `Run` — proceed.
  - `Show details` — print full block spec from catalog and re-ask.
  - `Cancel` — exit.

This is the Brief-Then-Execute pattern from Part VII of the methodology guide.

### Step 5 — Dispatch

Two cases:

**Case A — `executor: <subagent>` and `internal_logic_owner: <subagent>` (procedure block):**

The subagent owns the internal logic. Invoke it via `Task`:

```
Task(
  subagent_type: <executor>,
  description: "Run block <BLOCK_NAME>",
  prompt: """
    You are <executor> running block '<BLOCK_NAME>' from the catalog.
    Block contract:
      inputs:  <list>
      outputs: <list>
      params:  <merged>

    Read the input files, perform the block's logic per your Procedure for
    this block (defined in your system prompt), write outputs to disk.
    Do NOT exceed your role — for example, the strategist never writes
    section draft.md.
  """,
  files_to_read: <inputs from catalog>
)
```

**Case B — atomic block (one shot, no subagent):**

Inline action via `Read`/`Write`/`Edit`/`Glob`/`Grep`/`Bash`. Examples:

- `recall` — read recent section summaries; write a digest.
- `cross-reference-check` — grep glossary terms across sections; report inconsistencies.
- `summary-update` — write `sections/<N>/summary.md` based on `edited.md`.
- `registry-update` — re-build `section-registry.md` from `sections/`.

For atomic blocks the orchestrator carries the implementation; the catalog notes which kind a block is.

### Step 6 — Verify outputs

Re-read each declared output from disk. Confirm that the file exists and is non-empty (or, for blocks that update an existing file, that the modification timestamp is fresh).

### Step 7 — STATE.md history append

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SCOPE_LABEL="book"
[ -n "$SECTION_N" ] && SCOPE_LABEL="section $SECTION_N"
printf '\n%s — `/bookbench:run %s` — block ran for %s\n' \
  "$NOW" "$BLOCK_NAME" "$SCOPE_LABEL" >> .book/STATE.md
```

### Step 8 — Next-step message

```
Block <BLOCK_NAME> done.
Outputs: <list>

Recommended next:
  /bookbench:next        — see what to do next.
  /bookbench:status      — see overall progress.
```

### Constitutional rules

- **MUST** validate the block name against the catalog before executing.
- **MUST** confirm with the author before executing (Brief-Then-Execute, Part VII methodology).
- **MUST** keep block logic in the catalog or in the subagent — the orchestrator only dispatches.
- **NEVER** invent block names or invent block parameters not in the catalog.
- **NEVER** chain multiple blocks in one invocation — one block per `/bookbench:run` call.
- **NEVER** override a wrapper command — for blocks with dedicated commands (`/bookbench:plan-book` for `book-plan`, etc.), recommend the wrapper instead of running the block directly.

</execution>
