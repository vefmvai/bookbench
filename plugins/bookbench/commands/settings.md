---
description: Views or edits the global plugin settings ${CLAUDE_PLUGIN_DATA}/settings.yaml. Without arguments lists all sections. With <section> shows section-level fields. With <section>.<key>=<value> sets a field and verifies. Distinct from /book:config (which edits per-book .book/config.yaml). Affects every book on this machine.
argument-hint: "[<section>] [<key>=<value>]"
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

# /book:settings

<purpose>
Editor for `${CLAUDE_PLUGIN_DATA}/settings.yaml` — the global per-user plugin settings. Settings here are inherited by every book unless overridden by genre defaults (`defaults.yaml`) or per-book config (`.book/config.yaml`).
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `${CLAUDE_PLUGIN_DATA}/settings.yaml` (read; possibly edit).

## Outputs

- A formatted listing on stdout.
- `${CLAUDE_PLUGIN_DATA}/settings.yaml` (edit).
- `${CLAUDE_PLUGIN_DATA}/settings.log` — append-only log of changes.

<execution>

Eight-step pattern: validate → resolve → load → confirm → write → verify → log → next-step.

### Step 1 — Pre-flight + resolve plugin data

```bash
# H1: resolve plugin data
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  PLUGIN_DATA="$CLAUDE_PLUGIN_DATA"
elif [ -n "${LOCALAPPDATA:-}" ]; then
  PLUGIN_DATA="$LOCALAPPDATA/bookbench"
else
  PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"
fi
mkdir -p "$PLUGIN_DATA"
SETTINGS="$PLUGIN_DATA/settings.yaml"

# Bootstrap if absent
if [ ! -f "$SETTINGS" ]; then
  cat > "$SETTINGS" <<YAML
# BookBench global settings
# Affects every book on this machine.
# To override per-book, edit .book/config.yaml inside the book.

mcp_servers:
  enabled: []         # e.g. [tavily, brave, exa]
  tavily_api_key: ""
  brave_api_key: ""

evolver:
  min_books_for_analysis: 3
  default_apply_mode: propose

privacy:
  default_book_private: false
  default_include_in_evolver: true

ui:
  default_voice_strictness: standard
  default_section_target_chars: 20000

scan_paths:
  paths: []           # e.g. [/Users/me/Books, /Users/me/Documents/Writing]
YAML
  echo "Created default $SETTINGS."
fi
```

### Step 2 — Parse arguments

```bash
SECTION=""
ASSIGNMENT=""
for arg in $ARGUMENTS; do
  case "$arg" in
    *=*)        ASSIGNMENT="$arg" ;;
    --*)        : ;;
    *)          [ -z "$SECTION" ] && SECTION="$arg" ;;
  esac
done
```

### Step 3 — Mode A: list all (no arguments)

```bash
echo "Global settings: $SETTINGS"
echo ""
cat "$SETTINGS"
echo ""
echo "Recommended next:"
echo "  /book:settings mcp_servers          — see MCP server config."
echo "  /book:settings evolver              — see evolver thresholds."
echo "  /book:settings ui.default_voice_strictness=strict   — change a field."
```

### Step 4 — Mode B: section view (`<section>` only)

Print only the requested section. Validate against the known section list (`mcp_servers`, `evolver`, `privacy`, `ui`, `scan_paths`). On unknown section:

```
Error: section '<section>' not found in $SETTINGS.
Known sections: mcp_servers | evolver | privacy | ui | scan_paths
```

### Step 5 — Mode C: assignment

Same parser as `/book:config` Step 5. Compute `OLD_VALUE`. If unchanged — print «no-op» and exit.

### Step 6 — Confirmation gate

Present an `AskUserQuestion`:

- Title: «Update global setting `<KEY_PATH>`?»
- Body:
  - `current: <OLD_VALUE>`
  - `new:     <NEW_VALUE>`
  - Note: «This affects every book on this machine.»
- Options:
  - `Update` — proceed.
  - `Cancel` — exit.

### Step 7 — Apply + log

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$PLUGIN_DATA/.backup"
cp -p "$SETTINGS" "$PLUGIN_DATA/.backup/settings-$TS.yaml"

# Apply (similar awk to /book:config Step 7)
SECT=$(echo "$KEY_PATH" | cut -d. -f1)
KEY=$(echo "$KEY_PATH" | cut -d. -f2)
awk -v s="$SECT" -v k="$KEY" -v v="$NEW_VALUE" '
  $0 == s ":" { in_sect=1; print; next }
  in_sect && /^[a-zA-Z]/ { in_sect=0 }
  in_sect && $0 ~ "^  " k ":" { print "  " k ": " v; next }
  { print }
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

# Append to log
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s — settings %s: %s → %s\n' "$NOW" "$KEY_PATH" "$OLD_VALUE" "$NEW_VALUE" \
  >> "$PLUGIN_DATA/settings.log"
```

### Step 8 — Next-step message

```
Updated $KEY_PATH: $OLD_VALUE → $NEW_VALUE
Backup: $PLUGIN_DATA/.backup/settings-$TS.yaml

Recommended next:
  /book:settings $SECT          — see other fields in this section.
  /book:settings                — full settings view.
```

### Constitutional rules

- **MUST** create a backup before any edit.
- **MUST** confirm with the author before writing global settings (these affect every book on the machine).
- **MUST** keep an append-only log at `${CLAUDE_PLUGIN_DATA}/settings.log` for audit.
- **NEVER** read or write any book's `.book/config.yaml` from this command — that is `/book:config`.
- **NEVER** edit `defaults.yaml` (those are genre defaults shipped with the plugin).

</execution>
