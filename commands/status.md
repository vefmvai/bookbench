---
description: Reports the current state of the book at hand — chapter progress, last action, plugin compatibility, active debug sessions and pending competing-variant resolutions. Read-only.
argument-hint: ""
allowed-tools: [Read, Bash, Glob, Grep]
---

# /book:status

<purpose>
Show progress: how many chapters are done, what was last touched, whether plugin and book versions are still compatible, what is recommended next.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Inputs

- `.book/STATE.md`, `.book/ROADMAP.md`, `.book/config.yaml`.
- Listing of `.book/chapters/`.
- `${CLAUDE_PLUGIN_DATA}/registry.yaml` for registration check.

## Outputs

- A formatted summary on stdout.

## Side effects

None. Read-only command.

<execution>

This command is read-only. It reads files, computes a summary, prints it. No `Task` calls, no Write tool calls, no Edit. PS-13-04 fixes the warning-not-fail policy on plugin-version mismatch.

### Step 1 — Resolve paths

Run the same Bash recipe as `/book:start` Step 2 to compute `PLUGIN_ROOT`, `PLUGIN_DATA`, `PLUGIN_VERSION`. (Reference: `${CLAUDE_PLUGIN_ROOT}/lib/plugin-data-helpers.md` H1, H2, H6.)

### Step 2 — Detect book initialisation

```bash
[ -d .book ] || {
  echo "No .book/ directory. Run /book:start to initialise a book here."
  exit 0
}
```

If `.book/` is absent — print the message above and stop. Do NOT continue.

### Step 3 — Read book state

Read these files (each ≤ 5 KB; total ≤ 25 KB):

- `.book/STATE.md`
- `.book/config.yaml`
- `.book/ROADMAP.md` (it may be empty if `/book:plan-book` has not run yet)

Extract via Bash and Glob:

```bash
# State
CURRENT_SECTION=$(awk -F'`' '/current_section/{print $3; exit}' .book/STATE.md | sed -E 's/^: //; s/^[[:space:]]+//; s/[[:space:]]+$//')
CURRENT_CHAPTER=$(awk -F'`' '/current_chapter/{print $3; exit}' .book/STATE.md | sed -E 's/^: //; s/^[[:space:]]+//; s/[[:space:]]+$//')
LAST_ACTION=$(awk -F'`' '/last_action/{print $3; exit}' .book/STATE.md | sed -E 's/^: //; s/^[[:space:]]+//; s/[[:space:]]+$//')

# Last 3 history entries
LAST_HISTORY=$(grep -E '^[0-9]{4}-' .book/STATE.md | tail -n 3 || true)

# Config
BOOK_TITLE=$(awk -F'"' '/^  title:/{print $2; exit}' .book/config.yaml)
BOOK_GENRE=$(awk '/^  genre:/{print $2; exit}' .book/config.yaml)
BOOK_LANGUAGE=$(awk '/^  language:/{print $2; exit}' .book/config.yaml)
BOOK_REGISTRY_ID=$(awk -F'"' '/^  registry_id:/{print $2; exit}' .book/config.yaml)
BOOK_VERSION=$(awk -F'"' '/created_with_bookbench/{print $2; exit}' .book/config.yaml)
LAST_SYNCED=$(awk -F'"' '/last_synced_with/{print $2; exit}' .book/config.yaml)
```

### Step 4 — Plan and chapter listing

```bash
# ROADMAP planned chapters (count of "## Chapter" or "- chapter-" entries)
ROADMAP_LINES=$(wc -l < .book/ROADMAP.md 2>/dev/null || echo 0)
PLANNED_CHAPTERS=$(grep -cE '^## (Chapter|Глава)' .book/ROADMAP.md 2>/dev/null || echo 0)

# Existing chapter folders
CHAPTER_DIRS=$(ls -d .book/chapters/chapter-*/ 2>/dev/null | sort || true)
COMPLETED_COUNT=0
IN_PROGRESS_COUNT=0
for d in $CHAPTER_DIRS; do
  if [ -f "$d/chapter-state.yaml" ]; then
    if grep -qE '^completed: true' "$d/chapter-state.yaml"; then
      COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
    else
      IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
    fi
  fi
done
```

### Step 5 — Plugin compatibility check (PS-13-04)

Compare `BOOK_VERSION` (`created_with_bookbench` from `.book/config.yaml`) with the resolved `PLUGIN_VERSION`. Use semver-aware comparison; if string equality, no warning. If the major versions differ — emit a warning (do NOT exit non-zero).

```bash
COMPAT_NOTE=""
if [ -n "$BOOK_VERSION" ] && [ -n "$PLUGIN_VERSION" ] && [ "$PLUGIN_VERSION" != "unknown" ]; then
  BMAJ="${BOOK_VERSION%%.*}"
  PMAJ="${PLUGIN_VERSION%%.*}"
  if [ "$BMAJ" != "$PMAJ" ]; then
    COMPAT_NOTE="WARNING: book was created on bookbench $BOOK_VERSION, plugin is $PLUGIN_VERSION. Run /book:update to migrate (stage 14)."
  fi
fi
```

PS-13-04: warning, never hard-fail. The author should always be able to inspect `/book:status` even after a major bump.

### Step 6 — Registry sanity (optional, soft)

```bash
REGISTRY="$PLUGIN_DATA/registry.yaml"
REGISTERED="no"
if [ -f "$REGISTRY" ]; then
  if grep -F "  path: $(pwd)" "$REGISTRY" >/dev/null 2>&1; then
    REGISTERED="yes"
  fi
fi
```

### Step 7 — Print the summary

Output a compact human-readable block (≤ 25 lines), formatted like:

```
Book status — "${BOOK_TITLE}"
  Genre:           ${BOOK_GENRE}
  Language:        ${BOOK_LANGUAGE}
  Registry id:     ${BOOK_REGISTRY_ID}
  Created on:      bookbench ${BOOK_VERSION}    (current plugin: ${PLUGIN_VERSION})
  Registered:      ${REGISTERED}

Progress
  Section:         ${CURRENT_SECTION}
  Current chapter: ${CURRENT_CHAPTER:-none}
  Planned:         ${PLANNED_CHAPTERS} chapters in ROADMAP
  Completed:       ${COMPLETED_COUNT}
  In progress:     ${IN_PROGRESS_COUNT}

Last action
  ${LAST_ACTION}

Recent history
  ${LAST_HISTORY}

${COMPAT_NOTE}

Recommended next:
  /book:resume       — short briefing on what to do next.
```

The «recommended next» line varies by state:

- If `PLANNED_CHAPTERS == 0` and `IN_PROGRESS_COUNT == 0`: «Run `/book:plan-book` to draft the chapter list.»
- If `PLANNED_CHAPTERS > 0` and `COMPLETED_COUNT == 0`: «Run `/book:plan-chapter 1` to draft the spec for chapter 1.»
- If `IN_PROGRESS_COUNT > 0`: «Run `/book:resume` for a briefing on the in-progress chapter.»
- Otherwise: «Run `/book:plan-chapter <next-id>` to start the next chapter.»

### Constitutional rules for this command

- **MUST** be read-only — never Write, Edit, or Bash a destructive command.
- **MUST** complete in under 5 seconds on a 200-chapter book (no full-text reads).
- **MUST** never throw on missing optional files (`ROADMAP.md` may not exist before `/book:plan-book`).
- **NEVER** modify `STATE.md`.
- **NEVER** call any subagent through `Task`.

</execution>
