---
name: tune:guidelines
description: Two-step tuner that proposes guideline edits to .book/agent-guidelines/<role>/. First call analyses TUNING-LOG, REJECTIONS-LOG, and recent guideline diffs to produce proposals with severity tags. Second call (apply <id>) applies a specific proposal to the matching guideline file and records the apply in TUNING-LOG with approved_by author. Pattern detection via book-tuner with the four-phase procedure (collect, cluster, prioritise, propose). Minimum three occurrences required for a proposal.
argument-hint: "[apply <id>] [reject <id>] [--all] [--role <role>] [--since <date>]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Task, AskUserQuestion]
---

# /bookbench:tune:guidelines

<purpose>
Tune the per-book agent guidelines. Two-step flow: analyse to surface
proposals (Step 4G), then `apply <id>` to materialise a specific edit on
disk. Never edits agent bodies (those are templates), only guideline files.
</purpose>

<!-- Stage 14, Wave B, T4: full implementation. -->

## Step 1 — Parse arguments

```bash
RAW="${ARGUMENTS:-}"
SUBACTION=""
PROPOSAL_ID=""
ROLE_FILTER=""
SINCE=""
ALL=0

set -- $RAW
case "${1:-}" in
  apply)  SUBACTION="apply";  shift; PROPOSAL_ID="${1:-}"; [ -n "$PROPOSAL_ID" ] && shift ;;
  reject) SUBACTION="reject"; shift; PROPOSAL_ID="${1:-}"; [ -n "$PROPOSAL_ID" ] && shift ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --all)    ALL=1 ;;
    --role)   ROLE_FILTER="$2"; shift ;;
    --since)  SINCE="$2"; shift ;;
    *) echo "tune:guidelines: unknown flag '$1'" 1>&2 ;;
  esac
  shift
done
echo "tune:guidelines: subaction='$SUBACTION' proposal_id='$PROPOSAL_ID' role='$ROLE_FILTER' since='$SINCE' all=$ALL"
```

## Step 2 — Pre-flight

```bash
[ -d .book ] || { echo "tune:guidelines: no .book/ folder. Run /bookbench:start first."; exit 0; }
[ -d .book/agent-guidelines ] || {
  echo "tune:guidelines: .book/agent-guidelines/ missing — your book installation may be corrupt."
  exit 0
}
mkdir -p .book/.tune
touch .book/TUNING-LOG.md .book/REJECTIONS-LOG.md
```

## Step 3 — Resolve plugin root (for skill loading)

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && {
  for c in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    [ -f "$c/manifest.json" ] && PLUGIN_ROOT="$c" && break
  done
}
echo "tune:guidelines: plugin_root=$PLUGIN_ROOT"
```

## Dispatch on subaction

If `SUBACTION` is empty → run analysis (Step 4G..7G). Otherwise jump to the
appropriate apply / reject branch.

---

## Step 4G — Analysis: invoke book-tuner

The model issues a Task call with `subagent_type: book-tuner` (whose body is
`bookbench/agent-templates/book-tuner.md`). The Task prompt embeds the
analyse-only mode and the four-phase procedure from the body, with the
inputs collected from the book.

```text
Task(
  subagent_type="book-tuner",
  prompt="""
  Run /bookbench:tune:guidelines in analyse mode (UX-09 step 1).

  Inputs to read:
    - .book/TUNING-LOG.md
    - .book/REJECTIONS-LOG.md
    - .book/agent-guidelines/**/*.md  (every role folder, including its README)
    - .book/.claude/agent-memory/tuner/MEMORY.md
    - .book/agent-guidelines/tuner/sensitivity-thresholds.md (if present)

  Filters (apply if non-empty):
    - role:  ${ROLE_FILTER}
    - since: ${SINCE}
    - all:   ${ALL}

  Procedure: TUNE (4 phases per book-tuner body):
    Phase 1 — collect signals
    Phase 2 — cluster (>= 3 occurrences for a pattern)
    Phase 3 — prioritise (critical / important / optional, see body)
    Phase 4 — write proposal entries to TUNING-LOG.md with status: proposed

  Output to caller:
    - Markdown report with the five sections from book-tuner.md Procedure §15:
      Краткое резюме / Детальный анализ / Конкретные рекомендации /
      Проверка полноты / Apply commands.
    - List of new proposal ids (`tun-NNNN`) with one-line summaries.

  Constitution reminders:
    - Never edit guideline files directly (no Edit tool in your frontmatter).
    - Never call Task (no Task tool in your frontmatter — no cascade).
    - Never propose from < 3 occurrences.
    - Never re-propose patterns with permanent rejection or active cooldown.
  """,
  description="Analyse signals and propose guideline edits via book-tuner."
)
```

## Step 5G — Persist the snapshot

The Task return-value goes into `.book/.tune/<TS>-suggestions.md` for traceability.

```bash
TS="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
SNAPSHOT=".book/.tune/$TS-suggestions.md"
echo "tune:guidelines: snapshot at $SNAPSHOT"
```

The model uses Write to save the markdown report at `$SNAPSHOT`.

## Step 6G — Author gate

Use AskUserQuestion to present the top three proposals (sorted by severity,
critical first) with a multi-select:

- `Apply tun-NNNN` (per-proposal action)
- `Apply all critical`
- `Reject tun-NNNN` (records cooldown)
- `Save and exit` (default)

If the user picks Apply for a specific id, dispatch into Step 7G-Apply.
If the user picks Reject, dispatch into Step 7G-Reject.
If Save and exit, end with the next-step message.

## Step 7G-Apply — Apply a proposal

The exact mechanics mirror `tune.md` Step 2A. Recap of the steps the model
takes here:

1. Read `.book/TUNING-LOG.md`; locate proposal where `id == $PROPOSAL_ID`
   and `status: proposed`.
2. For each entry in `files_changed`:
   - `append` → Edit (or Write if missing) to append the diff content.
   - `replace` → Edit with the diff's old/new pair, preserving indentation.
   - `delete-section` → Edit removing the section verbatim.
3. Update the TUNING-LOG.md record:
   - flip `status: applied`,
   - set `author_confirmed: true`, `approved_by: author`,
   - set `applied_at: <ISO now>`.
4. Append to `.book/.claude/agent-memory/tuner/MEMORY.md` under
   `Applied tuning history`: a one-line entry
   `- tun-NNNN | <ISO> | <role> | <signal_pattern>`.

After apply:

```text
tune:guidelines apply: applied tun-NNNN to <path>.
Recorded in TUNING-LOG.md with approved_by: author.
```

## Step 7G-Reject — Reject a proposal (cooldown)

The model:

1. Reads the proposal from `.book/TUNING-LOG.md`.
2. Updates the record: `status: rejected`, `rejected_at: <ISO now>`.
3. Appends to `.book/REJECTIONS-LOG.md`:

   ```yaml
   - id: rej-NNNN
     timestamp: <ISO>
     rejection_kind: tuner-suggestion
     rejection_type: author-rejected
     proposal_id: tun-NNNN
     role: <role>
     mode: guidelines
     rationale: "<author note from AskUserQuestion follow-up>"
     source: author
   ```

4. Updates `agent-memory/tuner/MEMORY.md`:
   - under `Rejected tuning suggestions` — increment `rejection_count_total` for
     this `signal_pattern`;
   - under `Cooldown timers` — set cooldown until
     `<now> + cooldown_days_default (30 by default)`.
   - if `rejection_count_total >= permanent_after_rejections (3)`, mark the
     pattern as `permanent_rejected: true`.

After reject:

```text
tune:guidelines reject: rejected tun-NNNN; cooldown set for 30 days.
After 3 rejections of the same signal pattern, the tuner will skip it permanently.
```

## Notes

- The `tuning-guidelines` skill referenced in `workflow-evolution-design.md`
  § 1.4 is realised here as the analyse-mode prompt of `book-tuner`. The
  body already contains the 4-phase procedure and DEC-08 priority resolution.
- `disallowedTools: Task` on `book-tuner` — structural guarantee no cascade
  (DEC-10). The apply / reject side-effects are performed by **this command**,
  not by the tuner agent.
- The two-step pattern (analyse → apply) is UX-09. Apply is always a
  deliberate, separate user action.
