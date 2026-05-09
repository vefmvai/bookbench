---
name: tune:workflow
description: Two-step tuner for the per-book workflow.md. First call analyses STATE timestamps, skipped blocks, repeated discussion notes and rejection logs to surface workflow-level patterns (replace block, add cross-cutting check, change parameters). Second call apply <id> applies a specific proposal to .book/workflow.md after a YAML round-trip parse, records the apply in TUNING-LOG with mode workflow and approved_by author. Higher risk than guideline tuning — extra confirmation gate before apply.
argument-hint: "[apply <id>] [reject <id>] [--lookback <N>] [--severity-threshold low|medium|high]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Task, AskUserQuestion]
---

# /book:tune:workflow

<purpose>
Tune the per-book workflow.md. Pattern detection looks at structural signals
(skipped blocks, repeated revise-loops, time-overruns, requested new blocks)
and proposes edits to `.book/workflow.md`. Apply is gated by an extra
confirmation step — workflow changes have cascading effects on next chapters.
</purpose>

<!-- Stage 14, Wave B, T4: full implementation. -->

## Step 1 — Parse arguments

```bash
RAW="${ARGUMENTS:-}"
SUBACTION=""
PROPOSAL_ID=""
LOOKBACK="5"
SEVERITY_THRESHOLD="low"

set -- $RAW
case "${1:-}" in
  apply)  SUBACTION="apply";  shift; PROPOSAL_ID="${1:-}"; [ -n "$PROPOSAL_ID" ] && shift ;;
  reject) SUBACTION="reject"; shift; PROPOSAL_ID="${1:-}"; [ -n "$PROPOSAL_ID" ] && shift ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --lookback)            LOOKBACK="$2"; shift ;;
    --severity-threshold)  SEVERITY_THRESHOLD="$2"; shift ;;
    *) echo "tune:workflow: unknown flag '$1'" 1>&2 ;;
  esac
  shift
done
echo "tune:workflow: subaction='$SUBACTION' proposal_id='$PROPOSAL_ID' lookback=$LOOKBACK threshold=$SEVERITY_THRESHOLD"
```

## Step 2 — Pre-flight

```bash
[ -d .book ] || { echo "tune:workflow: no .book/ folder. Run /book:start first."; exit 0; }
[ -f .book/workflow.md ] || {
  echo "tune:workflow: .book/workflow.md missing — workflow management requires it."
  exit 0
}
[ -f .book/STATE.md ] || {
  echo "tune:workflow: .book/STATE.md missing — workflow tuning relies on STATE timestamps."
  exit 0
}
mkdir -p .book/.tune
touch .book/TUNING-LOG.md .book/REJECTIONS-LOG.md
```

## Dispatch

Empty `SUBACTION` → analysis (Step 4W..7W). Else jump to the matching branch.

---

## Step 4W — Analysis: invoke book-tuner in workflow mode

```text
Task(
  subagent_type="book-tuner",
  prompt="""
  Run /book:tune:workflow in analyse mode (UX-09 step 1, mode=workflow).

  Inputs to read:
    - .book/workflow.md
    - .book/STATE.md (timestamps for blocks, gates, revise-loops)
    - .book/REJECTIONS-LOG.md
    - .book/TUNING-LOG.md  (filter out previously-rejected workflow proposals)
    - .book/chapters/*/discussion.md (for "requested new block" mentions)
    - .book/.claude/agent-memory/tuner/MEMORY.md (for cooldown checks)

  Lookback: last ${LOOKBACK} chapters (parameterisable via --lookback).
  Severity threshold: ${SEVERITY_THRESHOLD}.

  Workflow-mode specific signals (per workflow-evolution-design.md § 2.2):
    1. Skipped blocks      — block X was in workflow.md but author skipped it >= 3 times.
    2. Requested new blocks — author asked "let's also check Y" >= 3 times in chapter discussions or rejections.
    3. Block duration outliers — block X took N times longer than planned (timestamps in STATE).
    4. Revise-loop frequency — chapter N triggered re-discuss / re-edit-chapter several times.
    5. Cross-cutting trigger misfires — cross-cutting block did not run when its trigger said it should.

  Procedure: TUNE adapted for workflow:
    Phase 1 — collect signals from sources above
    Phase 2 — cluster (>= 3 occurrences across the lookback window)
    Phase 3 — prioritise:
              critical = blocker for next chapter (e.g. workflow contains a block author always skips)
              important = causes revise-loops but not blockers
              optional = stylistic / convenience improvements
    Phase 4 — write proposal entries to TUNING-LOG.md with status: proposed and mode: workflow.
              Each proposal MUST include an `impact` block in `rationale_full` modelling
              the effect on the next 3 chapters' chapter_loop.

  Output to caller:
    - Markdown report with the five sections from book-tuner.md Procedure §15.
    - List of new proposal ids (`tun-NNNN`) with severity and per-proposal impact summary.

  Constitution reminders (extra-strict for workflow):
    - Never propose a workflow change from < 3 occurrences.
    - Never propose a change that would orphan a gate or remove a required cross-cutting block.
    - Never propose a structural rewrite of workflow.md ("rewrite from scratch") — only targeted edits.
  """,
  description="Analyse workflow-level signals and propose .book/workflow.md edits via book-tuner."
)
```

## Step 5W — Persist the snapshot

```bash
TS="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
SNAPSHOT=".book/.tune/$TS-workflow-suggestions.md"
echo "tune:workflow: snapshot at $SNAPSHOT"
```

The model writes the report to `$SNAPSHOT`.

## Step 6W — Extra-strict author gate

Workflow changes are higher-risk than guideline changes. Use AskUserQuestion
with **two** confirmations for apply:

1. First gate — show the proposal + the impact block (modelled effect on
   the next 3 chapters):
   - `Continue to apply confirmation`
   - `Reject (cooldown)`
   - `Save and exit`

2. If `Continue to apply confirmation` — second gate:
   - `Yes, apply tun-NNNN to .book/workflow.md`
   - `Show me the diff one more time`
   - `Cancel`

Only after both confirmations dispatch into Step 7W-Apply.

## Step 7W-Apply — Apply a workflow proposal

1. Read `.book/TUNING-LOG.md`; locate proposal with
   `id == $PROPOSAL_ID && mode: workflow && status: proposed`.
2. **Backup** `.book/workflow.md` to `.book/.backup/workflow-$TS.md`.
3. Apply the diff (Edit with old_string / new_string from `diff_summary`).
4. **Round-trip parse**: read the updated `.book/workflow.md` and validate
   that:
   - YAML frontmatter parses (if present);
   - all top-level keys (`bookbench_version`, `book_level`, `chapter_loop`,
     `cross_cutting`, `post_book`) are still present;
   - block name structure is intact (every `block:` has a `name:` and every
     `gate:` has `on_approve:` / `on_revise:`).
5. If parse fails — restore from `.book/.backup/workflow-$TS.md`, write to
   `.book/REJECTIONS-LOG.md` an entry
   `rejection_kind: tuner-apply-failed-yaml-parse`, and stop with an error
   message (do not retry automatically).
6. Update the TUNING-LOG.md record (flip `status: applied`, set
   `applied_at`, `approved_by: author`, `author_confirmed: true`).
7. Append to `agent-memory/tuner/MEMORY.md` `Applied tuning history`.

After apply:

```text
tune:workflow apply: applied tun-NNNN to .book/workflow.md.
Backup saved at .book/.backup/workflow-$TS.md.
YAML round-trip parse: OK.
Recorded in TUNING-LOG.md with mode: workflow, approved_by: author.
```

## Step 7W-Reject — Reject a workflow proposal

Same mechanics as `/book:tune:guidelines` Step 7G-Reject, but with
`mode: workflow` in the REJECTIONS-LOG entry. Cooldown duration defaults to
60 days for workflow (vs 30 for guidelines) — workflow changes are
higher-stakes and the author should not be re-asked too often.

## Notes

- The `tuning-workflow` skill (mentioned in `workflow-evolution-design.md`
  § 1.4) is realised as the workflow-mode prompt above. Skill-as-data files
  are not required in 0.1 because the body of `book-tuner.md` already
  contains the four-phase procedure; the workflow-mode prompt parameterises
  the inputs and the priority rules.
- The "round-trip parse" of `workflow.md` will be replaced by a richer
  `/book:workflow:check` invocation when that command lands in wave C
  (T6e). Until then, this inline parse is sufficient.
- Workflow tuning may be invoked manually by the author via
  `/book:tune:workflow` even when no automated signals exist — the author
  uses it as a pre-flight planning aid before changing chapter cadence.
