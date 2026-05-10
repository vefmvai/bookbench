---
name: workflow:edit
description: Opens .book/workflow.md in $EDITOR for direct edits. Backs up the current file to .book/.backup/workflow-<TS>.md before opening. After the editor closes, automatically runs /bookbench:workflow:check; if validation fails, offers to revert to backup. UX-04 from stage 7.2.
argument-hint: "[--in-editor]"
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

# /bookbench:workflow:edit

<purpose>
Direct manual edit of the workflow file via `$EDITOR`. Preferred when the author has a clear change in mind and prefers a text-editor workflow over an interactive dialog. After save, the file is validated automatically.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный дизайн — `workflow-management-design.md` § 3 этапа 7.2 -->

## Inputs

- `.book/workflow.md` (read; opened in `$EDITOR`).
- `${CLAUDE_PLUGIN_ROOT}/blocks-catalog.md` (read for help banner only).

## Outputs

- `.book/workflow.md` — possibly modified by the author.
- `.book/.backup/workflow-<TS>.md` — pre-edit copy.
- After save: report from `/bookbench:workflow:check`.

<execution>

Eight-step pattern: pre-flight → backup → open editor → validate → optional revert → state mutation → next-step.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory. Run /bookbench:start first."; exit 0; }

if [ ! -f .book/workflow.md ]; then
  echo "No .book/workflow.md. Either:"
  echo "  • Run /bookbench:start to create one from a preset."
  echo "  • Run /bookbench:research-genre <genre> to generate one."
  echo "  • Manually create .book/workflow.md with the YAML schema."
  exit 0
fi

# Detect $EDITOR
EDITOR_CMD="${EDITOR:-vi}"
if ! command -v "$EDITOR_CMD" >/dev/null 2>&1; then
  echo "Error: \$EDITOR ('$EDITOR_CMD') is not installed or not on PATH."
  echo "Set EDITOR=<command> in your shell, then re-run."
  exit 0
fi
```

### Step 2 — Confirmation gate

Present an `AskUserQuestion`:

- Title: «Edit `.book/workflow.md`?»
- Body: «This will:
  - Backup current `workflow.md` to `.book/.backup/workflow-<TS>.md`.
  - Open `workflow.md` in `$EDITOR` (`<EDITOR_CMD>`).
  - Run `/bookbench:workflow:check` automatically after save.»
- Options:
  - `Open editor` — proceed.
  - `Show current workflow first` — print the file head (≈80 lines) and re-ask.
  - `Cancel` — exit.

### Step 3 — Backup

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p .book/.backup
BACKUP=".book/.backup/workflow-$TS.md"
cp -p .book/workflow.md "$BACKUP"
SHA_BEFORE=$(shasum -a 256 .book/workflow.md | awk '{print $1}')
```

### Step 4 — Open editor

```bash
"$EDITOR_CMD" .book/workflow.md
RC=$?
if [ "$RC" -ne 0 ]; then
  echo "Warning: editor exited non-zero ($RC). The file may not have been saved."
fi

SHA_AFTER=$(shasum -a 256 .book/workflow.md | awk '{print $1}')
```

If `SHA_BEFORE == SHA_AFTER`:

```
No changes detected. Backup at $BACKUP is preserved.
```

Skip to Step 8.

### Step 5 — Auto-run /bookbench:workflow:check

If the file changed, run the validator inline (the same logic as `commands/workflow-check.md`). Capture exit code and report.

```bash
# Equivalent of running /bookbench:workflow:check
# Inline implementation: parse workflow.md, cross-reference catalog, build report
# (The validation logic mirrors workflow-check.md Step 2-4.)
CHECK_OUT=$(/* run inline validator; collect critical / high count */)
CHECK_RC=$?
echo "$CHECK_OUT"
```

### Step 6 — Optional revert

If the validator returned CRITICAL issues, present an `AskUserQuestion`:

- Title: «Workflow has CRITICAL issues»
- Body: List the first 5 critical issues from `CHECK_OUT`.
- Options:
  - `Keep changes (will fix later)` — leave the file as-is; the next `/bookbench:next` will warn.
  - `Revert to backup` — copy `$BACKUP` over `workflow.md`.
  - `Re-open editor` — re-open `$EDITOR` to fix and re-validate.

### Step 7 — STATE.md history append

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NLINES_BEFORE=$(wc -l < "$BACKUP")
NLINES_AFTER=$(wc -l < .book/workflow.md)
DIFF=$((NLINES_AFTER - NLINES_BEFORE))
printf '\n%s — `/bookbench:workflow:edit` — workflow edited (Δlines %+d, validator: %s)\n' \
  "$NOW" "$DIFF" "$([ "$CHECK_RC" -eq 0 ] && echo OK || echo "issues")" >> .book/STATE.md
```

### Step 8 — Next-step message

If validation clean:

```
Workflow saved. ✓ /bookbench:workflow:check passed.
Backup: $BACKUP

Recommended next:
  /bookbench:next       — verify the new workflow recommends what you expect.
  /bookbench:status     — see overall progress.
```

If validation has CRITICAL issues and the author chose «Keep»:

```
Workflow saved with CRITICAL issues. Backup: $BACKUP
/bookbench:next may misbehave until the issues are fixed.

Recommended next:
  /bookbench:workflow:edit         — re-open and fix.
  /bookbench:workflow:check        — re-run validation.
```

### Constitutional rules

- **MUST** create a backup before opening `$EDITOR`. The backup name must include a timestamp.
- **MUST** auto-run `/bookbench:workflow:check` after save (never trust the author's edit blindly).
- **MUST** offer revert if validation fails CRITICAL.
- **MUST** detect no-op edits via sha256 and skip the check + history append in that case.
- **NEVER** discard the backup file silently; backups are pruned by a separate housekeeping command (stage 15+).
- **NEVER** run any subagent — pure local operation.

</execution>
