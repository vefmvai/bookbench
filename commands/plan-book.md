---
description: Forms or extends the book-level plan by invoking book-strategist in book-mode. Produces the chapter list in ROADMAP.md and the red-thread keywords. With --from-imports incorporates classified imported fragments.
argument-hint: "[--from-imports]"
allowed-tools: [Task, Read, Write, Edit, AskUserQuestion]
---

# /book:plan-book

<purpose>
Plan the whole book — number and order of chapters, parts, red-thread keywords. Stops at the chapter-spec level (`/book:plan-chapter` does that).
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Inputs

- `.book/PROJECT.md`, `.book/config.yaml`, `.book/context/`.
- `${CLAUDE_PLUGIN_ROOT}/skills/genres/<genre>/SKILL.md` via `skills:` injection on `book-strategist`.
- `INGEST-DECISIONS.md` and `.book/intel/classifications/*.json` if `--from-imports`.

## Outputs

- `.book/ROADMAP.md` (write or append).
- `.book/context/red-thread-keywords.md` (write or update).

<execution>

This is the first command at stage 13 that delegates to a subagent. The 8-step orchestrator pattern applies: validate, resolve paths, read inputs, optional `AskUserQuestion`, `Task` with `<files_to_read>`, verify outputs, atomic STATE update, next-step message.

### Step 1 — Pre-flight

```bash
[ -d .book ] || {
  echo "No .book/ directory. Run /book:start first."
  exit 0
}
[ -f .book/PROJECT.md ] || {
  echo ".book/PROJECT.md is missing. The book is not initialised correctly. Run /book:start."
  exit 0
}
[ -f .book/config.yaml ] || {
  echo ".book/config.yaml is missing. Run /book:start."
  exit 0
}

# Detect existing ROADMAP
EXISTING_PLANNED=0
[ -f .book/ROADMAP.md ] && EXISTING_PLANNED=$(grep -cE '^## (Chapter|Глава)' .book/ROADMAP.md || echo 0)
```

If `EXISTING_PLANNED > 0` — present an `AskUserQuestion`:

- Title: «ROADMAP already has ${EXISTING_PLANNED} chapters»
- Options: `Replace (re-plan from scratch)` / `Refine (strategist reads existing ROADMAP and refines)` / `Cancel`.
- On `Cancel` — exit. The selected mode is passed to the strategist via prompt.

### Step 2 — Argument

If `$ARGUMENTS` contains `--from-imports`, set `FROM_IMPORTS=1`. Stage 13 still passes this flag to the strategist; classifier output handling is part of stage 14, but the strategist is allowed to read existing `INGEST-DECISIONS.md` if present.

### Step 3 — Read minimal context for the orchestrator

Read these files into the coordinator's context to compose the Task prompt (small, ≤ 10 KB total):

- `.book/PROJECT.md` (vision, audience, scope).
- `.book/config.yaml` (genre, language, version).
- `.book/STATE.md` (last_action).

Do NOT read full `context/*.md` here — they are passed to the strategist via `<files_to_read>` so it can read them in its isolated context.

### Step 4 — Compose `<files_to_read>` for `book-strategist`

Per `context-control.md` § 2.1, the strategist context budget is 15–50 KB. For book-mode the obligatory list is:

```
.book/PROJECT.md
.book/config.yaml
.book/context/voice-profile.md
.book/context/target-audience.md
.book/context/red-thread-keywords.md     (may be empty placeholder; strategist will fill it)
.book/context/glossary.md                (may be empty)
.book/context/parameters.md              (may be empty)
```

If `FROM_IMPORTS=1`, also include:

```
.book/INGEST-DECISIONS.md
```

Do NOT pass any chapter directories or memory files (the book has no chapters yet).

### Step 5 — Call the strategist via `Task`

Invoke the Task tool exactly once:

- `subagent_type`: `book-strategist`
- `description`: `Plan book in book-mode (chapters list and red-thread keywords)`
- `prompt`: a structured instruction (~ 25–40 lines) consisting of:

  ```
  You are book-strategist in BOOK-MODE for /book:plan-book.

  Mode parameter: ${MODE}        # one of: fresh | refine | from-imports
  ${MODE == "refine" ? "Read the existing .book/ROADMAP.md and propose changes/additions, do not discard existing structure unless contradicted by PROJECT.md." : ""}
  ${MODE == "from-imports" ? "Use INGEST-DECISIONS.md as a hint. Do NOT include any unverified claims; flag with [NEEDS_FACTCHECK]." : ""}

  Required outputs (write directly to disk):
    1. .book/ROADMAP.md — chapter-by-chapter plan with at minimum: title, one-line thesis,
       red-thread keywords used, expected_word_count, prerequisites, status: planned.
       Aim for the chapter count given in PROJECT.md "scope" or, if unspecified, 8–12 chapters.
    2. .book/context/red-thread-keywords.md — 5–10 keywords with one-line definitions and
       intended distribution across chapters.

  Constraints (from base-methodology and ${BOOK_GENRE_SKILL_NAME}):
    - 3-act or pyramid structure (specify which in ROADMAP frontmatter).
    - Each chapter has 1 thesis only.
    - red_thread_keywords must appear in at least 3 chapters total.
    - Use the author's voice as captured in voice-profile.md (do not invent persona).

  Files to read are listed below. Read them once. Do not browse the filesystem; rely on the list.

  After writing the two files, return a 5-line summary (chapter count, red-thread keywords,
  open questions if any). Do NOT return the full ROADMAP body in your answer; the
  coordinator reads the file from disk.
  ```

- `files_to_read`: the list from Step 4.

### Step 6 — Verify outputs

After the Task returns, do not trust the return text. Read from disk:

```bash
[ -s .book/ROADMAP.md ] || { echo "Strategist did not write ROADMAP.md"; exit 1; }
[ -s .book/context/red-thread-keywords.md ] || { echo "Strategist did not write red-thread-keywords.md"; exit 1; }
PLANNED=$(grep -cE '^## (Chapter|Глава)' .book/ROADMAP.md)
[ "$PLANNED" -ge 3 ] || { echo "ROADMAP has <3 chapters; rejecting."; exit 1; }
```

If verification fails — present an `AskUserQuestion`: «Strategist returned an incomplete ROADMAP. Options: retry / accept partial / cancel.»

### Step 7 — Author gate

Read the head of the new `ROADMAP.md` (first ~ 60 lines). Show the author a 5–8 line summary plus an `AskUserQuestion`:

- Title: «Book plan ready»
- Question: «${PLANNED} chapters drafted with red-thread keywords [${KEYWORD_LIST}]. Proceed?»
- Options:
  - `Accept` — finalise.
  - `Refine (provide guidance)` — follow up with a free-text question, then re-call the strategist with `revise-mode` and the author note.
  - `Reject (start over)` — backup the current ROADMAP to `.book/.backup/<ts>-plan-book/` and re-run from Step 5 with mode=fresh.

For stage 13 the refine/reject loop runs at most once (no infinite retries — the author can simply re-run the command).

### Step 8 — Atomic STATE update

On `Accept`:

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Update last_action and current_section
sed -i.bak -E "s/^- \`current_section\`:.*/- \`current_section\`: book_level/" .book/STATE.md
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: plan-book completed (${PLANNED} chapters)/" .book/STATE.md
rm -f .book/STATE.md.bak
# Append History line
printf '\n%s — `/book:plan-book` — wrote ROADMAP.md (%d chapters) and red-thread-keywords.md\n' "$NOW" "$PLANNED" >> .book/STATE.md
```

### Step 9 — Next-step message

```
Book plan accepted: ${PLANNED} chapters in .book/ROADMAP.md
Red-thread keywords: ${KEYWORD_LIST}

Recommended next:
  /book:plan-chapter 1     — draft the spec for chapter 1.
  /book:status             — see current progress.
```

### Constitutional rules for this command

- **MUST** call `book-strategist` exactly once per accepted plan (one retry allowed via the refine gate).
- **MUST** pass an explicit `<files_to_read>` block (no autodiscovery).
- **MUST** verify outputs from disk, not from the Task return string.
- **NEVER** edit `ROADMAP.md` directly. The coordinator only updates `STATE.md`.
- **NEVER** invoke any other subagent here (writer, factchecker, editor are stage 13 task T7).

</execution>
