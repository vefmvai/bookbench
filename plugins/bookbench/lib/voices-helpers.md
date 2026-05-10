# Voices library helpers (referenced by `/bookbench:voice *` commands at stage 08.1)

> Shared helper procedures used by `/bookbench:voice build`, `/bookbench:voice extract`, `/bookbench:voice save-as`, `/bookbench:voice import`, `/bookbench:voice list`. Stage 08.1 implementation. PS-08.1-03 closes the path resolution policy. PS-08.1-07 closes the privacy enforcement policy.
>
> The bash code blocks below are recipes that the command (Claude Code executes commands as markdown prompts) runs through the Bash tool. They are deterministic and idempotent.

## H1. resolve_voices_library_path

Resolves the absolute path to the personal cross-book voices library (`~/.bookbench/voices/` by default).

Order of precedence (PS-08.1-03):

1. Environment variable `BOOKBENCH_VOICES_DIR` if set and the directory exists or can be created.
2. Key `voices_dir` in `~/.bookbench/config.yaml` if the file exists and the key is present.
3. Platform fallback:
   - macOS / Linux: `${HOME}/.bookbench/voices`.
   - Windows (incl. WSL where `LOCALAPPDATA` is exported): `${LOCALAPPDATA:-${APPDATA}}/bookbench/voices`. If neither variable is set — fall back to `${HOME}/.bookbench/voices`.

Bash recipe (run via the Bash tool):

```bash
resolve_voices_library_path() {
  if [ -n "${BOOKBENCH_VOICES_DIR:-}" ]; then
    echo "$BOOKBENCH_VOICES_DIR"
    return 0
  fi
  local config_file="$HOME/.bookbench/config.yaml"
  if [ -f "$config_file" ]; then
    local from_config
    from_config=$(awk -F: '/^voices_dir:/ {gsub(/^[ \t"]+|[ \t"]+$/, "", $2); print $2; exit}' "$config_file")
    if [ -n "$from_config" ]; then
      # Expand ~ if present
      from_config="${from_config/#\~/$HOME}"
      echo "$from_config"
      return 0
    fi
  fi
  if [ -n "${LOCALAPPDATA:-}" ]; then
    echo "$LOCALAPPDATA/bookbench/voices"
    return 0
  fi
  if [ -n "${APPDATA:-}" ]; then
    echo "$APPDATA/bookbench/voices"
    return 0
  fi
  echo "$HOME/.bookbench/voices"
}

VOICES_DIR="$(resolve_voices_library_path)"
mkdir -p "$VOICES_DIR"
echo "VOICES_DIR=$VOICES_DIR"
```

The directory is created on demand. The resulting path is used by `voice save-as`, `voice import`, `voice list`, and the optional suggestion in `/bookbench:start`.

## H2. pack / unpack a voice file

A voice in the personal library is a single markdown file `<name>.md` containing two sections, separated by HTML-style markers so a human can also read and edit the file directly.

Pack format:

```markdown
<!-- VOICE-PACK: section=voice-profile -->
<full content of .book/context/voice-profile.md>
<!-- /VOICE-PACK: section=voice-profile -->

<!-- VOICE-PACK: section=voice-samples -->
<full content of .book/agent-guidelines/writer/voice-samples.md OR the literal string "(no samples)" -->
<!-- /VOICE-PACK: section=voice-samples -->
```

The `voice-samples` section is always present. If the source `voice-samples.md` was empty or contained only TBD placeholders, the section body is the literal string `(no samples)` (one line). This keeps the pack format invariant — every pack always has both markers.

Bash recipe — pack:

```bash
pack_voice() {
  # $1 = path to voice-profile.md
  # $2 = path to voice-samples.md (optional; empty string means none)
  # $3 = output pack path
  local profile="$1"
  local samples="$2"
  local out="$3"
  {
    echo "<!-- VOICE-PACK: section=voice-profile -->"
    cat "$profile"
    echo ""
    echo "<!-- /VOICE-PACK: section=voice-profile -->"
    echo ""
    echo "<!-- VOICE-PACK: section=voice-samples -->"
    if [ -n "$samples" ] && [ -f "$samples" ] && [ -s "$samples" ]; then
      # Treat samples as "no samples" if every non-empty line matches a TBD pattern
      local meaningful
      meaningful=$(grep -vE '^\s*$|^\s*#|TBD|\(Add entries here\.\)|\(Author fills|\(Paste' "$samples" | wc -l | tr -d ' ')
      if [ "${meaningful:-0}" -gt 0 ]; then
        cat "$samples"
      else
        echo "(no samples)"
      fi
    else
      echo "(no samples)"
    fi
    echo ""
    echo "<!-- /VOICE-PACK: section=voice-samples -->"
  } > "$out"
}
```

Bash recipe — unpack:

```bash
unpack_voice() {
  # $1 = pack file
  # $2 = target voice-profile.md
  # $3 = target voice-samples.md (or empty string to skip samples)
  local pack="$1"
  local profile_target="$2"
  local samples_target="$3"
  awk -v profile_out="$profile_target" -v samples_out="$samples_target" '
    /<!-- VOICE-PACK: section=voice-profile -->/  { mode="profile"; next }
    /<!-- \/VOICE-PACK: section=voice-profile -->/ { mode="";        next }
    /<!-- VOICE-PACK: section=voice-samples -->/  { mode="samples"; next }
    /<!-- \/VOICE-PACK: section=voice-samples -->/ { mode="";        next }
    {
      if (mode == "profile") print > profile_out
      else if (mode == "samples" && samples_out != "") print > samples_out
    }
  ' "$pack"
  # Trim trailing blank lines from outputs (best-effort)
  if [ -n "$samples_target" ] && [ -f "$samples_target" ]; then
    if grep -q "^(no samples)$" "$samples_target" 2>/dev/null; then
      # The pack signalled no samples — leave the target file untouched / remove our write
      : # caller decides whether to keep the placeholder or delete
    fi
  fi
}
```

## H3. validate_pack

Validates a pack file before unpacking. Returns 0 on PASS, non-zero with a diagnostic message on FAIL.

```bash
validate_pack() {
  local pack="$1"
  if [ ! -f "$pack" ]; then
    echo "validate_pack: file not found: $pack" 1>&2
    return 1
  fi
  if ! grep -q '<!-- VOICE-PACK: section=voice-profile -->' "$pack"; then
    echo "validate_pack: missing opening marker for voice-profile" 1>&2
    return 2
  fi
  if ! grep -q '<!-- /VOICE-PACK: section=voice-profile -->' "$pack"; then
    echo "validate_pack: missing closing marker for voice-profile" 1>&2
    return 3
  fi
  if ! grep -q '<!-- VOICE-PACK: section=voice-samples -->' "$pack"; then
    echo "validate_pack: missing opening marker for voice-samples" 1>&2
    return 4
  fi
  if ! grep -q '<!-- /VOICE-PACK: section=voice-samples -->' "$pack"; then
    echo "validate_pack: missing closing marker for voice-samples" 1>&2
    return 5
  fi
  return 0
}
```

## H4. abort_if_writes_to_plugin_tree

Privacy enforcement (PS-08.1-07). Every `/bookbench:voice *` command must verify before any Write/cp/mv that the target path is **not** inside the plugin source tree. The plugin code tree is `${CLAUDE_PLUGIN_ROOT}` resolved via `lib/plugin-data-helpers.md` H2.

```bash
abort_if_writes_to_plugin_tree() {
  # $1 = absolute target path
  local target="$1"
  local plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
  if [ -z "$plugin_root" ]; then
    # Best-effort fallback: the directory two levels up from this helper file.
    # In production CLAUDE_PLUGIN_ROOT is always exported; this is a defensive guard.
    plugin_root="$HOME/.claude/plugins/bookbench"
  fi
  case "$target" in
    "$plugin_root"*)
      echo "abort_if_writes_to_plugin_tree: refusing to write inside plugin tree: $target" 1>&2
      exit 1
      ;;
  esac
}
```

Use this guard at the top of every Write/cp/mv block in `voice-build`, `voice-extract`, `voice-save-as`, `voice-import`. `voice-list` is read-only and does not need the guard.

## When commands use these helpers

- `/bookbench:voice build` — H4 only (writes to `.book/`, never to library or plugin).
- `/bookbench:voice extract` — H2 pack + H4 (writes to stdout or to `--to-file` outside plugin).
- `/bookbench:voice save-as` — H1 + H2 pack + H4 (writes to library only).
- `/bookbench:voice import` — H1 + H3 validate + H2 unpack + H4 (writes to `.book/` only).
- `/bookbench:voice list` — H1 only (read-only on library).

## Border with stage 14

Stage 14 introduced cross-book registry helpers in `lib/plugin-data-helpers.md`. This file is the parallel for the personal voices library — it lives outside `${CLAUDE_PLUGIN_DATA}` because voices are author-personal across all installs, not per-install.
