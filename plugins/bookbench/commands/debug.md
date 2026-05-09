---
description: Manages persistent debug sessions for long investigations into sections, registries or guidelines that span multiple Claude Code sessions. State lives in .book/debug/<slug>.md. Without arguments lists active sessions; with a slug resumes; --new <slug> creates; --close <slug> marks resolved with a final note.
argument-hint: "[<slug>] [--new] [--close]"
allowed-tools: [Read, Write, Edit, Bash, Glob, AskUserQuestion]
---

# /book:debug

<purpose>
A separate "investigator mode" of the main dialog — not a subagent invocation. Holds reasoning state across sessions in a markdown file. Useful when chasing down subtle bugs in factcheck, voice drift, glossary inconsistency, or any other multi-session investigation.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный контракт — `debug-design.md` этапа 07 -->

## Inputs

- `.book/debug/<slug>.md` (existing or new).
- The current book context.

## Outputs

- A new or updated debug file under `.book/debug/`.
- A timestamp record in `.book/STATE.md`.

<execution>

Read-modify pattern. Six steps.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory. Run /book:start first."; exit 0; }
mkdir -p .book/debug

# Parse arguments: first positional = slug; flags --new, --close
SLUG=""
ACTION="resume"   # default if slug given
for arg in $ARGUMENTS; do
  case "$arg" in
    --new)        ACTION="new" ;;
    --close)      ACTION="close" ;;
    --*)          : ;;
    *)            [ -z "$SLUG" ] && SLUG="$arg" ;;
  esac
done
```

### Step 2 — Mode A: list (no slug, no flags)

If `$SLUG` and `$ACTION` is the default and no slug was given:

```bash
if [ -z "$SLUG" ]; then
  ACTIVE=$(find .book/debug -maxdepth 1 -name '*.md' -not -name 'archived-*' 2>/dev/null)
  if [ -z "$ACTIVE" ]; then
    echo "No active debug sessions."
    echo ""
    echo "Recommended next:"
    echo "  /book:debug --new <slug>     — start a new investigation."
    exit 0
  fi
  echo "Active debug sessions:"
  for f in $ACTIVE; do
    base=$(basename "$f" .md)
    title=$(awk '/^# /{sub(/^# /, ""); print; exit}' "$f")
    last=$(awk '/^Last updated:/ {sub(/^Last updated:[ ]*/, ""); print; exit}' "$f")
    printf '  %-30s — %s (last: %s)\n' "$base" "$title" "$last"
  done
  echo ""
  echo "Recommended next:"
  echo "  /book:debug <slug>           — resume an investigation."
  echo "  /book:debug --new <slug>     — start a new one."
  exit 0
fi
```

### Step 3 — Mode B: --new <slug>

```bash
if [ "$ACTION" = "new" ]; then
  [ -z "$SLUG" ] && {
    echo "Error: --new requires a slug."
    echo "Usage: /book:debug --new <slug>"
    exit 0
  }

  DBG=".book/debug/$SLUG.md"
  if [ -f "$DBG" ]; then
    echo "Error: $DBG already exists. Use /book:debug $SLUG to resume."
    exit 0
  fi

  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$DBG" <<MD
# Debug: $SLUG

Created: $NOW
Last updated: $NOW
Status: open

## Problem statement

(describe the problem you are investigating here)

## Hypothesis

(working hypothesis)

## Findings

(running list of what you discover; date each entry)

## Next actions

(what to try next)

## Resolution

(filled in when /book:debug --close $SLUG)
MD

  echo "Created $DBG. Open it in your editor or describe the problem here in the dialog."
  echo ""
  echo "Recommended next:"
  echo "  /book:debug $SLUG          — resume to add findings."
  echo "  /book:debug --close $SLUG  — close when resolved."
  exit 0
fi
```

### Step 4 — Mode C: resume <slug>

```bash
if [ "$ACTION" = "resume" ] && [ -n "$SLUG" ]; then
  DBG=".book/debug/$SLUG.md"
  [ -f "$DBG" ] || {
    echo "Error: $DBG does not exist."
    echo "Use /book:debug --new $SLUG to create it."
    exit 0
  }

  # Show file content
  echo "── $DBG ──"
  cat "$DBG"
  echo "── end ──"
  echo ""

  # Update Last updated
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  sed -i.bak -E "s/^Last updated:.*$/Last updated: $NOW/" "$DBG"
  rm -f "$DBG.bak"
fi
```

The author is expected to add new findings via the regular dialog (the coordinator can write directly into `<DBG>` when asked). For stage 14 the command shows the file and notes the timestamp; richer interactive editing is a stage 15 polish item.

### Step 5 — Mode D: --close <slug>

```bash
if [ "$ACTION" = "close" ]; then
  [ -z "$SLUG" ] && { echo "Error: --close requires a slug."; exit 0; }
  DBG=".book/debug/$SLUG.md"
  [ -f "$DBG" ] || { echo "Error: $DBG does not exist."; exit 0; }
```

Present an `AskUserQuestion`:

- Title: «Close debug session `<SLUG>`?»
- Body: «What is the resolution? (1-3 lines.)»
- Options: free-text input.

Append to the debug file:

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RESOLUTION="$(cat /tmp/bookbench-debug-resolution.txt 2>/dev/null || echo 'Resolved.')"
sed -i.bak -E "s/^Status:.*$/Status: closed/" "$DBG"
sed -i.bak -E "s/^Last updated:.*$/Last updated: $NOW/" "$DBG"
rm -f "$DBG.bak"
cat >> "$DBG" <<MD

## Closed on $NOW

$RESOLUTION
MD

  # Optionally rename the file with archived prefix
  mv "$DBG" ".book/debug/archived-$SLUG.md" 2>/dev/null || true
fi
```

### Step 6 — STATE.md history append + next-step

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
case "$ACTION" in
  new)
    printf '\n%s — `/book:debug --new` — opened debug session %s\n' "$NOW" "$SLUG" >> .book/STATE.md ;;
  resume)
    printf '\n%s — `/book:debug` — resumed debug session %s\n' "$NOW" "$SLUG" >> .book/STATE.md ;;
  close)
    printf '\n%s — `/book:debug --close` — closed debug session %s\n' "$NOW" "$SLUG" >> .book/STATE.md ;;
esac

echo ""
echo "Recommended next:"
echo "  /book:debug                  — list other active sessions."
echo "  /book:debug --new <slug>     — start a new investigation."
```

### Constitutional rules

- **MUST** keep debug files under `.book/debug/` only — never elsewhere.
- **MUST** distinguish open vs closed via the `Status:` line and (optionally) the `archived-` filename prefix.
- **NEVER** delete a debug file — closed ones are renamed to `archived-<slug>.md`.
- **NEVER** invoke any subagent — pure local file operation.
- **NEVER** auto-run any other command (e.g. close should not also archive the book).

</execution>
