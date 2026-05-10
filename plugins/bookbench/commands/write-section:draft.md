---
description: Re-runs only Phase 2 (book-writer) for section N. Uses the existing spec.md, backs up the previous draft.md to draft-prev-<timestamp>.md, resets factcheck_iteration_count, and produces a new draft. Useful after voice calibration or guideline changes.
argument-hint: "<section-number>"
allowed-tools: [Task, Read, Write, Edit, AskUserQuestion]
---

# /bookbench:write-section:draft

<purpose>
Atomic re-run of the writer phase. See `entry-point-design.md` § 2.2 (etap 11) and `phases-spec.md` § 2.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Preconditions

- A valid `sections/<id>/spec.md` exists.
- (Optional) An existing `draft.md` will be moved to `draft-prev-<timestamp>.md`.

## Outputs

- `.book/sections/<id>/draft.md` (new).
- Reset of `section-state.yaml`: `factcheck_iteration_count: 0`, `factcheck_status: null`, `phase: writing`.

<execution>

Thin wrapper around `/bookbench:write-section` Step 6 (writer). PS-13-06: stage 13 implements as a focused re-run that calls only `book-writer`.

### Step 1 — Validate

```bash
ARG="$ARGUMENTS"
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
[ -z "$N" ] && { echo "Usage: /bookbench:write-section:draft <section-number>"; exit 0; }
PADDED=$(printf '%03d' "$N")
CHDIR=".book/sections/section-${PADDED}"
[ -d "$SECDIR" ] || { echo "$CHDIR does not exist. Run /bookbench:plan-section $N first."; exit 0; }
[ -s "$SECDIR/spec.md" ] || { echo "$SECDIR/spec.md is missing. Run /bookbench:plan-section $N first."; exit 0; }
```

### Step 2 — Backup existing draft

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
[ -f "$SECDIR/draft.md" ] && cp "$SECDIR/draft.md" "$SECDIR/draft-prev-${TS}.md"
```

### Step 3 — Reset section-state

```bash
sed -i.bak -E "s/^phase: .*/phase: writing/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^factcheck_iteration_count: .*/factcheck_iteration_count: 0/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^factcheck_status: .*/factcheck_status: null/" "$SECDIR/section-state.yaml"
rm -f "$SECDIR/section-state.yaml.bak"
```

### Step 4 — Call writer

Same `Task` invocation as `/bookbench:write-section` Step 6 (book-writer initial draft mode). Same `<files_to_read>`. Same prompt template.

### Step 5 — Verify and report

```bash
[ -s "$SECDIR/draft.md" ] || { echo "Writer did not produce draft.md"; exit 1; }
WC=$(wc -w < "$SECDIR/draft.md")
echo "draft.md regenerated for section $N (${WC} words)."
echo "Recommended next: /bookbench:write-section:factcheck $N"
```

### Step 6 — STATE update

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: write-section:draft ${N} re-run/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/bookbench:write-section:draft %s` — draft regenerated\n' "$NOW" "$N" >> .book/STATE.md
```

### Constitutional rules

- **MUST** back up the existing draft before regenerating.
- **MUST** reset factcheck-loop state.
- **NEVER** call factchecker, editor, marketer.

</execution>
