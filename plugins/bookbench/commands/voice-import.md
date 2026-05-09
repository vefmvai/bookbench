---
description: Imports a saved voice from the personal library at ~/.bookbench/voices/<name>.md into the current book. Asks before overwriting non-empty .book/context/voice-profile.md or voice-samples.md. Writes only to .book/; reads only from the library; never writes inside the plugin tree.
argument-hint: "<name>"
allowed-tools: [Read, Write, Bash, Glob, Grep, AskUserQuestion]
---

# /book:voice import

<purpose>
Copy a saved voice pack from the personal library into the current book — fills .book/context/voice-profile.md and (if the pack carries samples) .book/agent-guidelines/writer/voice-samples.md. Confirms before overwriting non-empty existing files.
</purpose>

<!-- Stage 08.1, Wave B, T4: full implementation. PS-08.1-03 path resolution. PS-08.1-07 privacy enforcement. -->

<execution>

This command follows the eight-step orchestrator pattern: validate name → resolve plugin paths and book root → resolve voices library path → check source pack → check overwrite gate (AskUserQuestion if needed) → action (validate + unpack) → verify outputs → next-step message.

### Step 1 — Parse arguments and validate name

```bash
RAW="${ARGUMENTS:-}"
NAME=""

set -- $RAW
while [ $# -gt 0 ]; do
  case "$1" in
    -*) echo "voice import: unknown flag '$1'" 1>&2 ;;
    *)
      if [ -z "$NAME" ]; then
        NAME="$1"
      else
        echo "voice import: unexpected positional argument '$1'" 1>&2
      fi
      ;;
  esac
  shift 2>/dev/null || true
done

if [ -z "$NAME" ]; then
  echo "voice import: <name> is required. Usage: /book:voice import <name>" 1>&2
  exit 1
fi

if ! printf '%s' "$NAME" | grep -qE '^[a-z0-9_-]+$'; then
  echo "voice import: invalid name '$NAME' — only [a-z0-9_-] allowed." 1>&2
  exit 1
fi
```

### Step 2 — Resolve plugin paths and book root

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && {
  for c in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    [ -f "$c/manifest.json" ] && PLUGIN_ROOT="$c" && break
  done
}

BOOK_ROOT=""
if [ -d ".book" ]; then
  BOOK_ROOT="$PWD/.book"
elif [ -d "$PWD/agent-memory" ] && [ -f "$PWD/STATE.md" ]; then
  BOOK_ROOT="$PWD"
else
  echo "voice import: cannot locate .book/ — run from inside a book directory."
  exit 1
fi
```

### Step 3 — Resolve voices library path (voices-helpers H1) and locate source pack

```bash
resolve_voices_library_path() {
  if [ -n "${BOOKBENCH_VOICES_DIR:-}" ]; then echo "$BOOKBENCH_VOICES_DIR"; return 0; fi
  local cf="$HOME/.bookbench/config.yaml"
  if [ -f "$cf" ]; then
    local fc
    fc=$(awk -F: '/^voices_dir:/ {gsub(/^[ \t"]+|[ \t"]+$/, "", $2); print $2; exit}' "$cf")
    if [ -n "$fc" ]; then fc="${fc/#\~/$HOME}"; echo "$fc"; return 0; fi
  fi
  if [ -n "${LOCALAPPDATA:-}" ]; then echo "$LOCALAPPDATA/bookbench/voices"; return 0; fi
  if [ -n "${APPDATA:-}" ];      then echo "$APPDATA/bookbench/voices";      return 0; fi
  echo "$HOME/.bookbench/voices"
}
VOICES_DIR="$(resolve_voices_library_path)"
SOURCE_PACK="$VOICES_DIR/$NAME.md"

if [ ! -f "$SOURCE_PACK" ]; then
  echo "voice import: voice '$NAME' not found at $SOURCE_PACK" 1>&2
  echo "  Run /book:voice list to see available voices." 1>&2
  exit 1
fi

echo "voice import: source=$SOURCE_PACK"
```

### Step 4 — Validate the source pack (voices-helpers H3)

```bash
if ! grep -q '<!-- VOICE-PACK: section=voice-profile -->' "$SOURCE_PACK"; then
  echo "voice import: pack $SOURCE_PACK is broken — missing voice-profile marker." 1>&2
  exit 1
fi
if ! grep -q '<!-- /VOICE-PACK: section=voice-profile -->' "$SOURCE_PACK"; then
  echo "voice import: pack $SOURCE_PACK is broken — missing voice-profile closing marker." 1>&2
  exit 1
fi
if ! grep -q '<!-- VOICE-PACK: section=voice-samples -->' "$SOURCE_PACK"; then
  echo "voice import: pack $SOURCE_PACK is broken — missing voice-samples marker." 1>&2
  exit 1
fi
if ! grep -q '<!-- /VOICE-PACK: section=voice-samples -->' "$SOURCE_PACK"; then
  echo "voice import: pack $SOURCE_PACK is broken — missing voice-samples closing marker." 1>&2
  exit 1
fi
```

### Step 5 — Privacy guard on targets (PS-08.1-07)

```bash
PROFILE_PATH="$BOOK_ROOT/context/voice-profile.md"
SAMPLES_PATH="$BOOK_ROOT/agent-guidelines/writer/voice-samples.md"

case "$PROFILE_PATH" in
  "$PLUGIN_ROOT"*)
    echo "voice import: refusing to write inside plugin tree: $PROFILE_PATH" 1>&2
    exit 1
    ;;
esac
case "$SAMPLES_PATH" in
  "$PLUGIN_ROOT"*)
    echo "voice import: refusing to write inside plugin tree: $SAMPLES_PATH" 1>&2
    exit 1
    ;;
esac
```

### Step 6 — Overwrite gate (AskUserQuestion if existing files are non-empty)

```bash
PROFILE_HAS_CONTENT=0
SAMPLES_HAS_CONTENT=0

if [ -f "$PROFILE_PATH" ]; then
  M=$(grep -vE '^\s*$|^\s*#|^>|TBD|\(Add entries here\.\)|<!-- ' "$PROFILE_PATH" | wc -l | tr -d ' ')
  [ "${M:-0}" -gt 3 ] && PROFILE_HAS_CONTENT=1
fi
if [ -f "$SAMPLES_PATH" ]; then
  M=$(grep -vE '^\s*$|^\s*#|TBD|\(Author fills|\(Paste|\(Add entries here\.\)' "$SAMPLES_PATH" | wc -l | tr -d ' ')
  [ "${M:-0}" -gt 0 ] && SAMPLES_HAS_CONTENT=1
fi
echo "voice import: profile_has_content=$PROFILE_HAS_CONTENT samples_has_content=$SAMPLES_HAS_CONTENT"
```

If either has content, present an `AskUserQuestion`:

- Title: «Overwrite existing voice»
- Question: «The current book already has a non-empty voice profile or voice samples. Importing `$NAME` will overwrite them. Proceed?»
- Options: `Overwrite` / `Cancel` / `Show diff`.
- On `Cancel` — exit cleanly. On `Show diff` — Read both source and target, present a textual diff (key differences in the six parameters), then re-ask.

A backup of overwritten files is taken automatically before the unpack step:

```bash
if [ "$PROFILE_HAS_CONTENT" = "1" ] || [ "$SAMPLES_HAS_CONTENT" = "1" ]; then
  TS=$(date -u +%Y%m%dT%H%M%SZ)
  BAK="$BOOK_ROOT/.backup/voice-profile"
  mkdir -p "$BAK"
  [ -f "$PROFILE_PATH" ] && cp "$PROFILE_PATH" "$BAK/voice-profile.${TS}.md"
  [ -f "$SAMPLES_PATH" ] && cp "$SAMPLES_PATH" "$BAK/voice-samples.${TS}.md"
  echo "voice import: backed up existing files to $BAK/"
fi
```

### Step 7 — Action: unpack via voices-helpers H2 (final privacy re-check)

```bash
# Re-check privacy guards immediately before write.
case "$PROFILE_PATH" in
  "$PLUGIN_ROOT"*) echo "voice import: refusing plugin-tree write" 1>&2; exit 1 ;;
esac
case "$SAMPLES_PATH" in
  "$PLUGIN_ROOT"*) echo "voice import: refusing plugin-tree write" 1>&2; exit 1 ;;
esac

mkdir -p "$(dirname "$PROFILE_PATH")"
mkdir -p "$(dirname "$SAMPLES_PATH")"

awk -v profile_out="$PROFILE_PATH" -v samples_out="$SAMPLES_PATH" '
  /<!-- VOICE-PACK: section=voice-profile -->/   { mode="profile"; next }
  /<!-- \/VOICE-PACK: section=voice-profile -->/  { mode="";        next }
  /<!-- VOICE-PACK: section=voice-samples -->/   { mode="samples"; next }
  /<!-- \/VOICE-PACK: section=voice-samples -->/  { mode="";        next }
  {
    if (mode == "profile") print > profile_out
    else if (mode == "samples") print > samples_out
  }
' "$SOURCE_PACK"

# If the samples section was the literal "(no samples)" placeholder, restore the template.
if [ -f "$SAMPLES_PATH" ] && grep -q '^(no samples)$' "$SAMPLES_PATH" 2>/dev/null; then
  rm -f "$SAMPLES_PATH"
  if [ -f "$PLUGIN_ROOT/templates/agent-guidelines/writer/voice-samples.md" ]; then
    cp "$PLUGIN_ROOT/templates/agent-guidelines/writer/voice-samples.md" "$SAMPLES_PATH"
  fi
fi

echo "voice import: unpack ok"
```

### Step 8 — Verify outputs and clear voice_pending flag

```bash
if [ ! -s "$PROFILE_PATH" ]; then
  echo "voice import: $PROFILE_PATH is empty after unpack — import failed." 1>&2
  exit 1
fi
if ! grep -q '^## ' "$PROFILE_PATH"; then
  echo "voice import: $PROFILE_PATH has no markdown sections — import looks broken." 1>&2
  exit 1
fi

# Clear voice_pending flag if present (PS-08.1-04).
STATE_FILE="$BOOK_ROOT/STATE.md"
if [ -f "$STATE_FILE" ] && grep -q '^## voice_pending' "$STATE_FILE"; then
  awk '
    /^## voice_pending/ { skip=1; next }
    skip && /^## /      { skip=0 }
    !skip
  ' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  echo "voice import: cleared voice_pending flag from STATE.md"
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  echo ""
  echo "- ${NOW} — /book:voice import $NAME — voice imported from library."
} >> "$STATE_FILE"

cat <<NEXT
voice import: done.

Files written:
  $PROFILE_PATH
  $SAMPLES_PATH (only if the pack carried samples)

Voice from '$NAME' is now active. Continue with /book:write-section <N>.
NEXT
```

### Constitutional rules for this command

- **MUST** confirm via `AskUserQuestion` before overwriting non-empty existing files.
- **MUST** back up overwritten files into `.book/.backup/voice-profile/`.
- **MUST** apply privacy guard before every Write site (PS-08.1-07).
- **NEVER** writes inside `${CLAUDE_PLUGIN_ROOT}`.
- **NEVER** writes inside `~/.bookbench/voices/` — this command is one-way (library → book).

</execution>
