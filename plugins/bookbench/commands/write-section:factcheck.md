---
description: Re-runs only Phase 3 (book-factchecker) for section N with the configured revise-loop. Backs up the previous factcheck.md and resets factcheck_iteration_count. On exhaustion of the loop runs ESCALATE-flow with REJECTIONS-LOG entry.
argument-hint: "<section-number>"
allowed-tools: [Task, Read, Write, Edit, AskUserQuestion]
---

# /book:write-section:factcheck

<purpose>
Atomic re-run of the factchecker phase. See `phases-spec.md` § 3 (etap 11).
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Preconditions

- A valid `draft.md` exists.

## Outputs

- `.book/sections/<id>/factcheck.md` (new) with status `pass | revise-required | escalate`.
- On revise-required and iteration < `factcheck_max_iterations`: invokes `book-writer` in revise-mode and loops back.
- On exhaustion: appends to `REJECTIONS-LOG.md` and runs `AskUserQuestion` (hedging, drop claim, manual source, accept with `[ASSUMED]`).

<execution>

Thin wrapper around `/book:write-section` Step 7 (factchecker loop with DEC-03 limit).

### Step 1 — Validate

```bash
ARG="$ARGUMENTS"
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
[ -z "$N" ] && { echo "Usage: /book:write-section:factcheck <section-number>"; exit 0; }
PADDED=$(printf '%03d' "$N")
CHDIR=".book/sections/section-${PADDED}"
[ -d "$SECDIR" ] || { echo "$CHDIR does not exist."; exit 0; }
[ -s "$SECDIR/draft.md" ] || { echo "$SECDIR/draft.md is missing. Run /book:write-section:draft $N first."; exit 0; }
```

### Step 2 — Backup existing factcheck

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
[ -f "$SECDIR/factcheck.md" ] && cp "$SECDIR/factcheck.md" "$SECDIR/factcheck-prev-${TS}.md"
sed -i.bak -E "s/^factcheck_iteration_count: .*/factcheck_iteration_count: 0/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^factcheck_status: .*/factcheck_status: null/" "$SECDIR/section-state.yaml"
sed -i.bak -E "s/^phase: .*/phase: factcheck/" "$SECDIR/section-state.yaml"
rm -f "$SECDIR/section-state.yaml.bak"
```

### Step 3 — Run loop

Run the factcheck-loop exactly as `/book:write-section` Step 7 (DEC-03 max 3 iterations, with writer revise-mode in between, ESCALATE-flow on exhaustion). Re-use the same `Task` recipes and the same `<files_to_read>` lists.

### Step 4 — Verify and report

```bash
STATUS=$(awk '/^status:/{print $2; exit}' "$SECDIR/factcheck.md" || echo unknown)
ITER=$(awk '/^factcheck_iteration_count:/{print $2; exit}' "$SECDIR/section-state.yaml" || echo 0)
echo "Factcheck loop completed for section $N: status=$STATUS, iterations=$ITER"
echo "Recommended next: /book:write-section:edit $N (if status=pass) or inspect REJECTIONS-LOG.md"
```

### Step 5 — STATE update

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: write-section:factcheck ${N} ($STATUS)/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/book:write-section:factcheck %s` — status=%s iter=%s\n' "$NOW" "$N" "$STATUS" "$ITER" >> .book/STATE.md
```

### Constitutional rules

- **MUST** preserve DEC-03 loop limit (3 iterations + ESCALATE).
- **MUST** call writer in revise-mode between factcheck iterations.
- **NEVER** call editor, marketer.

</execution>
