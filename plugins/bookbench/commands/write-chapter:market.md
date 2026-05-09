---
description: Re-runs only Phase 6 (book-marketer) for chapter N. Uses existing edited.md. Useful after target-audience or brand-voice changes. Errors out if workflow.md > chapter_loop.enable_marketer is false unless --force is supplied.
argument-hint: "<chapter-number> [--force]"
allowed-tools: [Task, Read, Write, Edit, AskUserQuestion]
---

# /book:write-chapter:market

<purpose>
Atomic re-run of the marketer phase. See `phases-spec.md` § 6 (etap 11).
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Preconditions

- A valid `edited.md` exists.
- `workflow.md > chapter_loop.enable_marketer: true` (or the author confirms `--force`).

## Outputs

- `.book/chapters/<id>/marketing.md` (new): three title variants, hook line, Telegram post draft, Midjourney prompt, social snippets.
- Updates to `marketer/MEMORY.md`.

<execution>

Thin wrapper around `/book:write-chapter` Step 10 (marketer).

### Step 1 — Validate

```bash
ARG="$ARGUMENTS"
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
FORCE=0
case "$ARG" in *--force*) FORCE=1 ;; esac
[ -z "$N" ] && { echo "Usage: /book:write-chapter:market <chapter-number> [--force]"; exit 0; }
PADDED=$(printf '%03d' "$N")
CHDIR=".book/chapters/chapter-${PADDED}"
[ -d "$CHDIR" ] || { echo "$CHDIR does not exist."; exit 0; }
[ -s "$CHDIR/edited.md" ] || { echo "$CHDIR/edited.md is missing. Run /book:write-chapter $N first."; exit 0; }
```

### Step 2 — Marketer enablement check

```bash
ENABLED=$(awk '/^  - marketer/{print 1; exit}' .book/config.yaml | head -1)
[ -z "$ENABLED" ] && ENABLED=0
if [ "$ENABLED" != "1" ] && [ "$FORCE" != "1" ]; then
  echo "Marketer is not enabled in .book/config.yaml.agents.enabled."
  echo "Pass --force to run anyway, or enable marketer via /book:config (stage 14)."
  exit 0
fi
```

### Step 3 — Backup existing marketing.md

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
[ -f "$CHDIR/marketing.md" ] && cp "$CHDIR/marketing.md" "$CHDIR/marketing-prev-${TS}.md"
sed -i.bak -E "s/^phase: .*/phase: marketing/" "$CHDIR/chapter-state.yaml"
rm -f "$CHDIR/chapter-state.yaml.bak"
```

### Step 4 — Call marketer

Identical to `/book:write-chapter` Step 10. Same `Task` invocation, same `<files_to_read>`.

### Step 5 — Verify and report

```bash
[ -s "$CHDIR/marketing.md" ] || { echo "Marketer did not produce marketing.md"; exit 1; }
echo "marketing.md regenerated for chapter $N."
echo "Recommended next: /book:audit-chapter $N (when chapter is finalised) or /book:plan-chapter $((N+1))."
```

### Step 6 — STATE update

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: write-chapter:market ${N} re-run/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/book:write-chapter:market %s` — marketing.md regenerated\n' "$NOW" "$N" >> .book/STATE.md
```

### Constitutional rules

- **MUST** check marketer is enabled (or `--force`).
- **MUST** require `edited.md` to exist.
- **NEVER** modify `edited.md`.
- **NEVER** call writer, factchecker, editor.

</execution>
