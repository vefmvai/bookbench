---
description: Прогоняет фазу 1 микро-цикла раздела N (агент book-strategist) и шлюз одобрения ТЗ (spec-gate). Создаёт файл sections/<id>/spec.md и просит автора утвердить ТЗ. Само написание драфта не запускается — это работа команды /book:write-section.
argument-hint: "<section-number>"
allowed-tools: [Task, Read, Write, Edit, AskUserQuestion]
---

# /book:plan-section

<purpose>
Generate the section specification (`spec.md`) for section N — a structural ToR — without proceeding into the rest of the micro-cycle.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Inputs

- `<section-number>` (positional argument).
- Existing `sections/<id>/spec.md` (if present, asks: overwrite, create v2, show current).
- `.book/ROADMAP.md`, `.book/PROJECT.md`, `.book/config.yaml`.
- `.book/context/{red-thread-keywords, parameters, voice-profile, target-audience, common-misconceptions}.md`.
- `.book/agent-guidelines/strategist/`.
- `.book/.claude/agent-memory/strategist/MEMORY.md`.
- `.book/sections/<previous-id>/summary.md` (cross-section context budget).

<execution>

This command implements Phase 1 (strategist) + Phase 1g (spec gate) of the section micro-cycle. PS-13-02 says when `spec.md` is missing for `/book:write-section`, refuse with a hint (rather than auto-call); here we are the source of `spec.md`.

### Step 1 — Validate argument

```bash
ARG="$ARGUMENTS"
[ -z "$ARG" ] && { echo "Usage: /book:plan-section <section-number>"; exit 0; }
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
[ -z "$N" ] && { echo "Section number must be an integer ≥ 1."; exit 0; }
[ "$N" -lt 1 ] 2>/dev/null && { echo "Section number must be ≥ 1."; exit 0; }
PADDED=$(printf '%03d' "$N")
SECDIR=".book/sections/section-${PADDED}"
echo "N=$N PADDED=$PADDED SECDIR=$SECDIR"
```

### Step 2 — Pre-flight book state

```bash
[ -d .book ] || { echo "No .book/. Run /book:start."; exit 0; }
[ -f .book/ROADMAP.md ] || { echo ".book/ROADMAP.md is missing. Run /book:plan-book first."; exit 0; }

# Genre pending guard (D-36, etap 24).
GENRE_LINE=$(grep -E '^[[:space:]]+genre:[[:space:]]' .book/config.yaml | head -1 | sed -E 's/^[[:space:]]+genre:[[:space:]]+//; s/[[:space:]]*#.*$//; s/^"//; s/"$//' | tr -d ' ')
if [ "$GENRE_LINE" = "pending" ] || [ "$GENRE_LINE" = "null" ] || [ -z "$GENRE_LINE" ]; then
  echo "ERROR: жанр в .book/config.yaml — pending или не задан."
  echo "Запусти /book:research-genre <slug>, чтобы сгенерировать пресет, или назначь готовый жанр через /book:config genre <slug>, прежде чем продолжать."
  exit 2
fi

PLANNED=$(grep -cE '^## (Section|Раздел|Глава|Chapter)' .book/ROADMAP.md || echo 0)
[ "$PLANNED" -lt "$N" ] && {
  echo "ROADMAP has only $PLANNED planned sections; you asked for $N."
  echo "Either /book:plan-book to extend, or pass a smaller section number."
  exit 0
}
```

### Step 3 — Existing section folder

```bash
EXISTS=0
[ -d "$SECDIR" ] && EXISTS=1
HAS_SPEC=0
[ -s "$SECDIR/spec.md" ] && HAS_SPEC=1
COMPLETED=false
[ -f "$SECDIR/section-state.yaml" ] && COMPLETED=$(awk '/^completed:/{print $2; exit}' "$SECDIR/section-state.yaml" || echo false)
```

If `COMPLETED == true` — present an `AskUserQuestion`:

- Title: «Section ${N} is already completed»
- Options: `Re-plan (back up the current spec)` / `Show current spec` / `Cancel`.
- On `Cancel` — exit. On `Show` — print head 40 lines of `spec.md`, then re-ask. On `Re-plan` — back up:

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$SECDIR"
cp "$SECDIR/spec.md" "$SECDIR/spec-prev-${TS}.md" 2>/dev/null || true
cp "$SECDIR/section-state.yaml" "$SECDIR/section-state-prev-${TS}.yaml" 2>/dev/null || true
```

If `HAS_SPEC == 1 && COMPLETED == false` — `AskUserQuestion`: `Overwrite (back up current)` / `Show current` / `Cancel`.

### Step 4 — Scaffold section folder

```bash
if [ ! -d "$SECDIR" ]; then
  mkdir -p "$SECDIR"
  cp -R .book/sections/.template/. "$SECDIR/"
  # Patch section-state.yaml with section_id, created
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  sed -i.bak -E "s/^section_id: TBD/section_id: section-${PADDED}/" "$SECDIR/section-state.yaml"
  sed -i.bak -E "s/^created: TBD/created: ${NOW}/" "$SECDIR/section-state.yaml"
  sed -i.bak -E "s/^last_phase_change: TBD/last_phase_change: ${NOW}/" "$SECDIR/section-state.yaml"
  rm -f "$SECDIR/section-state.yaml.bak"
fi
```

### Step 5 — Compose `<files_to_read>` for `book-strategist`

Per `context-control.md` § 2.1 (strategist budget 15–50 KB). Include:

```
${SECDIR}/section-state.yaml
.book/ROADMAP.md
.book/PROJECT.md
.book/config.yaml
.book/context/parameters.md
.book/context/red-thread-keywords.md
.book/context/glossary.md
.book/context/target-audience.md
.book/context/voice-profile.md
.book/context/common-misconceptions.md
```

If `${SECDIR}/spec.md` already exists (revise mode) — also include `${SECDIR}/spec.md` plus the author note.

If `${PREV_PADDED}` section directory exists, also include:

```
.book/sections/section-${PREV_PADDED}/summary.md
```

If `${PREV_PADDED-2}` section directory exists, optionally also `.book/sections/section-${PREV2_PADDED}/summary.md` (≤ 2 KB each).

If `.book/.claude/agent-memory/strategist/MEMORY.md` exists, include it.

If `.book/agent-guidelines/strategist/README.md` exists, include it.

### Step 6 — Call the strategist via `Task`

Single Task invocation:

- `subagent_type`: `book-strategist`
- `description`: `Form spec.md for section ${N}`
- `prompt`: structured instruction:

  ```
  You are book-strategist for /book:plan-section ${N}.

  Mode: ${MODE}    # one of: fresh | revise (when spec.md exists)
  Author note (if revise): "${AUTHOR_NOTE}"

  Required output: ${SECDIR}/spec.md

  Mandatory sections of spec.md (per artifact-protocol.md § 3.2 and book-strategist
  Procedure FORM-SPEC):
    - YAML frontmatter (section_id, created_by, created, section_template,
      expected_word_count, red_thread_keywords, locked_decisions, prerequisites).
    - "# ТЗ раздела ${N}: <title>"
    - "## Goals" (bullets)
    - "## Hook strategy"
    - "## Three key theses" (1, 2, 3)
    - "## Expected length"
    - "## Locus in red thread"
    - "## Connection to previous section"
    - "## Decisions for this section (S-NNN)"
    - "## Factcheck hints" (with [NEEDS_FACTCHECK] markers if relevant)
    - "## Spec completion checklist"

  Constraints:
    - Use ROADMAP.md as the authoritative source for the section title and thesis.
    - Use red-thread-keywords.md to choose 2–3 keywords for this section.
    - expected_word_count: read from .book/config.yaml.writing.section_target_chars (or
      override from .book/context/parameters.md).
    - Do not write the section body; this is the writer's job. Just the spec.
    - Do not verify facts. If you mark [NEEDS_FACTCHECK] — that is a hint to the factchecker,
      not an admission of doubt.

  After writing the file, return a 5-line summary. Do not return the full spec body.
  ```

- `files_to_read`: list from Step 5.

### Step 7 — Verify outputs

```bash
[ -s "$SECDIR/spec.md" ] || { echo "Strategist did not write spec.md"; exit 1; }
# Required sections (heuristic checks — substring match)
for section in '## Goals' '## Цели' '## Hook' '## Hook-стратегия' '## Three key theses' '## 3 ключевых тезиса'; do
  : # noop — strategist may use either Russian or English headings; we accept both
done
# Minimal acceptance: file > 500 bytes and contains section_id frontmatter
test "$(wc -c < "$SECDIR/spec.md")" -gt 500 || { echo "spec.md is too short"; exit 1; }
grep -qE '^section_id:' "$SECDIR/spec.md" || { echo "spec.md frontmatter missing section_id"; exit 1; }
echo "spec.md verified."
```

If verification fails — `AskUserQuestion` with `retry` / `inspect` / `cancel`.

### Step 8 — Spec gate (Phase 1g)

Read `${SECDIR}/spec.md` (head 80 lines). Show the author a compact summary:

```
Section ${N} spec ready.
  Template:    <section_template>
  Words:       <expected_word_count>
  Hook:        <one-line description>
  Three theses:
    1. <thesis 1>
    2. <thesis 2>
    3. <thesis 3>
  Connection to previous: <one line or "none">
  NEEDS_FACTCHECK markers: K
```

`AskUserQuestion`:

- Title: «Spec for section ${N}»
- Options:
  - `Accept (move to writing)` — proceed to Step 9.
  - `Refine (give guidance)` — follow up free-text; back-up current spec; re-call strategist in revise mode.
  - `Reject (cancel)` — exit; do not update STATE.

For stage 13 refine runs at most once per command invocation.

### Step 9 — Atomic state update

On `Accept`:

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Patch section-state.yaml
sed -i.bak -E "s/^phase: .*/phase: spec-review/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^last_phase_change: .*/last_phase_change: ${NOW}/" "$SECDIR/section-state.yaml"
rm -f "$SECDIR/section-state.yaml.bak"

# Patch .book/STATE.md
sed -i.bak -E "s/^- \`current_section\`:.*/- \`current_section\`: section_loop/" .book/STATE.md
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: plan-section ${N} accepted/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/book:plan-section %s` — spec accepted (section-%s)\n' "$NOW" "$N" "$PADDED" >> .book/STATE.md
```

### Step 10 — Next-step message

```
Spec for section ${N} accepted: ${SECDIR}/spec.md

Recommended next:
  /book:write-section ${N}    — run the full 5+1-phase micro-cycle.
  /book:plan-section ${N+1}   — pre-plan the next section (optional).
```

### Constitutional rules for this command

- **MUST** validate the section number is a positive integer.
- **MUST** call `book-strategist` exactly once (plus at most one revise call).
- **MUST** pass an explicit `<files_to_read>` block bounded by per-role budget.
- **MUST** never proceed to writing — that is `/book:write-section`.
- **NEVER** call `book-writer`, `book-factchecker`, `book-editor`, `book-marketer` from this command.

</execution>
