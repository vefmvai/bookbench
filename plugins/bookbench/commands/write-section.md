---
description: Запускает полный микро-цикл раздела N через цепочку субагентов — book-strategist (ТЗ), book-writer (драфт), book-factchecker с циклом ревизий до трёх итераций, book-editor (редактура), опциональные skill-проверки, опциональный book-marketer, финализация координатором. Автор подтверждает только два шлюза: одобрение ТЗ (spec-gate) и финальное принятие раздела; остальное автоматизировано через файловый протокол передачи артефактов.
argument-hint: "<section-number> [--on-completed re-write|re-edit|abort|ask]"
allowed-tools: [Task, Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
on_completed: ask
---

# /bookbench:write-section

<purpose>
The thickest command of the framework. Drives the whole 5+1 phase pipeline for one section. Atomic re-runs of one phase are available via the four `:phase` subcommands.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже; ЭТАП 14 финализирует логику координатора -->

## Inputs

- `<section-number>` (positional).
- `--on-completed` (optional, default `ask`): action when section is already `completed: true`. Values: `re-write`, `re-edit`, `abort`, `ask`. Closes OQ-19.
- Existing `sections/<id>/spec.md` (created by `/bookbench:plan-section`).
- `.book/context/`, `.book/agent-guidelines/<role>/`, all relevant `agent-memory/<role>/MEMORY.md`.
- Previous sections' `summary.md` (per per-role context budget — see `context-control.md`).

## Outputs

- `.book/sections/<id>/draft.md`, `factcheck.md`, `edited.md`, `marketing.md` (if marketer enabled), `summary.md`.
- Updates to five role MEMORY.md files.
- Updates to `.book/STATE.md` and `sections/<id>/section-state.yaml`.

## Behaviour

- The section micro-cycle is implemented as block `section-loop` (block 31 in `blocks-catalog.md`).
- Author gates run at `[spec, approval]` by default; configurable via `workflow.md > section_loop.gates`.
- `factcheck_max_iterations = 3` by default (DEC-03); on hit the coordinator runs ESCALATE-flow and writes to `REJECTIONS-LOG.md`.
- The anti-AI-cliche hook (`templates/hooks/anti-ai-cliche-lint.sh`) runs PostToolUse on writer and editor writes.

## on_completed parameter (closes OQ-19)

When the user invokes `/bookbench:write-section <N>` for a section whose `section-state.yaml.completed` is `true`, behaviour follows `on_completed`:

| Value | Behaviour |
|-------|-----------|
| `ask` (default) | Coordinator presents an `AskUserQuestion`: re-write, re-edit, abort. |
| `re-write` | Backs up `edited.md` to `<artifact>-prev-<ts>.md` and re-runs the full pipeline. |
| `re-edit` | Re-runs Phase 4 (Editor) only, equivalent to `/bookbench:write-section:edit <N>`. |
| `abort` | Exits with a notice; no changes made. |

The same parameter is mirrored in `section-loop-block.md` for consistency.

## Recovery from a failed phase

Use the atomic subcommands:

- `/bookbench:write-section:draft <N>` — re-run only writer.
- `/bookbench:write-section:factcheck <N>` — re-run only factchecker (with loop).
- `/bookbench:write-section:edit <N>` — re-run only editor.
- `/bookbench:write-section:market <N>` — re-run only marketer.

<execution>

This is the heaviest command of the framework. It implements `Procedure WRITE-SECTION` from `agent-templates/book-coordinator.md` plus block 31 `section-loop` from `blocks-catalog.md`. The 8-step orchestrator pattern is wrapped around 9 phase steps (5 phases + skill-mode + marketer + finalise + gate).

### Step 1 — Parse arguments

```bash
ARG="$ARGUMENTS"
[ -z "$ARG" ] && { echo "Usage: /bookbench:write-section <section-number> [--on-completed re-write|re-edit|abort|ask]"; exit 0; }

# Default
ON_COMPLETED="ask"

# Extract section number — first run of digits in $ARGUMENTS
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g' | head -c 4)

# Parse --on-completed flag (substring match — $ARGUMENTS arrives as a single string)
case "$ARG" in
  *--on-completed=re-write*|*--on-completed\ re-write*) ON_COMPLETED=re-write ;;
  *--on-completed=re-edit*|*--on-completed\ re-edit*)   ON_COMPLETED=re-edit ;;
  *--on-completed=abort*|*--on-completed\ abort*)       ON_COMPLETED=abort ;;
  *--on-completed=ask*|*--on-completed\ ask*)           ON_COMPLETED=ask ;;
esac
[ -z "$N" ] && { echo "Section number must be an integer ≥ 1."; exit 0; }
PADDED=$(printf '%03d' "$N")
SECDIR=".book/sections/section-${PADDED}"
echo "N=$N PADDED=$PADDED SECDIR=$SECDIR ON_COMPLETED=$ON_COMPLETED"
```

### Step 2 — Resolve plugin paths and book context

Run the same `PLUGIN_ROOT`/`PLUGIN_DATA`/`PLUGIN_VERSION` resolver as `/bookbench:start` Step 2. Read `.book/config.yaml` to detect:

- `agents.enabled` — whether marketer is in the list.
- `agents.loop_limits.factchecker_writer_revise` (default 3, DEC-03).
- `quality_gates.min_factcheck_pass_rate`.

### Step 3 — Pre-flight checks

```bash
[ -d .book ] || { echo "No .book/. Run /bookbench:start."; exit 0; }

# Genre pending guard (D-36, etap 24).
GENRE_LINE=$(grep -E '^[[:space:]]+genre:[[:space:]]' .book/config.yaml | head -1 | sed -E 's/^[[:space:]]+genre:[[:space:]]+//; s/[[:space:]]*#.*$//; s/^"//; s/"$//' | tr -d ' ')
if [ "$GENRE_LINE" = "pending" ] || [ "$GENRE_LINE" = "null" ] || [ -z "$GENRE_LINE" ]; then
  echo "ERROR: жанр в .book/config.yaml — pending или не задан."
  echo "Запусти /bookbench:research-genre <slug>, чтобы сгенерировать пресет, или назначь готовый жанр через /bookbench:config genre <slug>, прежде чем продолжать."
  exit 2
fi

[ -d "$SECDIR" ] || { echo "Section folder $SECDIR does not exist. Run /bookbench:plan-section $N first."; exit 0; }
[ -s "$SECDIR/spec.md" ] || {
  # PS-13-02: refuse with hint, do NOT auto-call
  echo "$SECDIR/spec.md is missing or empty."
  echo "Run /bookbench:plan-section $N first to create the spec."
  exit 0
}

COMPLETED=$(awk '/^completed:/{print $2; exit}' "$SECDIR/section-state.yaml" || echo false)
LOOP_COUNT=$(awk '/^loop_count:/{print $2; exit}' "$SECDIR/section-state.yaml" || echo 0)
```

### Step 4 — Already-completed branch (PS-12-04, OQ-19 closure)

If `COMPLETED == true` (section already done), branch on `ON_COMPLETED`:

| Value | Action |
|-------|--------|
| `ask` | Present `AskUserQuestion`: «Section $N is completed. Choose: re-write (full pipeline) / re-edit (editor only) / abort.» |
| `re-write` | Back up artefacts to `$SECDIR/<artifact>-prev-<TS>.md`, reset `section-state.yaml` (`phase: writing, loop_count: 0, completed: false`), continue from Step 5. |
| `re-edit` | Hand off to `/bookbench:write-section:edit $N` semantics — call only the editor (Step 8 below). Skip Steps 5–7 and 9. |
| `abort` | Exit with notice. |

Backup recipe:

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
for f in draft.md factcheck.md edited.md marketing.md summary.md; do
  [ -f "$SECDIR/$f" ] && cp "$SECDIR/$f" "$SECDIR/${f%.md}-prev-${TS}.md"
done
sed -i.bak -E "s/^phase: .*/phase: writing/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^completed: .*/completed: false/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^loop_count: .*/loop_count: 0/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^factcheck_iteration_count: .*/factcheck_iteration_count: 0/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^factcheck_status: .*/factcheck_status: null/" "$SECDIR/section-state.yaml"
rm -f "$SECDIR/section-state.yaml.bak"
```

### Step 5 — Brief and start (Phase 0/Setup)

Print a 4–5 line briefing:

```
Starting section $N writing.
Phases: strategist → writer → factchecker (max ${LOOP_LIMIT}) → editor → optional skill-mode → optional marketer → finalise.
This may take several minutes. The author is asked to gate at the spec (already done) and at the final approval.
```

Update `.book/STATE.md` `current_section` and `last_action`:

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^- \`current_section\`:.*/- \`current_section\`: section_loop/" .book/STATE.md
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: write-section ${N} started/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/bookbench:write-section %s` — pipeline started\n' "$NOW" "$N" >> .book/STATE.md
```

Patch `section-state.yaml` `phase: writing`.

### Step 6 — Phase 2: Writer (initial draft)

Compose `<files_to_read>` per `context-control.md` § 2.2 (writer budget 25–80 KB):

```
${SECDIR}/spec.md
.book/context/voice-profile.md
.book/context/glossary.md
.book/config.yaml
${PREV_SECDIR}/summary.md          (if exists)
.book/.claude/agent-memory/writer/MEMORY.md   (if exists; created lazily by writer if absent)
.book/agent-guidelines/writer/README.md       (if exists)
```

Call `Task`:

- `subagent_type`: `book-writer`
- `description`: `Draft section ${N}`
- `prompt`:

  ```
  You are book-writer for /bookbench:write-section ${N} — INITIAL DRAFT mode.

  Required output: ${SECDIR}/draft.md
  Mandatory parts:
    - YAML frontmatter (section_id, created_by, created, based_on_spec_version,
      target_word_count, draft_word_count).
    - Body of the section (prose).

  Constraints (from base-methodology, popular-science-methodology, anti-ai-cliche skills):
    - Follow spec.md (theses 1–3 in order; hook strategy as specified).
    - Stay within 0.9 × target ≤ word_count ≤ 1.15 × target.
    - Preserve the author voice from voice-profile.md.
    - Avoid the 46 anti-AI-cliche patterns. The PostToolUse hook validates Write/Edit on draft.md.
    - Do NOT verify facts. The factchecker handles that next.
    - Do NOT include code blocks or math formulas (config.yaml.writing.forbid_*).

  Mark uncertain claims inline as `[NEEDS_FACTCHECK]` so the next phase can pick them up.

  After writing draft.md, return a 5-line summary (title, word count, hook used, theses
  covered, NEEDS_FACTCHECK count). Do NOT return the full draft.
  ```

- `files_to_read`: list above.

After Task returns, verify:

```bash
[ -s "$SECDIR/draft.md" ] || { echo "Writer did not produce draft.md"; exit 1; }
DRAFT_WC=$(wc -w < "$SECDIR/draft.md")
test "$DRAFT_WC" -ge 100 || { echo "draft.md is too short ($DRAFT_WC words)"; exit 1; }
sed -i.bak -E "s/^phase: .*/phase: factcheck/" "$SECDIR/section-state.yaml"
rm -f "$SECDIR/section-state.yaml.bak"
```

### Step 7 — Phase 3: Factchecker loop (DEC-03 max 3 iterations)

`LOOP_LIMIT` is `agents.loop_limits.factchecker_writer_revise` from `.book/config.yaml`, default 3.

```bash
ITER=1
LOOP_LIMIT=${LOOP_LIMIT:-3}
STATUS=""
while [ "$ITER" -le "$LOOP_LIMIT" ]; do
  echo "Factcheck iteration $ITER of $LOOP_LIMIT"
  # ... call factchecker (Task)
done
```

For each iteration:

1. Compose `<files_to_read>` per `context-control.md` § 2.3 (30–70 KB):

   ```
   ${SECDIR}/draft.md
   ${SECDIR}/spec.md
   .book/context/common-misconceptions.md
   .book/.claude/agent-memory/factchecker/MEMORY.md   (if exists)
   .book/agent-guidelines/factchecker/README.md       (if exists)
   ${PREV_SECDIR}/summary.md                           (if exists)
   ```

2. `Task`:
   - `subagent_type`: `book-factchecker`
   - `description`: `Factcheck section ${N} iteration ${ITER}`
   - `prompt`:

     ```
     You are book-factchecker for /bookbench:write-section ${N} — iteration ${ITER}/${LOOP_LIMIT}.

     Required output: ${SECDIR}/factcheck.md (overwrite if exists; previous iteration is
     already saved as factcheck-v$((ITER-1)).md by the coordinator).

     Mandatory frontmatter:
       status: pass | revise-required | escalate
       claims_total: <int>
       claims_verified: <int>
       claims_unverifiable: <int>
       claims_failed: <int>

     Body:
       For each factual claim — claim text (with source lines), verification (URL or
       trusted-sources reference), verdict (verified | unverifiable | failed).

     Adversarial stance: a claim is unverified until matched against at least one trusted source.
     Do NOT fix the draft. Do NOT propose new wording. The writer handles that on revise.

     If at iteration ${LOOP_LIMIT} you still have unresolved claims, set status: escalate
     and list the offending claims under "## Escalation".
     ```

   - `files_to_read`: list above.

3. After Task, read `factcheck.md` from disk:

   ```bash
   STATUS=$(awk '/^status:/{print $2; exit}' "$SECDIR/factcheck.md" || echo "")
   ```

4. Branch:

   - `STATUS == pass` → exit loop, proceed to Step 8.
   - `STATUS == revise-required` and `ITER < LOOP_LIMIT`:
     - `cp "$SECDIR/draft.md" "$SECDIR/draft-revised-v${ITER}.md"`
     - `cp "$SECDIR/factcheck.md" "$SECDIR/factcheck-v${ITER}.md"`
     - Increment `factcheck_iteration_count` in `section-state.yaml`.
     - Call writer in revise-mode:
       - `subagent_type`: `book-writer`, `description`: `Revise draft section ${N} iter ${ITER}`
       - `prompt`: «You are book-writer in REVISE mode. Read draft.md and factcheck.md (status: revise-required). Address each `revise-required` claim by either supporting it with a verifiable source, hedging, or removing it. Output: overwrite ${SECDIR}/draft.md.»
       - `files_to_read`: `[draft.md, factcheck.md, spec.md, voice-profile.md, glossary.md, agent-guidelines/writer/README.md]`
     - `ITER=$((ITER + 1))`, continue loop.
   - `STATUS == escalate` or (`STATUS == revise-required` and `ITER == LOOP_LIMIT`):
     - **ESCALATE-flow** (DEC-03):
       - Append entry to `.book/REJECTIONS-LOG.md`:
         ```
         ## ${NOW} — section-${PADDED} — factcheck-loop-exhausted
         iteration_count: ${ITER}
         claims_failed: <count>
         ```
       - `AskUserQuestion`:
         - Title: «Factcheck loop exhausted (section $N)»
         - Options: `Hedge claims (writer adds "approximately"/"some studies suggest")` / `Drop the failing claims` / `I will provide sources manually` / `Accept with [ASSUMED] markers`.
         - On `Hedge`/`Drop` — call writer one more time in revise mode with explicit author instruction; then re-call factchecker once; if still not pass — go to «accept with markers».
         - On `Manually` — pause: print «Edit ${SECDIR}/draft.md by hand, add sources, then run `/bookbench:write-section:factcheck $N`.» Exit.
         - On `Accept` — leave the failing claims marked `[ASSUMED]` and proceed to Step 8 with a note in `section-state.yaml.notes`.

After the loop:

```bash
sed -i.bak -E "s/^phase: .*/phase: editing/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^factcheck_iteration_count: .*/factcheck_iteration_count: ${ITER}/" "$SECDIR/section-state.yaml"
rm -f "$SECDIR/section-state.yaml.bak"
```

### Step 8 — Phase 4: Editor

Compose `<files_to_read>` per `context-control.md` § 2.4 (35–90 KB):

```
${SECDIR}/draft.md
${SECDIR}/factcheck.md
${SECDIR}/spec.md
.book/context/voice-profile.md
.book/context/cross-references.md
.book/.claude/agent-memory/editor/MEMORY.md   (if exists)
.book/agent-guidelines/editor/README.md       (if exists)
${PREV_SECDIR}/summary.md                      (if exists)
```

`Task`:

- `subagent_type`: `book-editor`
- `description`: `Edit section ${N}`
- `prompt`:

  ```
  You are book-editor in BASE-MODE for /bookbench:write-section ${N}.

  Required output: ${SECDIR}/edited.md (new file, do NOT overwrite draft.md).

  Mandatory frontmatter:
    section_id, created_by, created, based_on_draft_version, based_on_factcheck_status,
    draft_word_count, edited_word_count, delta_pct, target_met, anti_cliche_occurrences,
    voice_decisions_count, cohesion_callbacks, needs_recheck_blocks.

  Body:
    Full edited section text + "## Deviation log" (each change with line numbers + reason)
    + "## Voice decisions" (taste-preferences left intact).

  Constraints (from popular-science-methodology, anti-ai-cliche, base-methodology):
    - Preserve author voice (voice-profile.md is the source of truth).
    - Reduce volume by ~10% (delta_pct ≤ -10 → target_met: true).
    - Apply 4 levels (structure → paragraphs → sentences → words).
    - The PostToolUse hook lints draft/edited writes for the 46 anti-cliche patterns.
    - If you doubt a claim, mark `[NEEDS_RECHECK]` block in edited.md; do NOT edit factcheck.md.
    - Do NOT change meaning, only form.
    - Hard error vs taste preference — hard errors are fixed; taste preferences are left + logged.
  ```

- `files_to_read`: list above.

Verify:

```bash
[ -s "$SECDIR/edited.md" ] || { echo "Editor did not produce edited.md"; exit 1; }
NEEDS_RECHECK=$(awk '/^needs_recheck_blocks:/{print $2; exit}' "$SECDIR/edited.md" || echo 0)
```

If `NEEDS_RECHECK > 0`, optionally re-call factchecker once in fragment mode (Phase 4b). For stage 13 we accept this as a known optional path — the coordinator may skip on first pass; the author is informed in the next-step message.

### Step 9 — Phase 5: optional skill-mode reviews (skipped at stage 13)

Skill-mode passes (`consistency-check`, `philosophical-review`, `sensitivity-review`, `ethical-review`, `anti-cliche-check`, `cultural-translation-review`) are configured via `workflow.md > section_loop.enable_skill_reviews`. Stage 13 reads `.book/config.yaml` for an optional `skill_reviews:` array; if absent or empty, skip Phase 5.

If non-empty, for each enabled skill name, call `Task(subagent_type=book-editor, description="Skill ${SKILL} review section ${N}", prompt="You are book-editor in SKILL-MODE. Active skill: ${SKILL}. Output: ${SECDIR}/reviews/${SKILL}.md. Do NOT modify edited.md.", files_to_read=[edited.md, agent-guidelines/editor/README.md, context/voice-profile.md])`.

For stage 13 the default config has no skill reviews enabled — proceed to Step 10.

### Step 10 — Phase 6: optional Marketer

If `agents.enabled` includes `marketer` AND a workflow flag (default `true` for popular-science) keeps it on, call:

- `Task(subagent_type=book-marketer, description="Market section ${N}", files_to_read=[edited.md, agent-guidelines/marketer/README.md, context/visual-blacklist.md, context/target-audience.md, .book/.claude/agent-memory/marketer/MEMORY.md (if exists)])`.
- Prompt: «You are book-marketer. Required output: ${SECDIR}/marketing.md with three title variants, one hook line, one Telegram-style post draft (1000–2000 chars), one image prompt (50–100 words), and a 140–150 char snippet. Do NOT change edited.md. Do NOT invent facts; reuse what is already in edited.md.»

Verify `marketing.md` exists; tolerate missing `.book/.claude/agent-memory/marketer/MEMORY.md` (created lazily).

If marketer is disabled — skip silently.

### Step 11 — Phase 7: Coordinator finalise (`summary.md`)

The coordinator (this command) writes the section summary directly. No subagent.

Read `${SECDIR}/edited.md` head + tail (≈ 100 lines total). Compose `summary.md` (≤ 500 words) with:

- Frontmatter (`section_id`, `created_by: book-coordinator`, `created`, `word_count` of edited).
- Sections: «Thesis» (one line), «Key concepts introduced», «Used metaphors / examples» (reference writer/MEMORY.md by line), «Forward link / open questions».

Write directly via the Write tool to `${SECDIR}/summary.md`.

### Step 12 — Final author gate (Phase 1g of approval)

`AskUserQuestion`:

- Title: «Section ${N} ready»
- Show: `edited.md` head 30 lines + `marketing.md` first 10 lines (if present).
- Options:
  - `Accept` — finalise.
  - `Re-edit (give guidance)` — author note → re-call editor in revise mode (one extra iteration). Stage 13 implements at most one such retry.
  - `Reject (full re-write)` — back up all artefacts (draft, factcheck, edited, marketing, summary), reset `section-state.yaml` to `phase: writing, loop_count: 0`, return to Step 6.

For stage 13, `Reject` is supported but the loop count is bounded at 2 to avoid infinite cycles.

### Step 13 — Atomic finalisation

On `Accept`:

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^phase: .*/phase: done/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^completed: .*/completed: true/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^last_phase_change: .*/last_phase_change: ${NOW}/" "$SECDIR/section-state.yaml"
rm -f "$SECDIR/section-state.yaml.bak"

sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: section ${N} written/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/bookbench:write-section %s` — section completed (factcheck iters=%d)\n' "$NOW" "$N" "${ITER:-1}" >> .book/STATE.md
```

### Step 14 — Next-step message

```
Section ${N} written and accepted.
  Files: ${SECDIR}/draft.md, factcheck.md, edited.md, summary.md
  ${MARKETER_LINE}
  Factcheck iterations: ${ITER}

Recommended next:
  /bookbench:audit-section ${N}    — independent audit of the finished section (read-only).
  /bookbench:plan-section $((N+1)) — start the next section.
```

### Constitutional rules for this command

- **MUST** preserve DEC-03 loop limit (default 3, configurable, capped at 5 for sanity).
- **MUST** call subagents through `Task` with explicit `<files_to_read>`; never autodiscovery.
- **MUST** verify each subagent's output from disk; never trust the return string.
- **MUST** back up artefacts on `re-write` and `Reject (full re-write)`.
- **NEVER** edit `draft.md`, `factcheck.md`, `edited.md`, `marketing.md` directly (file-ownership invariant).
- **NEVER** call `book-tuner` or `bookbench-evolver` from this command (those are stage 14).
- **NEVER** skip the spec gate (already enforced — `/bookbench:plan-section` runs first; we error out if `spec.md` is missing).
- **NEVER** progress past `factcheck_status: pass` without writing it to disk.

### Stage-14 hand-off notes

- The PostToolUse hook (`anti-ai-cliche-lint.sh`) is wired in `.book/.claude/settings.json` (PS-12-01). At stage 13 the hook returns `pass` without running the regex engine. Stage 14 implements the corpus loader and reaction policy.
- Phase 4b (re-check on `[NEEDS_RECHECK]`) is partially supported; full implementation (multi-fragment factchecker re-call) lands in stage 14 along with the writer/factchecker eval-cases.
- Stage 14 polishes the subagent prompts. Bugs in their output during stage 13 manual tests are recorded in `.bpd/stages/13-realizaciya-komand/manual-test-log.md`, not patched in stage 13.

</execution>
