---
description: Extracts the current book's voice profile and optional voice samples into a single self-contained markdown pack. By default writes the pack to stdout; with --to-file <path> writes to a file outside the plugin tree. Read-only on .book/ — does not modify any source files. Used as a building block by voice save-as.
argument-hint: "[--to-stdout | --to-file <path>]"
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

# /book:voice extract

<purpose>
Pack .book/context/voice-profile.md + .book/agent-guidelines/writer/voice-samples.md into a single markdown file (the "voice pack" format from voices-helpers H2). The pack is what /book:voice save-as later stores in the personal library.
</purpose>

<!-- Stage 08.1, Wave B, T4: full implementation. PS-08.1-07 privacy enforcement. -->

<execution>

This command is a markdown prompt executed by Claude Code. It follows the eight-step orchestrator pattern abbreviated for a read-only data-shaping action: validate → resolve plugin paths → read inputs → action (pack via voices-helpers H2) → verify outputs → next-step message.

### Step 1 — Parse arguments

```bash
RAW="${ARGUMENTS:-}"
OUT_MODE="stdout"
OUT_FILE=""

set -- $RAW
while [ $# -gt 0 ]; do
  case "$1" in
    --to-stdout)
      OUT_MODE="stdout"
      ;;
    --to-file)
      shift
      OUT_FILE="${1:-}"
      OUT_MODE="file"
      ;;
    *)
      echo "voice extract: unknown flag '$1'" 1>&2
      ;;
  esac
  shift 2>/dev/null || true
done

if [ "$OUT_MODE" = "file" ] && [ -z "$OUT_FILE" ]; then
  echo "voice extract: --to-file requires a path argument" 1>&2
  exit 1
fi

echo "voice extract: out_mode=$OUT_MODE out_file=${OUT_FILE:-<none>}"
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
  echo "voice extract: cannot locate .book/ — run from inside a book directory."
  exit 1
fi

echo "PLUGIN_ROOT=$PLUGIN_ROOT BOOK_ROOT=$BOOK_ROOT"
```

### Step 3 — Privacy guard on output destination (PS-08.1-07)

If `--to-file <path>` was given, refuse to write inside the plugin tree.

```bash
if [ "$OUT_MODE" = "file" ]; then
  # Resolve absolute path of the requested target.
  case "$OUT_FILE" in
    /*) ABS_OUT="$OUT_FILE" ;;
    *)  ABS_OUT="$PWD/$OUT_FILE" ;;
  esac
  case "$ABS_OUT" in
    "$PLUGIN_ROOT"*)
      echo "voice extract: refusing to write inside plugin tree: $ABS_OUT" 1>&2
      exit 1
      ;;
  esac
fi
```

### Step 4 — Read inputs

```bash
PROFILE_PATH="$BOOK_ROOT/context/voice-profile.md"
SAMPLES_PATH="$BOOK_ROOT/agent-guidelines/writer/voice-samples.md"

if [ ! -f "$PROFILE_PATH" ]; then
  echo "voice extract: $PROFILE_PATH does not exist — nothing to extract." 1>&2
  exit 1
fi

# Sanity: the profile must not be a bare TBD shell — otherwise extraction is useless.
MEANINGFUL=$(grep -vE '^\s*$|^\s*#|^>|TBD|\(Add entries here\.\)|<!-- ' "$PROFILE_PATH" | wc -l | tr -d ' ')
if [ "${MEANINGFUL:-0}" -le 3 ]; then
  echo "voice extract: voice-profile.md looks empty (only TBD placeholders detected)." 1>&2
  echo "  Run /book:voice build first." 1>&2
  exit 1
fi
```

### Step 5 — Action: pack via voices-helpers H2

Read `${CLAUDE_PLUGIN_ROOT}/lib/voices-helpers.md` H2 once and apply the `pack_voice` recipe. The pack output is either streamed to stdout or written to `$OUT_FILE`.

```bash
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

if [ "$OUT_MODE" = "file" ]; then
  # Privacy guard re-check before final write.
  case "$ABS_OUT" in
    "$PLUGIN_ROOT"*)
      rm -f "$TMP_PACK"
      echo "voice extract: refusing to write inside plugin tree: $ABS_OUT" 1>&2
      exit 1
      ;;
  esac
  mkdir -p "$(dirname "$ABS_OUT")"
  cp "$TMP_PACK" "$ABS_OUT"
  echo "voice extract: pack written to $ABS_OUT"
else
  cat "$TMP_PACK"
fi

rm -f "$TMP_PACK"
```

### Step 6 — Verify outputs and next-step message

If `--to-file` was used, verify the file exists and is non-empty.

```bash
if [ "$OUT_MODE" = "file" ]; then
  if [ ! -s "$ABS_OUT" ]; then
    echo "voice extract: output file $ABS_OUT is empty — extraction failed." 1>&2
    exit 1
  fi
fi

cat <<'NEXT'
voice extract: done.

Next steps:
  /book:voice save-as <name>     — save the pack into ~/.bookbench/voices/<name>.md
  /book:voice import <name>      — replace the current book's voice with a saved one
  /book:voice list               — see all voices in your personal library
NEXT
```

### Constitutional rules for this command

- **MUST** be read-only on `.book/` — never modifies `voice-profile.md` or `voice-samples.md`.
- **MUST** apply privacy guard before every Write/cp site (PS-08.1-07).
- **NEVER** writes inside `${CLAUDE_PLUGIN_ROOT}`. The `--to-file` path is checked.
- **NEVER** writes inside `~/.bookbench/voices/` directly — that is the job of `/book:voice save-as`.

</execution>
