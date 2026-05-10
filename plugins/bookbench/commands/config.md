---
description: Views or edits the current book configuration .book/config.yaml. Without arguments prints the active cascade (book overrides genre defaults overrides global settings). With <section> shows section-level fields. With <section>.<key>=<value> sets a field and verifies. Records the change in STATE.md. UX from CMD-12 (etap 7).
argument-hint: "[<section>] [<key>=<value>]"
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

# /bookbench:config

<purpose>
Dashboard editor for the current book. Distinct from `/bookbench:settings` (which edits the global plugin settings). Three-level cascade: `${CLAUDE_PLUGIN_DATA}/settings.yaml` → `${CLAUDE_PLUGIN_ROOT}/defaults.yaml` (per genre) → `.book/config.yaml`.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `.book/config.yaml` (read; possibly edit).
- `${CLAUDE_PLUGIN_ROOT}/defaults.yaml` (read) — genre defaults for cascade display.
- `${CLAUDE_PLUGIN_DATA}/settings.yaml` (read) — global settings for cascade display.

## Outputs

- Cascade-aware view on stdout.
- `.book/config.yaml` (edit).
- `STATE.md` line of the form `config edited: <field>: <old> → <new>`.

<execution>

Eight-step pattern.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory. Run /bookbench:start first."; exit 0; }
[ -f .book/config.yaml ] || {
  echo "No .book/config.yaml. Run /bookbench:start to create it."
  exit 0
}

# Resolve plugin paths
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
DEFAULTS=""
[ -n "$PLUGIN_ROOT" ] && [ -f "$PLUGIN_ROOT/defaults.yaml" ] && DEFAULTS="$PLUGIN_ROOT/defaults.yaml"

if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  PLUGIN_DATA="$CLAUDE_PLUGIN_DATA"
elif [ -n "${LOCALAPPDATA:-}" ]; then
  PLUGIN_DATA="$LOCALAPPDATA/bookbench"
else
  PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"
fi
SETTINGS="$PLUGIN_DATA/settings.yaml"
```

### Step 2 — Parse arguments

Three call shapes:

- `/bookbench:config` — list all sections with cascade display.
- `/bookbench:config <section>` — show section-level fields.
- `/bookbench:config <section>.<key>=<value>` — set a field.
- `/bookbench:config <key>=<value>` — set a top-level field.

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

### Step 3 — Mode A: full cascade view (no arguments)

Print sections from `config-design.md` § 2.1 (etap 06): `book`, `writing`, `agents`, `quality_gates`, `mcp_servers`, `compatibility`, `privacy`. For each section, render `key | book-value | genre-default | global-default | effective`.

```
Configuration cascade for «My Book»

[book]
  title:                 My Book           (book)
  genre:                 popular-science   (book)
  language:              en                (book)
  bookbench_version:     0.1.0             (book)

[writing]
  section_target_chars:  20000             (book)        defaults: 25000      effective: 20000
  voice_strictness:      strict            (book)        defaults: standard   effective: strict

[quality_gates]
  factcheck_threshold:   0.8               (defaults)                         effective: 0.8
  ...

Recommended next:
  /bookbench:config writing                 — see writing section in detail.
  /bookbench:config writing.target=18000    — change a value.
```

### Step 4 — Mode B: section view (`<section>` only)

Print only the requested section. Validate `$SECTION` against the known list.

### Step 5 — Mode C: assignment (`<key>=<value>` or `<section>.<key>=<value>`)

Parse `ASSIGNMENT` into key path and new value:

```bash
KEY_PATH=$(echo "$ASSIGNMENT" | cut -d= -f1)
NEW_VALUE=$(echo "$ASSIGNMENT" | cut -d= -f2-)

# If KEY_PATH has no dot but SECTION is set, prepend the section
case "$KEY_PATH" in
  *.*)  : ;;
  *)    [ -n "$SECTION" ] && KEY_PATH="$SECTION.$KEY_PATH" ;;
esac
```

Read the current value:

```bash
SECT=$(echo "$KEY_PATH" | cut -d. -f1)
KEY=$(echo "$KEY_PATH" | cut -d. -f2)
OLD_VALUE=$(awk -v s="$SECT" -v k="$KEY" '
  $0 == s ":" { in_sect=1; next }
  in_sect && /^[a-zA-Z]/ { in_sect=0 }
  in_sect && $0 ~ "^  " k ":" { sub(/^[^:]+: */, ""); print; exit }
' .book/config.yaml)
```

### Step 6 — Confirmation gate

Present an `AskUserQuestion`:

- Title: «Update `<KEY_PATH>`?»
- Body:
  - `current: <OLD_VALUE>`
  - `new:     <NEW_VALUE>`
- Options:
  - `Update` — proceed.
  - `Cancel` — exit.

### Step 7 — Apply edit

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
cp -p .book/config.yaml ".book/.backup/config-$TS.yaml" 2>/dev/null || \
  { mkdir -p .book/.backup && cp -p .book/config.yaml ".book/.backup/config-$TS.yaml"; }

# In-place edit (single-key replacement)
awk -v s="$SECT" -v k="$KEY" -v v="$NEW_VALUE" '
  $0 == s ":" { in_sect=1; print; next }
  in_sect && /^[a-zA-Z]/ { in_sect=0 }
  in_sect && $0 ~ "^  " k ":" { print "  " k ": " v; next }
  { print }
' .book/config.yaml > .book/config.yaml.tmp && mv .book/config.yaml.tmp .book/config.yaml
```

Verify:

```bash
NEW_READ=$(awk -v s="$SECT" -v k="$KEY" '
  $0 == s ":" { in_sect=1; next }
  in_sect && /^[a-zA-Z]/ { in_sect=0 }
  in_sect && $0 ~ "^  " k ":" { sub(/^[^:]+: */, ""); print; exit }
' .book/config.yaml)

if [ "$NEW_READ" != "$NEW_VALUE" ]; then
  echo "Warning: edit may not have committed; current value is '$NEW_READ'."
fi
```

### Step 8 — STATE.md history append + next-step

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '\n%s — `/bookbench:config` — %s: %s → %s\n' \
  "$NOW" "$KEY_PATH" "$OLD_VALUE" "$NEW_VALUE" >> .book/STATE.md

echo "Updated $KEY_PATH: $OLD_VALUE → $NEW_VALUE"
echo ""
echo "Recommended next:"
echo "  /bookbench:config $SECT       — see other fields in this section."
echo "  /bookbench:config             — full cascade view."
```

### Constitutional rules

- **MUST** display the cascade (book vs genre-default vs global) when listing.
- **MUST** create a backup before any edit.
- **MUST** verify the edit committed by re-reading the file.
- **NEVER** edit `defaults.yaml` (genre defaults) or `settings.yaml` (global) — those are `/plugin update` and `/bookbench:settings` territory.
- **NEVER** retroactively re-process existing sections when `language` or `genre` change — only future blocks see the new value.

</execution>
