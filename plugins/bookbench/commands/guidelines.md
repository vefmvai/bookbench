---
description: Lists or opens guideline files in .book/agent-guidelines/<role>/. Without arguments lists all roles with file counts. With <role> lists files in that role's folder. With <role> <file> opens the file content (and optionally in $EDITOR). Manual edits are recorded in TUNING-LOG.md with applied_by manual approved_by author.
argument-hint: "[<role>] [<file>]"
allowed-tools: [Read, Write, Edit, Bash, Glob, AskUserQuestion]
---

# /bookbench:guidelines

<purpose>
Manual access to per-role guidelines without going through the tuner. The guidelines folder holds book-specific overrides for each subagent: trusted sources for the factchecker, voice samples for the writer, forbidden phrases per role, etc. Direct edits made via this command are logged so the tuner can later analyse patterns.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `<role>` ∈ {coordinator, strategist, writer, factchecker, editor, marketer, classifier, synthesizer, tuner}.
- `<file>` (optional) — guideline file in that folder, with or without `.md`.

## Outputs

- A formatted listing or file content on stdout.
- Optionally: opens the file in `$EDITOR`; on save writes to `.book/TUNING-LOG.md`.

<execution>

Eight-step pattern (read-only by default; edit branch adds optional Edit step).

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory. Run /bookbench:start first."; exit 0; }

GUIDELINES_DIR=".book/agent-guidelines"
if [ ! -d "$GUIDELINES_DIR" ]; then
  echo "Error: $GUIDELINES_DIR/ does not exist."
  echo "It should have been created by /bookbench:start. Run /bookbench:doctor."
  exit 0
fi

# Parse arguments: first positional = role, second = file
ROLE=""
FILE=""
for arg in $ARGUMENTS; do
  case "$arg" in
    --*)            : ;;  # ignore flags for now
    *)              [ -z "$ROLE" ] && ROLE="$arg" || [ -z "$FILE" ] && FILE="$arg" ;;
  esac
done

# Validate role if given
VALID_ROLES="coordinator strategist writer factchecker editor marketer classifier synthesizer tuner"
if [ -n "$ROLE" ]; then
  if ! echo "$VALID_ROLES" | tr ' ' '\n' | grep -qx "$ROLE"; then
    echo "Error: unknown role '$ROLE'."
    echo "Valid: $VALID_ROLES"
    exit 0
  fi
fi
```

### Step 2 — Mode A: no arguments — list all roles

If `$ROLE` is empty, print a per-role summary:

```
Guidelines in $GUIDELINES_DIR:

  coordinator/    — N files (last edited Y days ago)
  strategist/     — N files
  writer/         — N files
  factchecker/    — N files
  editor/         — N files
  marketer/       — N files
  classifier/     — N files
  synthesizer/    — N files
  tuner/          — N files

Recommended next:
  /bookbench:guidelines writer            — list writer's guideline files.
  /bookbench:guidelines factchecker       — list factchecker's guideline files.
```

```bash
for role in $VALID_ROLES; do
  count=$(find "$GUIDELINES_DIR/$role" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  printf '  %-15s — %s files\n' "$role/" "$count"
done
```

### Step 3 — Mode B: role given, no file — list files in role's folder

If `$ROLE` is set and `$FILE` is empty:

```bash
ROLE_DIR="$GUIDELINES_DIR/$ROLE"
[ -d "$ROLE_DIR" ] || { echo "No folder for role '$ROLE'."; exit 0; }

printf 'Guidelines for role: %s\n' "$ROLE"
printf '  path: %s\n\n' "$ROLE_DIR"

for f in $(ls -1 "$ROLE_DIR"/*.md 2>/dev/null); do
  base=$(basename "$f" .md)
  size=$(wc -c < "$f" | tr -d ' ')
  lines=$(wc -l < "$f" | tr -d ' ')
  printf '  %-30s — %s lines, %s bytes\n' "$base" "$lines" "$size"
done

echo ""
echo "Recommended next:"
echo "  /bookbench:guidelines $ROLE <file>       — view/edit a specific file."
echo "  /bookbench:tune                          — get tuner suggestions."
```

### Step 4 — Mode C: role + file — show / edit

If both `$ROLE` and `$FILE` are set:

```bash
# Tolerate .md suffix
FILE_BASE="${FILE%.md}"
FILE_PATH="$GUIDELINES_DIR/$ROLE/$FILE_BASE.md"

if [ ! -f "$FILE_PATH" ]; then
  echo "Error: '$FILE_PATH' does not exist."
  echo ""
  echo "Existing files in $ROLE/:"
  ls -1 "$GUIDELINES_DIR/$ROLE/"*.md 2>/dev/null | xargs -n1 basename
  echo ""
  echo "To create a new file:"
  echo "  /bookbench:guidelines $ROLE $FILE_BASE --new   (stage 15+ feature)"
  exit 0
fi
```

Print the file content:

```bash
echo "── $FILE_PATH ──"
cat "$FILE_PATH"
echo "── end ──"
```

### Step 5 — Optional edit gate

After printing, present an `AskUserQuestion`:

- Title: «Open `<FILE_PATH>` in `$EDITOR`?»
- Options:
  - `Open editor` — proceed to Step 6.
  - `Cancel` — exit (printed content is enough).

### Step 6 — Backup + open editor

```bash
EDITOR_CMD="${EDITOR:-vi}"
if ! command -v "$EDITOR_CMD" >/dev/null 2>&1; then
  echo "Error: \$EDITOR ('$EDITOR_CMD') is not on PATH."
  exit 0
fi

TS=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p .book/.backup
BACKUP=".book/.backup/guidelines-$ROLE-$FILE_BASE-$TS.md"
cp -p "$FILE_PATH" "$BACKUP"
SHA_BEFORE=$(shasum -a 256 "$FILE_PATH" | awk '{print $1}')

"$EDITOR_CMD" "$FILE_PATH"

SHA_AFTER=$(shasum -a 256 "$FILE_PATH" | awk '{print $1}')
```

### Step 7 — Record manual edit in TUNING-LOG.md

If the file changed (`SHA_BEFORE != SHA_AFTER`), append an entry to `.book/TUNING-LOG.md`:

```bash
if [ "$SHA_BEFORE" != "$SHA_AFTER" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  TID=$(date -u +tun-%Y%m%d%H%M%S)

  cat >> .book/TUNING-LOG.md <<YAML

- id: $TID
  timestamp: $NOW
  role: $ROLE
  mode: guidelines
  trigger:
    type: manual-edit
    via: /bookbench:guidelines
  files_changed:
    - path: $FILE_PATH
      change_type: edit
  reason: "Manual author edit via /bookbench:guidelines"
  status: applied
  source: manual
  applied_by: manual
  approved_by: author
  applied_at: $NOW
  backup: $BACKUP
YAML

  echo "Edit recorded in .book/TUNING-LOG.md as $TID."
else
  echo "No changes saved. Backup $BACKUP preserved (you can delete it)."
fi
```

### Step 8 — Next-step message

```
Recommended next:
  /bookbench:guidelines $ROLE             — list other files for this role.
  /bookbench:tune                         — see if the tuner has suggestions.
```

### Constitutional rules

- **MUST** validate the role against the fixed list of 9 roles.
- **MUST** create a backup before opening `$EDITOR`.
- **MUST** record manual edits in `TUNING-LOG.md` so the tuner can later analyse patterns.
- **NEVER** edit `agent-templates/` (those are the canonical bodies; guidelines are book-local overrides).
- **NEVER** run any subagent — pure local file operation.

</execution>
