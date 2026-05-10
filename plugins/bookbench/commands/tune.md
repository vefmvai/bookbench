---
description: Runs book-tuner to analyse TUNING-LOG, REJECTIONS-LOG and recent guideline edits, then proposes guideline changes systemising repeated author corrections. Without an explicit subform routes to /bookbench:tune:guidelines (UX-08 default). The apply subform applies a single suggestion identified by its proposal id and records the apply in TUNING-LOG.md with approved_by author and applied_at timestamp.
argument-hint: "[apply <id>] [--all] [--role <role>] [--since <date>]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Task, AskUserQuestion]
---

# /bookbench:tune

<purpose>
Local tuning loop: detect repeated rejection patterns and turn them into
actionable guideline edits. The tuner only proposes; `/bookbench:tune apply <id>`
is required to write. UX-08: bare `/bookbench:tune` is an alias that defaults to
`/bookbench:tune:guidelines`. Use `/bookbench:tune:workflow` explicitly to tune
`workflow.md` blocks instead of guideline files.
</purpose>

<!-- Stage 14, Wave B, T4: full implementation. -->

## Forms

- `/bookbench:tune` — alias to `/bookbench:tune:guidelines` (UX-08).
- `/bookbench:tune apply <id>` — apply a specific proposal that was previously
  written to TUNING-LOG with `status: proposed`.
- `/bookbench:tune:guidelines` — analyse signals, propose edits to
  `.book/agent-guidelines/<role>/<file>.md`. Two-step: analyse → apply.
- `/bookbench:tune:workflow` — analyse signals, propose edits to `.book/workflow.md`.
  Higher-risk; requires extra confirmation.

## Step 1 — Parse arguments and dispatch

```bash
RAW="${ARGUMENTS:-}"
set -- $RAW
SUB="${1:-}"

# Apply-form detection: /bookbench:tune apply <id>
if [ "$SUB" = "apply" ]; then
  shift
  PROPOSAL_ID="${1:-}"
  [ -z "$PROPOSAL_ID" ] && {
    echo "Usage: /bookbench:tune apply <proposal-id>"
    echo "Find proposal ids with /bookbench:tune (analyse first, then apply)."
    exit 0
  }
  echo "tune: routing to apply mode with id=$PROPOSAL_ID"
  # Continue to Step 2A below.
else
  # Bare /bookbench:tune (no subform) — UX-08 alias to /bookbench:tune:guidelines.
  echo "tune: no explicit subform; defaulting to /bookbench:tune:guidelines (UX-08)."
  echo "tune: forwarding original arguments to guidelines analysis."
  # Re-dispatch by reading and executing the body of tune-guidelines.md.
  # Continue to Step 2G below.
fi
```

## Step 2A — Apply mode

### Pre-flight

```bash
[ -d .book ] || { echo "tune apply: no .book/ folder. Run /bookbench:start first."; exit 0; }
[ -f .book/TUNING-LOG.md ] || {
  echo "tune apply: .book/TUNING-LOG.md missing. Nothing to apply."
  exit 0
}
```

### Locate the proposal

The model uses the Read tool on `.book/TUNING-LOG.md`, then locates the entry
where `id == $PROPOSAL_ID` and `status == proposed`. If not found:

```text
tune apply: proposal $PROPOSAL_ID not found in .book/TUNING-LOG.md, or its
status is no longer `proposed` (it may already be applied, rejected, or it
may not exist). Run /bookbench:tune to refresh proposals.
```

### Read full proposal record

The proposal record contains:

```yaml
- id: tun-NNNN
  timestamp: <ISO>
  role: <role>
  mode: guidelines | workflow
  trigger:
    type: tuner-suggestion
    suggestion_id: P-<NN>
  files_changed:
    - path: .book/agent-guidelines/<role>/<file>.md
      change_type: append | replace | delete-section
      lines_added: <N>
      lines_removed: <M>
  reason: "<≤200 chars>"
  diff_summary: |
    <concrete proposed diff>
  status: proposed
  source: tuner-suggestion
  author_confirmed: false
  severity: critical | important | optional
  rationale_full: |
    <≤500 chars>
```

### Apply the diff

For each file in `files_changed`:

- `append` → use the Edit tool to append the new content at the file end (or
  use Write if the file does not exist yet, with the proposal's `diff_summary`
  as full content).
- `replace` → use Edit with `old_string` and `new_string` derived from the
  diff hunks in `diff_summary`. Preserve indentation exactly.
- `delete-section` → use Edit with the `old_string` set to the full section
  block (including header) and `new_string` empty.

For `mode: workflow` proposals — open `.book/workflow.md` and apply the same
transformation, but **also** run a YAML round-trip parse of the resulting
file to confirm it still parses. If the round-trip fails, abort the apply
and write a record to `.book/REJECTIONS-LOG.md` with
`rejection_kind: tuner-apply-failed-yaml-parse`.

### Update TUNING-LOG.md

Replace the original proposal record. New record:

```yaml
- id: tun-NNNN          # same id
  timestamp: <ISO original>
  applied_at: <ISO now>
  role: <role>
  mode: <mode>
  trigger:
    type: tuner-suggestion
    suggestion_id: P-<NN>
  files_changed:
    - path: .book/agent-guidelines/<role>/<file>.md
      change_type: append
      lines_added: <N>
      lines_removed: <M>
  reason: "<≤200 chars>"
  diff_summary: |
    <concrete diff>
  status: applied         # status flipped
  source: tuner-suggestion
  author_confirmed: true  # `apply` requires explicit author action
  approved_by: author
  severity: critical | important | optional
  rationale_full: |
    <≤500 chars>
```

### Update agent-memory/tuner

Append to `.book/.claude/agent-memory/tuner/MEMORY.md`:

- under `Applied tuning history` — a one-line entry
  `- tun-NNNN | <ISO> | <role> | <signal_pattern>`.
- under `Cooldown timers` — clear any cooldown that this signal_pattern
  may have had (since the apply replaces a previous rejection).

### Done message

```text
tune apply: applied $PROPOSAL_ID to <files_changed[*].path>.
Recorded in TUNING-LOG.md with approved_by: author and applied_at timestamp.
```

End of apply mode.

## Step 2G — Default to guidelines analysis

When `/bookbench:tune` was invoked without `apply` and without an explicit subform,
forward to `/bookbench:tune:guidelines` by reading the body of
`${CLAUDE_PLUGIN_ROOT}/commands/tune-guidelines.md` and executing it with
the original arguments preserved.

```bash
GL_CMD="${CLAUDE_PLUGIN_ROOT:-/dev/null}/commands/tune-guidelines.md"
[ -f "$GL_CMD" ] || GL_CMD="${CLAUDE_PLUGIN_ROOT:-/dev/null}/commands/tune:guidelines.md"
[ -f "$GL_CMD" ] || {
  echo "tune: alias target tune-guidelines.md not found in plugin root."
  echo "Falling back to inline guidelines analysis (see book-tuner agent body)."
}
echo "tune: dispatching guidelines analysis (UX-08 alias)."
```

The model then loads `tune-guidelines.md` and continues as if the user had
typed `/bookbench:tune:guidelines` with the same flags. End of dispatch.

## Notes

- `book-tuner` has `disallowedTools: [Edit, Bash, WebSearch, WebFetch, Task]`
  in its frontmatter (DEC-10) — it can only Write **new** proposal entries
  to TUNING-LOG.md, never directly edit guideline files. The actual edit on
  apply happens here, in this command, where Edit is allowed.
- The two-step (analyse → apply) flow is UX-09. The author always sees the
  proposal first; `apply` is a separate, deliberate step.
- Symbol convention: proposal ids follow the pattern `tun-NNNN` (zero-padded
  4-digit sequence). The internal `suggestion_id: P-<NN>` is the tuner's
  per-session label and does not persist between sessions.
