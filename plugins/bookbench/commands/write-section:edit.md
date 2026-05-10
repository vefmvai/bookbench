---
description: Re-runs only Phase 4 (book-editor) and the optional skill-mode passes (Phase 5) for section N. Uses existing draft.md and factcheck.md (status pass required, otherwise prompts to re-run factcheck). Backs up the previous edited.md.
argument-hint: "<section-number>"
allowed-tools: [Task, Read, Write, Edit, AskUserQuestion]
---

# /bookbench:write-section:edit

<purpose>
Atomic re-run of the editor phase. See `phases-spec.md` § 4 and § 5 (etap 11).
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Preconditions

- A valid `draft.md` and `factcheck.md` exist.
- `factcheck.md.status: pass` is required. If not, the coordinator asks the author whether to re-run factcheck first.

## Outputs

- `.book/sections/<id>/edited.md` (new).
- Optional `.book/sections/<id>/reviews/<skill>.md` for each enabled skill-mode in `workflow.md > section_loop.enable_skill_reviews`.
- Optional Phase 4b re-check trigger if editor flags `[NEEDS_RECHECK]` blocks.

<execution>

Thin wrapper around `/bookbench:write-section` Step 8 (editor) and optional Step 9 (skill-mode passes).

### Step 1 — Validate

```bash
ARG="$ARGUMENTS"
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
[ -z "$N" ] && { echo "Usage: /bookbench:write-section:edit <section-number>"; exit 0; }
PADDED=$(printf '%03d' "$N")
CHDIR=".book/sections/section-${PADDED}"
[ -d "$SECDIR" ] || { echo "$CHDIR does not exist."; exit 0; }
[ -s "$SECDIR/draft.md" ] || { echo "$SECDIR/draft.md is missing."; exit 0; }
[ -s "$SECDIR/factcheck.md" ] || { echo "$SECDIR/factcheck.md is missing. Run /bookbench:write-section:factcheck $N first."; exit 0; }
STATUS=$(awk '/^status:/{print $2; exit}' "$SECDIR/factcheck.md" || echo unknown)
```

### Step 2 — Status check

If `STATUS != pass`, present an `AskUserQuestion`:

- Title: «Factcheck status is `${STATUS}`»
- Options:
  - `Re-run factcheck first` — print «Run /bookbench:write-section:factcheck $N»; exit.
  - `Edit anyway (force)` — proceed.
  - `Cancel`.

### Step 3 — Backup existing edited.md

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
[ -f "$SECDIR/edited.md" ] && cp "$SECDIR/edited.md" "$SECDIR/edited-prev-${TS}.md"
sed -i.bak -E "s/^phase: .*/phase: editing/" "$SECDIR/section-state.yaml"
rm -f "$SECDIR/section-state.yaml.bak"
```

### Step 4 — Call editor

Identical to `/bookbench:write-section` Step 8 (book-editor base-mode). Same `Task` invocation, same `<files_to_read>`.

### Step 5 — Optional Phase 5 skill-modes

Same as `/bookbench:write-section` Step 9. Stage 13 default config has no skill reviews enabled.

### Step 6 — Verify and report

```bash
[ -s "$SECDIR/edited.md" ] || { echo "Editor did not produce edited.md"; exit 1; }
NEEDS_RECHECK=$(awk '/^needs_recheck_blocks:/{print $2; exit}' "$SECDIR/edited.md" || echo 0)
echo "edited.md regenerated for section $N. NEEDS_RECHECK blocks: $NEEDS_RECHECK"
echo "Recommended next: /bookbench:write-section:market $N (if marketer enabled) or finalise via /bookbench:write-section $N (full pipeline)."
```

### Step 7 — STATE update

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: write-section:edit ${N} re-run/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/bookbench:write-section:edit %s` — edited.md regenerated\n' "$NOW" "$N" >> .book/STATE.md
```

### Constitutional rules

- **MUST** require factcheck `pass` (or explicit author override).
- **MUST** back up the existing edited.md.
- **NEVER** call writer or factchecker.

</execution>
