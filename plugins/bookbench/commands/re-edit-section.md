---
description: Перезапускает цикл редактуры главы N из версионной подпапки vN/. С флагом --from-audit берёт замечания из audit-report.md; иначе запрашивает список проблем у автора. Сохраняет предыдущий edited.md как v1 и создаёт v2 (или v3, ...). С --with-marketing дополнительно перезапускает агента book-marketer.
argument-hint: "<section-number> [--from-audit] [--with-marketing]"
allowed-tools: [Task, Read, Write, Edit, Bash, AskUserQuestion]
---

# /book:re-edit-section

<purpose>
Generate `sections/<id>/v2/` (or v3, ...) with a new draft, factcheck and edit pass driven by either an audit report or explicit author feedback. The old version stays in place — the coordinator surfaces both versions to the author at the gate.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `.book/sections/<id>/edited.md` (current).
- `.book/sections/<id>/audit-report.md` (if `--from-audit`).
- Author-provided issue list (if no `--from-audit`).

## Outputs

- `.book/sections/<id>/v2/{draft.md, factcheck.md, edited.md}` (or v3, ...).
- Updates to relevant role MEMORY.md files (the editor's own memory protocol).
- Updated STATE.md.

<execution>

Eight-step orchestrator: validate → resolve → choose source of issues → confirm → run editor (Task) → verify → state mutation → next-step.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory."; exit 0; }

# Parse section number
SECTION_N=""
FROM_AUDIT=0
WITH_MARKETING=0
for arg in $ARGUMENTS; do
  case "$arg" in
    --from-audit)       FROM_AUDIT=1 ;;
    --with-marketing)   WITH_MARKETING=1 ;;
    --*)                : ;;
    *)                  [ -z "$SECTION_N" ] && SECTION_N="$arg" ;;
  esac
done

if [ -z "$SECTION_N" ]; then
  echo "Error: /book:re-edit-section requires a section number."
  echo "Usage: /book:re-edit-section <N> [--from-audit] [--with-marketing]"
  exit 0
fi

SECTION_DIR=$(printf '.book/sections/section-%03d' "$SECTION_N")
[ -d "$SECTION_DIR" ] || { echo "Error: section $SECTION_N not found ($SECTION_DIR)."; exit 0; }
[ -f "$SECTION_DIR/edited.md" ] || {
  echo "Error: $SECTION_DIR/edited.md does not exist."
  echo "The section has not finished its first edit pass. Run /book:write-section $SECTION_N first."
  exit 0
}
```

### Step 2 — Determine next version number

```bash
NEXT_VER=2
while [ -d "$SECTION_DIR/v$NEXT_VER" ]; do
  NEXT_VER=$((NEXT_VER + 1))
done
NEW_VER_DIR="$SECTION_DIR/v$NEXT_VER"
mkdir -p "$NEW_VER_DIR"
```

### Step 3 — Source of issues (audit-report or author-provided)

```bash
ISSUES_FILE=""

if [ "$FROM_AUDIT" -eq 1 ]; then
  if [ ! -f "$SECTION_DIR/audit-report.md" ]; then
    echo "Error: --from-audit was passed but $SECTION_DIR/audit-report.md is missing."
    echo "Run /book:audit-section $SECTION_N first."
    exit 0
  fi
  ISSUES_FILE="$SECTION_DIR/audit-report.md"
else
  echo "What issues should the editor address in v$NEXT_VER?"
  echo "(End input with an empty line. AskUserQuestion will collect this.)"
  # Use AskUserQuestion to capture the issue list as free-text
  # Save to .book/.tmp/re-edit-issues-$$.md
  ISSUES_FILE=".book/.tmp/re-edit-$SECTION_N-v$NEXT_VER-issues.md"
  mkdir -p .book/.tmp
  # AskUserQuestion result captured to ISSUES_FILE
fi
```

If the issue list is empty:

```
No issues provided. Re-edit aborted.
```

Exit.

### Step 4 — Confirmation gate

Present an `AskUserQuestion`:

- Title: «Re-edit section <N> as v<NEXT_VER>?»
- Body:
  - `Source of issues: <ISSUES_FILE>`
  - `Output:           <NEW_VER_DIR>/`
  - `Re-run marketer:  <yes if --with-marketing else no>`
- Options:
  - `Run re-edit` — proceed.
  - `Show issues first` — print `<ISSUES_FILE>` head and re-ask.
  - `Cancel` — exit.

### Step 5 — Delegate to book-editor in re-edit mode

```
Task(
  subagent_type: book-editor,
  description: "Re-edit section <N> as v<NEXT_VER>",
  prompt: """
    You are book-editor in RE-EDIT mode.

    Source of issues: <ISSUES_FILE>
    Previous edited.md: <SECTION_DIR>/edited.md
    Output dir: <NEW_VER_DIR>/

    Required:
      1. Read <ISSUES_FILE> and the previous edited.md.
      2. Address each issue. For each, decide:
         - revise (in-place change in edited.md);
         - re-write (escalate to writer for that section);
         - reject (issue is invalid; document why).
      3. If you decide re-write — escalate to writer via your standard contract,
         passing the focused issue (the writer will produce a new draft.md in v<N>).
      4. Apply edits to produce <NEW_VER_DIR>/edited.md.
      5. Write <NEW_VER_DIR>/factcheck.md if any factual claims changed
         (re-run factcheck on changed paragraphs only).
      6. Append a one-paragraph summary to <NEW_VER_DIR>/edit-notes.md describing
         which issues were addressed and how.

    Constraints:
      - Do NOT modify v1 (the previous edited.md). Treat as immutable history.
      - Use voice-profile.md to maintain the book's voice.
      - Preserve any [INVARIANT] markers in the previous edited.md.
  """,
  files_to_read: [
    <ISSUES_FILE>,
    <SECTION_DIR>/edited.md,
    <SECTION_DIR>/spec.md,
    <SECTION_DIR>/draft.md,
    <SECTION_DIR>/factcheck.md,
    .book/context/voice-profile.md,
    .book/context/red-thread-keywords.md,
    .book/context/glossary.md,
    .book/agent-guidelines/editor/
  ]
)
```

### Step 6 — Optional marketing re-run

If `--with-marketing`:

```
Task(
  subagent_type: book-marketer,
  description: "Re-run marketing for v<NEXT_VER> of section <N>",
  prompt: ...,
  files_to_read: [<NEW_VER_DIR>/edited.md, .book/context/, .book/agent-guidelines/marketer/]
)
```

### Step 7 — Verify outputs

```bash
[ -s "$NEW_VER_DIR/edited.md" ] || {
  echo "Editor did not produce $NEW_VER_DIR/edited.md."
  exit 1
}
NEW_SHA=$(shasum -a 256 "$NEW_VER_DIR/edited.md" | awk '{print $1}')
OLD_SHA=$(shasum -a 256 "$SECTION_DIR/edited.md" | awk '{print $1}')
[ "$NEW_SHA" = "$OLD_SHA" ] && echo "Warning: v$NEXT_VER is byte-identical to v1 — editor may not have changed anything."
```

### Step 8 — Atomic state mutation + next-step

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '\n%s — `/book:re-edit-section %d` — produced v%d in %s\n' \
  "$NOW" "$SECTION_N" "$NEXT_VER" "$NEW_VER_DIR" >> .book/STATE.md

# Update section-state.yaml: add re_edit_versions list entry
if [ -f "$SECTION_DIR/section-state.yaml" ]; then
  # Best-effort YAML append
  echo "  - v$NEXT_VER: { created_at: \"$NOW\", source: $([ "$FROM_AUDIT" = 1 ] && echo audit-report || echo author-issues) }" \
    >> "$SECTION_DIR/section-state.yaml"
fi

echo "Re-edit done: v$NEXT_VER produced in $NEW_VER_DIR."
echo ""
echo "Recommended next:"
echo "  /book:audit-section $SECTION_N            — re-audit the new version."
echo "  /book:re-edit-section $SECTION_N --from-audit  — yet another iteration if needed."
```

### Constitutional rules

- **MUST** preserve the existing `edited.md` (v1) — never overwrite it.
- **MUST** create a versioned subfolder `v<N>/` and write all artefacts there.
- **MUST** confirm with the author before launching (Brief-Then-Execute).
- **MUST** delegate the actual edit to `book-editor` via `Task` — never edit section content from the orchestrator.
- **NEVER** invoke writer / marketer without explicit author consent.
- **NEVER** delete previous versions; they are part of the audit trail.

</execution>
