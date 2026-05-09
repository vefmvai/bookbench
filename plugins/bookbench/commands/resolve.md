---
description: Resolves a competing-variant from INGEST-DECISIONS.md after /book:import. Without an action argument runs an interactive dialog with the variant context; with a|b|merge|reject applies the choice directly. Updates the destination file (section draft, glossary entry, voice sample, agent memory) and records the resolution in INGEST-DECISIONS.md.
argument-hint: "<variant-id> [a|b|merge|reject]"
allowed-tools: [Task, Read, Write, Edit, Bash, AskUserQuestion]
---

# /book:resolve

<purpose>
Finalise a single competing-variant after import. Without an argument: dialog with full context. With one of `a|b|merge|reject`: applied immediately with confirmation. Symmetric companion to `/book:import` which leaves competing variants pending.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `<variant-id>` from `INGEST-DECISIONS.md` (e.g. `V-01`).
- Optional resolution `a | b | merge | reject`.
- `.book/intel/classifications/*.json` for the relevant variant context.

## Outputs

- `.book/INGEST-DECISIONS.md` — variant moved from `Competing-variants` into `Auto-resolved` or `Rejected`.
- Destination file updated (section draft, glossary entry, agent memory) per the chosen action.

<execution>

Eight-step pattern with optional Task delegation to `book-doc-synthesizer` (when `merge` requires combining two variants).

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory."; exit 0; }
[ -f .book/INGEST-DECISIONS.md ] || {
  echo "No INGEST-DECISIONS.md. Run /book:import first."
  exit 0
}

# Parse arguments
VARIANT_ID=""
ACTION=""
for arg in $ARGUMENTS; do
  case "$arg" in
    a|b|merge|reject)   ACTION="$arg" ;;
    --*)                : ;;
    *)                  [ -z "$VARIANT_ID" ] && VARIANT_ID="$arg" ;;
  esac
done

if [ -z "$VARIANT_ID" ]; then
  echo "Error: /book:resolve requires a variant id."
  echo "Usage: /book:resolve <variant-id> [a|b|merge|reject]"
  echo ""
  echo "Pending variants:"
  awk '/^- V-/ {print "  " $2}' .book/INGEST-DECISIONS.md
  exit 0
fi
```

### Step 2 — Locate variant in INGEST-DECISIONS.md

```bash
# Extract the variant block (assumes "Competing variants" section format)
VARIANT_BLOCK=$(awk -v id="$VARIANT_ID" '
  $0 ~ "^- " id { in_block=1; print; next }
  in_block && /^- V-/ { in_block=0 }
  in_block { print }
' .book/INGEST-DECISIONS.md)

if [ -z "$VARIANT_BLOCK" ]; then
  echo "Error: variant $VARIANT_ID not found in pending list."
  echo "Run /book:resolve (no argument) to see available ids."
  exit 0
fi
```

### Step 3 — Render context for the author

```
== Variant $VARIANT_ID ==

$VARIANT_BLOCK

The variant has up to two candidates:
  (a) <option-a-summary>
  (b) <option-b-summary>

Possible actions:
  a       — accept option (a) and write to destination.
  b       — accept option (b) and write to destination.
  merge   — combine (a) and (b) using book-doc-synthesizer.
  reject  — drop both; the destination remains unchanged.
```

### Step 4 — Choose action (interactive if not given)

If `$ACTION` is empty, present an `AskUserQuestion`:

- Title: «Resolve `<VARIANT_ID>`?»
- Body: as in Step 3.
- Options: `a`, `b`, `merge`, `reject`, `cancel`.

### Step 5 — Confirmation gate

Present an `AskUserQuestion` (always, even if action was given on CLI):

- Title: «Confirm resolution `<VARIANT_ID>` = `<ACTION>`?»
- Body: brief summary of what will be written / removed.
- Options:
  - `Apply` — proceed.
  - `Show details first` — show the full variant block again and re-ask.
  - `Cancel` — exit.

### Step 6 — Apply the action

**Action `a` or `b`:**

- Read the corresponding payload from the variant block.
- Determine the destination path (the variant block contains `destination: <path>` for each option).
- Backup the existing destination file (if any) to `.book/.backup/`.
- Apply the payload via `Write` (create) or `Edit` (append/replace).

**Action `merge`:**

- Delegate to `book-doc-synthesizer` via `Task`:

```
Task(
  subagent_type: book-doc-synthesizer,
  description: "Merge variant <VARIANT_ID>",
  prompt: """
    You are book-doc-synthesizer in MERGE mode (memory: none).
    Variant: <VARIANT_ID>
    Option (a): <payload-a>
    Option (b): <payload-b>
    Destination: <dest-path>

    Required: produce a single payload combining the best of both options
    while honouring the destination's existing content. Write to <dest-path>.
  """,
  files_to_read: [<dest-path> if exists, .book/intel/classifications/<...>.json]
)
```

**Action `reject`:**

- No file is modified.
- The variant is moved to the `Rejected` bucket in INGEST-DECISIONS.md with a one-line reason (collected via AskUserQuestion).

### Step 7 — Update INGEST-DECISIONS.md

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Move the V- block from Competing variants to (Applied | Rejected).
# Best-effort awk: remove the matching V- block from one section, append to another.
awk -v id="$VARIANT_ID" -v action="$ACTION" -v now="$NOW" '
  BEGIN { skip=0 }
  $0 ~ "^- " id { skip=1; next }
  skip && /^- V-/ { skip=0 }
  skip && /^## / { skip=0 }
  !skip { print }
  END {
    print ""
    if (action == "reject") { print "## Rejected (added " now ")" }
    else                    { print "## Applied (added " now ")" }
    print "- " id " resolved as " action " at " now
  }
' .book/INGEST-DECISIONS.md > .book/INGEST-DECISIONS.md.tmp \
  && mv .book/INGEST-DECISIONS.md.tmp .book/INGEST-DECISIONS.md
```

### Step 8 — STATE.md + next-step

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '\n%s — `/book:resolve` — variant %s resolved as %s\n' \
  "$NOW" "$VARIANT_ID" "$ACTION" >> .book/STATE.md

# Count remaining pending
PENDING=$(awk '/^## Competing/{in_sect=1; next} /^## /{in_sect=0} in_sect && /^- V-/{c++} END{print c+0}' .book/INGEST-DECISIONS.md)

echo "Variant $VARIANT_ID resolved as $ACTION."
echo "Remaining pending variants: $PENDING"
echo ""
if [ "$PENDING" -gt 0 ]; then
  echo "Recommended next:"
  echo "  /book:resolve <next-variant-id>   — keep going."
else
  echo "All variants resolved."
  echo "Recommended next:"
  echo "  /book:status            — see overall progress."
  echo "  /book:plan-book         — (re-)plan now that everything is in place."
fi
```

### Constitutional rules

- **MUST** confirm with the author before writing — even if action is given on CLI.
- **MUST** backup any destination file that already exists before overwriting.
- **MUST** support `merge` only via `book-doc-synthesizer` Task — never inline merge.
- **MUST** update INGEST-DECISIONS.md atomically — variant moves from one bucket to another in one edit.
- **NEVER** apply multiple variants in one invocation — one variant per call.
- **NEVER** read raw author input files (`.book/inputs/`) — work only on the synthesizer's classifications and the destination files.

</execution>
