---
description: Выводит список голосов, сохранённых в личной библиотеке ~/.bookbench/voices/ (путь резолвится хелпером voices-helpers H1). Для каждого голоса печатает имя, время последней модификации и краткую сводку из шести параметров голоса, извлечённую из заголовка пакета. Только чтение, ничего не пишет.
argument-hint: ""
allowed-tools: [Read, Bash, Glob, Grep]
---

# /book:voice list

<purpose>
Show the contents of the personal voices library so the author can pick a voice for /book:voice import.
</purpose>

<!-- Stage 08.1, Wave B, T4: full implementation. PS-08.1-03 path resolution. PS-08.1-07 read-only. -->

<execution>

This command follows the eight-step orchestrator pattern, abbreviated for a read-only inventory action: validate (no args) → resolve plugin paths → resolve voices library path → action (scan + format) → next-step message.

### Step 1 — Parse arguments (none expected)

```bash
RAW="${ARGUMENTS:-}"
if [ -n "$RAW" ]; then
  echo "voice list: this command takes no arguments (got '$RAW'); ignoring." 1>&2
fi
```

### Step 2 — Resolve plugin paths

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && {
  for c in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    [ -f "$c/manifest.json" ] && PLUGIN_ROOT="$c" && break
  done
}
```

### Step 3 — Resolve voices library path (voices-helpers H1)

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
echo "VOICES_DIR=$VOICES_DIR"
```

### Step 4 — Scan and print

```bash
if [ ! -d "$VOICES_DIR" ]; then
  echo "voice list: library directory does not exist yet ($VOICES_DIR)."
  echo "  Use /book:voice save-as <name> after /book:voice build to create your first voice."
  exit 0
fi

shopt -s nullglob 2>/dev/null || true
COUNT=0
printf "%-24s | %-20s | %s\n" "name" "saved (UTC)" "six parameters (formality | paragraph | sentence variety | emotional | dash | anglicism)"
printf "%-24s-+-%-20s-+-%s\n" "------------------------" "--------------------" "------------------------------------------------------------------------------"

for f in "$VOICES_DIR"/*.md; do
  [ -e "$f" ] || continue
  COUNT=$((COUNT + 1))
  NAME=$(basename "$f" .md)

  # Modification timestamp (portable: macOS uses BSD stat -f, Linux GNU stat -c).
  if MTIME=$(stat -f %Sm -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null); then
    : # macOS path
  else
    MTIME=$(stat -c '%y' "$f" 2>/dev/null | cut -c1-16)
  fi

  # Extract the six parameters from the profile section between markers.
  PARAMS=$(awk '
    /<!-- VOICE-PACK: section=voice-profile -->/  { in_profile=1; next }
    /<!-- \/VOICE-PACK: section=voice-profile -->/ { in_profile=0; next }
    in_profile && /^- Formality:/             { f=$0 }
    in_profile && /^- Paragraph length:/      { p=$0 }
    in_profile && /^- Sentence variety:/      { s=$0 }
    in_profile && /^- Emotional intensity:/   { e=$0 }
    in_profile && /^- Dash typography:/       { d=$0 }
    in_profile && /^- Anglicism tolerance:/   { a=$0 }
    END {
      gsub(/^- [^:]+: /, "", f)
      gsub(/^- [^:]+: /, "", p)
      gsub(/^- [^:]+: /, "", s)
      gsub(/^- [^:]+: /, "", e)
      gsub(/^- [^:]+: /, "", d)
      gsub(/^- [^:]+: /, "", a)
      if (f == "") f = "?"
      if (p == "") p = "?"
      if (s == "") s = "?"
      if (e == "") e = "?"
      if (d == "") d = "?"
      if (a == "") a = "?"
      print f " | " p " | " s " | " e " | " d " | " a
    }
  ' "$f")

  printf "%-24s | %-20s | %s\n" "$NAME" "$MTIME" "$PARAMS"
done

echo ""
if [ "$COUNT" = "0" ]; then
  echo "voice list: no voices saved yet."
  echo "  Build a voice with /book:voice build, then save it with /book:voice save-as <name>."
else
  echo "voice list: $COUNT voice(s) found."
fi
```

### Step 5 — Next-step message

```text
voice list: done.

To use a voice in the current book:
  /book:voice import <name>

To save the current book's voice into the library:
  /book:voice save-as <name>
```

### Constitutional rules for this command

- **MUST** be strictly read-only — no Write, no Edit, no cp/mv anywhere.
- **MUST** handle a missing library directory gracefully (print a hint, exit 0).
- **NEVER** writes inside `${CLAUDE_PLUGIN_ROOT}`, `.book/`, or `~/.bookbench/voices/`.

</execution>
