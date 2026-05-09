---
description: Re-runs only Phase 4 (book-editor) and the optional skill-mode passes (Phase 5) for chapter N. Uses existing draft.md and factcheck.md (status pass required, otherwise prompts to re-run factcheck). Backs up the previous edited.md.
argument-hint: "<chapter-number>"
allowed-tools: [Task, Read, Write, Edit, AskUserQuestion]
---

# /book:write-chapter:edit

<purpose>
Atomic re-run of the editor phase. See `phases-spec.md` § 4 and § 5 (etap 11).
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Preconditions

- A valid `draft.md` and `factcheck.md` exist.
- `factcheck.md.status: pass` is required. If not, the coordinator asks the author whether to re-run factcheck first.

## Outputs

- `.book/chapters/<id>/edited.md` (new).
- Optional `.book/chapters/<id>/reviews/<skill>.md` for each enabled skill-mode in `workflow.md > chapter_loop.enable_skill_reviews`.
- Optional Phase 4b re-check trigger if editor flags `[NEEDS_RECHECK]` blocks.

<execution>

Thin wrapper around `/book:write-chapter` Step 8 (editor) and optional Step 9 (skill-mode passes).

### Step 1 — Validate

```bash
ARG="$ARGUMENTS"
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
[ -z "$N" ] && { echo "Usage: /book:write-chapter:edit <chapter-number>"; exit 0; }
PADDED=$(printf '%03d' "$N")
CHDIR=".book/chapters/chapter-${PADDED}"
[ -d "$CHDIR" ] || { echo "$CHDIR does not exist."; exit 0; }
[ -s "$CHDIR/draft.md" ] || { echo "$CHDIR/draft.md is missing."; exit 0; }
[ -s "$CHDIR/factcheck.md" ] || { echo "$CHDIR/factcheck.md is missing. Run /book:write-chapter:factcheck $N first."; exit 0; }
STATUS=$(awk '/^status:/{print $2; exit}' "$CHDIR/factcheck.md" || echo unknown)
```

### Step 2 — Status check

If `STATUS != pass`, present an `AskUserQuestion`:

- Title: «Factcheck status is `${STATUS}`»
- Options:
  - `Re-run factcheck first` — print «Run /book:write-chapter:factcheck $N»; exit.
  - `Edit anyway (force)` — proceed.
  - `Cancel`.

### Step 3 — Backup existing edited.md

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
[ -f "$CHDIR/edited.md" ] && cp "$CHDIR/edited.md" "$CHDIR/edited-prev-${TS}.md"
sed -i.bak -E "s/^phase: .*/phase: editing/" "$CHDIR/chapter-state.yaml"
rm -f "$CHDIR/chapter-state.yaml.bak"
```

### Step 4 — Call editor

Identical to `/book:write-chapter` Step 8 (book-editor base-mode). Same `Task` invocation, same `<files_to_read>`.

### Step 5 — Optional Phase 5 skill-modes

Same as `/book:write-chapter` Step 9. Stage 13 default config has no skill reviews enabled.

### Step 6 — Verify and report

```bash
[ -s "$CHDIR/edited.md" ] || { echo "Editor did not produce edited.md"; exit 1; }
NEEDS_RECHECK=$(awk '/^needs_recheck_blocks:/{print $2; exit}' "$CHDIR/edited.md" || echo 0)
echo "edited.md regenerated for chapter $N. NEEDS_RECHECK blocks: $NEEDS_RECHECK"
echo "Recommended next: /book:write-chapter:market $N (if marketer enabled) or finalise via /book:write-chapter $N (full pipeline)."
```

### Step 7 — STATE update

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: write-chapter:edit ${N} re-run/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/book:write-chapter:edit %s` — edited.md regenerated\n' "$NOW" "$N" >> .book/STATE.md
```

### Constitutional rules

- **MUST** require factcheck `pass` (or explicit author override).
- **MUST** back up the existing edited.md.
- **NEVER** call writer or factchecker.

</execution>
