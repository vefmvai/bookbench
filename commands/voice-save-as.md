---
description: Saves the current book's voice profile into the personal cross-book library at ~/.bookbench/voices/<name>.md (path resolved by voices-helpers H1). Refuses to overwrite an existing voice unless --overwrite is passed. Writes only to the library; never to .book/ or to the plugin tree.
argument-hint: "<name> [--overwrite]"
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

# /book:voice save-as

<purpose>
Pack the current book's voice (profile + optional samples) and store it as a single markdown file in the personal voices library, so the same voice can be reused across future books via /book:voice import.
</purpose>

<!-- Stage 08.1, Wave B, T4: full implementation. PS-08.1-03 path resolution. PS-08.1-07 privacy enforcement. -->

<execution>

This command follows the eight-step orchestrator pattern: validate name → resolve plugin paths → resolve voices library path → check overwrite gate → action (pack + copy) → verify outputs → next-step message.

### Step 1 — Parse arguments and validate name

```bash
RAW="${ARGUMENTS:-}"
NAME=""
OVERWRITE=0

set -- $RAW
while [ $# -gt 0 ]; do
  case "$1" in
    --overwrite) OVERWRITE=1 ;;
    -*)          echo "voice save-as: unknown flag '$1'" 1>&2 ;;
    *)
      if [ -z "$NAME" ]; then
        NAME="$1"
      else
        echo "voice save-as: unexpected positional argument '$1'" 1>&2
      fi
      ;;
  esac
  shift 2>/dev/null || true
done

if [ -z "$NAME" ]; then
  echo "voice save-as: <name> is required. Usage: /book:voice save-as <name> [--overwrite]" 1>&2
  exit 1
fi

if ! printf '%s' "$NAME" | grep -qE '^[a-z0-9_-]+$'; then
  echo "voice save-as: invalid name '$NAME' — only [a-z0-9_-] allowed (no spaces, no dots)." 1>&2
  exit 1
fi

echo "voice save-as: name=$NAME overwrite=$OVERWRITE"
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
  echo "voice save-as: cannot locate .book/ — run from inside a book directory."
  exit 1
fi
```

### Step 3 — Resolve voices library path (voices-helpers H1)

Read `${CLAUDE_PLUGIN_ROOT}/lib/voices-helpers.md` H1 once and apply the recipe.

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
mkdir -p "$VOICES_DIR"
TARGET_PATH="$VOICES_DIR/$NAME.md"
echo "VOICES_DIR=$VOICES_DIR TARGET=$TARGET_PATH"
```

### Step 4 — Privacy guards (PS-08.1-07)

Refuse to write inside the plugin tree even if `BOOKBENCH_VOICES_DIR` was misconfigured.

```bash
case "$TARGET_PATH" in
  "$PLUGIN_ROOT"*)
    echo "voice save-as: refusing to write inside plugin tree: $TARGET_PATH" 1>&2
    echo "  Check BOOKBENCH_VOICES_DIR or ~/.bookbench/config.yaml — voices_dir must NOT point inside the plugin." 1>&2
    exit 1
    ;;
  "$BOOK_ROOT"*)
    echo "voice save-as: refusing to write inside the current book: $TARGET_PATH" 1>&2
    echo "  voices_dir must point to a cross-book location." 1>&2
    exit 1
    ;;
esac
```

### Step 5 — Overwrite gate

```bash
if [ -e "$TARGET_PATH" ] && [ "$OVERWRITE" = "0" ]; then
  echo "voice save-as: $TARGET_PATH already exists." 1>&2
  echo "  Pass --overwrite to replace, or pick a different name." 1>&2
  exit 1
fi
```

If `OVERWRITE=1` and the target exists — also surface an `AskUserQuestion`:

- Title: «Overwrite voice in library»
- Question: «`$NAME.md` already exists in your voices library. Overwrite?»
- Options: `Yes, overwrite` / `No, abort` / `Show existing`.
- On `No, abort` — exit. On `Show existing` — Read `$TARGET_PATH`, then re-ask.

### Step 6 — Action: pack and write

Read `${CLAUDE_PLUGIN_ROOT}/lib/voices-helpers.md` H2 once and apply `pack_voice`.

```bash
PROFILE_PATH="$BOOK_ROOT/context/voice-profile.md"
SAMPLES_PATH="$BOOK_ROOT/agent-guidelines/writer/voice-samples.md"

if [ ! -f "$PROFILE_PATH" ]; then
  echo "voice save-as: $PROFILE_PATH does not exist — run /book:voice build first." 1>&2
  exit 1
fi

MEANINGFUL=$(grep -vE '^\s*$|^\s*#|^>|TBD|\(Add entries here\.\)|<!-- ' "$PROFILE_PATH" | wc -l | tr -d ' ')
if [ "${MEANINGFUL:-0}" -le 3 ]; then
  echo "voice save-as: voice-profile.md looks empty — nothing to save. Run /book:voice build first." 1>&2
  exit 1
fi

TMP_PACK=$(mktemp)
{
  echo "<!-- VOICE-PACK: section=voice-profile -->"
  cat "$PROFILE_PATH"
  echo ""
  echo "<!-- /VOICE-PACK: section=voice-profile -->"
  echo ""
  echo "<!-- VOICE-PACK: section=voice-samples -->"
  if [ -f "$SAMPLES_PATH" ] && [ -s "$SAMPLES_PATH" ]; then
    SAMPLE_MEANINGFUL=$(grep -vE '^\s*$|^\s*#|TBD|\(Author fills|\(Paste|\(Add entries here\.\)' "$SAMPLES_PATH" | wc -l | tr -d ' ')
    if [ "${SAMPLE_MEANINGFUL:-0}" -gt 0 ]; then
      cat "$SAMPLES_PATH"
    else
      echo "(no samples)"
    fi
  else
    echo "(no samples)"
  fi
  echo ""
  echo "<!-- /VOICE-PACK: section=voice-samples -->"
} > "$TMP_PACK"

# Final privacy re-check.
case "$TARGET_PATH" in
  "$PLUGIN_ROOT"*)
    rm -f "$TMP_PACK"
    echo "voice save-as: refusing to write inside plugin tree: $TARGET_PATH" 1>&2
    exit 1
    ;;
esac

mv "$TMP_PACK" "$TARGET_PATH"
echo "voice save-as: pack written to $TARGET_PATH"
```

### Step 7 — Verify outputs

```bash
if [ ! -s "$TARGET_PATH" ]; then
  echo "voice save-as: $TARGET_PATH is empty — save failed." 1>&2
  exit 1
fi
if ! grep -q '<!-- VOICE-PACK: section=voice-profile -->' "$TARGET_PATH"; then
  echo "voice save-as: pack format is broken — missing voice-profile marker." 1>&2
  exit 1
fi
echo "voice save-as: verify ok"
```

### Step 8 — Next-step message

```text
voice save-as: done.

Saved to your personal voices library:
  $TARGET_PATH

To reuse this voice in another book:
  cd <other-book-folder>
  /book:voice import $NAME

To list all saved voices:
  /book:voice list
```

### Constitutional rules for this command

- **MUST** validate `<name>` against `^[a-z0-9_-]+$` to keep filenames portable across filesystems.
- **MUST** refuse to overwrite without `--overwrite` even if a file exists.
- **MUST** apply privacy guard before every Write/cp/mv site (PS-08.1-07).
- **NEVER** writes inside `${CLAUDE_PLUGIN_ROOT}`.
- **NEVER** writes inside `.book/` — this command produces a side-effect only in the cross-book library.

</execution>
