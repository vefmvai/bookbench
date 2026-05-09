---
description: Opens an interactive discussion about chapter <N> with the book-strategist before formal spec writing. Useful when the author wants to refine the angle, hook, or thesis collaboratively. Output goes to chapters/<N>/discussion.md and feeds into /book:plan-chapter.
argument-hint: "<chapter-number>"
allowed-tools: [Task, Read, Write, AskUserQuestion]
---

# /book:discuss-chapter

<purpose>
Pre-spec dialog with the strategist to refine the chapter angle. Not part of the strict micro-cycle for popular-science (the strategist owns spec-formation directly), but valuable for genres with strong authorial-voice considerations: memoir, fiction, philosophical non-fiction.
</purpose>

<!-- ЭТАП 14: реализовано как тонкий orchestrator (минимально-достаточный для 0.1) -->

## Inputs

- `<chapter-number>` — required.
- `.book/chapters/chapter-<N>/spec.md` (read, if exists; informs the discussion).
- `.book/context/voice-profile.md`, `red-thread-keywords.md`, `target-audience.md`.
- `.book/ROADMAP.md` for chapter context.

## Outputs

- `.book/chapters/chapter-<N>/discussion.md` — append-only dialog log.

<execution>

Six-step pattern. Less rigorous than `/book:plan-chapter` because the output is exploratory.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory."; exit 0; }

CHAPTER_N="$ARGUMENTS"
[ -z "$CHAPTER_N" ] && { echo "Usage: /book:discuss-chapter <N>"; exit 0; }

CHAPTER_DIR=$(printf '.book/chapters/chapter-%03d' "$CHAPTER_N")
mkdir -p "$CHAPTER_DIR"
DISC_FILE="$CHAPTER_DIR/discussion.md"
```

### Step 2 — Initialise discussion file

If the file does not exist, create a header:

```bash
if [ ! -f "$DISC_FILE" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$DISC_FILE" <<MD
# Discussion: Chapter $CHAPTER_N

Started: $NOW
Status: open

## Open questions

(strategist asks; author answers; running log)

MD
fi
```

### Step 3 — Delegate to book-strategist in discussion mode

```
Task(
  subagent_type: book-strategist,
  description: "Open discussion for chapter <N>",
  prompt: """
    You are book-strategist in DISCUSSION mode (skill: base-methodology).

    Goal: refine the angle, hook, and thesis for chapter <N> through dialog
    with the author. This is NOT spec-formation — it is pre-spec exploration.

    Required steps:
      1. Read context (voice-profile, red-thread-keywords, ROADMAP entry for chapter <N>,
         previous chapter summary if exists, the existing discussion.md if any).
      2. Open the dialog with 2-4 sharp questions that surface the chapter's
         angle. Examples:
            • What is the single thesis of this chapter?
            • Who is the reader after this chapter?
            • What does the chapter reject (the thing some other writer would
              say in this slot but you would not)?
      3. As the author answers, append each Q-A pair to the discussion.md.
      4. After 2-3 rounds, propose a 1-2-line thesis statement and ask the
         author to confirm or refine.

    Constraints:
      • Do NOT write spec.md from this command. Spec belongs to /book:plan-chapter.
      • Append-only edits to discussion.md. Never overwrite.
      • One question or proposal per turn. Wait for the author to answer
        before continuing.
  """,
  files_to_read: [
    .book/PROJECT.md,
    .book/ROADMAP.md,
    .book/context/voice-profile.md,
    .book/context/red-thread-keywords.md,
    .book/context/target-audience.md,
    <CHAPTER_DIR>/discussion.md,
    <CHAPTER_DIR>/spec.md (if exists),
    .book/chapters/chapter-<N-1>/summary.md (if exists)
  ]
)
```

### Step 4 — Verify outputs

After the dialog completes, ensure `<DISC_FILE>` has gained at least one Q-A round.

### Step 5 — STATE.md history append

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '\n%s — `/book:discuss-chapter %d` — discussion updated\n' \
  "$NOW" "$CHAPTER_N" >> .book/STATE.md
```

### Step 6 — Next-step message

```
Discussion saved: $DISC_FILE

Recommended next:
  /book:plan-chapter $CHAPTER_N    — formalise the spec based on this discussion.
  /book:discuss-chapter $CHAPTER_N — continue the discussion later.
```

### Constitutional rules

- **MUST** delegate the dialog to `book-strategist`. The orchestrator does not generate questions.
- **MUST** be append-only on `discussion.md`. The history of the conversation is the artefact.
- **MUST** not write `spec.md` — that is `/book:plan-chapter`.
- **NEVER** call writer / factchecker / editor.

</execution>
