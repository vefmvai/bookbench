---
description: Selectively updates the local copies of nine agent bodies and the anti-AI-cliche hook script in the current book to match the latest plugin version. Performs three-way merge with backup, asks the author per file, never touches guidelines, registries, chapters or context. By default does NOT touch workflow.md (UX-08); --migrate-workflow opts in. D-21 from stage 6.
argument-hint: "[--major] [--migrate-workflow] [--from-local-dev <path>]"
allowed-tools: [Read, Write, Edit, Bash, Glob, AskUserQuestion]
---

# /book:update

<purpose>
Bring this book's local subagent bodies and hooks in sync with the current plugin while preserving everything author-owned. Three-way merge with backup. WF-04 (etap 7.1): a deployed book never receives plugin updates automatically — this command is opt-in and per-file.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный контракт — `installation-and-lifecycle.md` этапа 06 -->

## Inputs

- `${CLAUDE_PLUGIN_ROOT}/agent-templates/*.md` and `templates/hooks/anti-ai-cliche-lint.sh` (the would-be new versions).
- `.book/.claude/agents/*.md` and `.book/.hooks/anti-ai-cliche-lint.sh` (current book-side copies).
- `.book/.backup/<timestamp>/` (created during this command).

## Outputs

- Updated agent bodies and hook script (where author accepts).
- A new entry in `.book/UPDATE-LOG.md`.
- A timestamped backup folder under `.book/.backup/`.

<execution>

Eight-step orchestrator with per-file confirmation gates. Most complex of the lifecycle group.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory."; exit 0; }

# Resolve plugin root
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
MAJOR=0
MIGRATE_WORKFLOW=0
LOCAL_DEV_PATH=""
for arg in $ARGUMENTS; do
  case "$arg" in
    --major)              MAJOR=1 ;;
    --migrate-workflow)   MIGRATE_WORKFLOW=1 ;;
    --from-local-dev=*)   LOCAL_DEV_PATH="${arg#--from-local-dev=}" ;;
  esac
done

[ -n "$LOCAL_DEV_PATH" ] && PLUGIN_ROOT="$LOCAL_DEV_PATH"
[ -n "$PLUGIN_ROOT" ] || { echo "Error: cannot resolve CLAUDE_PLUGIN_ROOT. Pass --from-local-dev <path>."; exit 0; }
[ -d "$PLUGIN_ROOT/agent-templates" ] || { echo "Error: $PLUGIN_ROOT/agent-templates not found."; exit 0; }
```

### Step 2 — Compare versions

```bash
# Current book version
BOOK_VER=$(awk -F: '/^bookbench_version:/ {gsub(/^[ "]+|[" ]+$/, "", $2); print $2; exit}' .book/config.yaml)

# Plugin version (H6)
PLUGIN_VER="unknown"
if [ -f "$PLUGIN_ROOT/manifest.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    PLUGIN_VER=$(jq -r '.version // "unknown"' "$PLUGIN_ROOT/manifest.json")
  else
    PLUGIN_VER=$(awk -F\" '/"version":/ {print $4; exit}' "$PLUGIN_ROOT/manifest.json")
  fi
fi

echo "Book version:   $BOOK_VER"
echo "Plugin version: $PLUGIN_VER"

if [ "$BOOK_VER" = "$PLUGIN_VER" ]; then
  echo "Already on the latest version. Nothing to update."
  exit 0
fi

# Major boundary detection
BOOK_MAJOR=$(echo "$BOOK_VER" | cut -d. -f1)
PLUGIN_MAJOR=$(echo "$PLUGIN_VER" | cut -d. -f1)
if [ "$BOOK_MAJOR" != "$PLUGIN_MAJOR" ] && [ "$MAJOR" -ne 1 ]; then
  echo "Major version boundary detected ($BOOK_MAJOR → $PLUGIN_MAJOR)."
  echo "Pass --major to confirm. Read CHANGELOG.md before proceeding."
  exit 0
fi
```

### Step 3 — Build the file list

```bash
FILES_TO_UPDATE=""

# 9 agent bodies
for role in coordinator strategist writer factchecker editor marketer doc-classifier doc-synthesizer tuner; do
  SRC="$PLUGIN_ROOT/agent-templates/book-$role.md"
  DST=".book/.claude/agents/book-$role.md"
  [ -f "$SRC" ] || continue
  [ -f "$DST" ] || { FILES_TO_UPDATE="$FILES_TO_UPDATE $SRC>$DST"; continue; }
  if ! diff -q "$SRC" "$DST" >/dev/null 2>&1; then
    FILES_TO_UPDATE="$FILES_TO_UPDATE $SRC>$DST"
  fi
done

# Hook script
SRC_HOOK="$PLUGIN_ROOT/templates/hooks/anti-ai-cliche-lint.sh"
DST_HOOK=".book/.hooks/anti-ai-cliche-lint.sh"
if [ -f "$SRC_HOOK" ] && [ -f "$DST_HOOK" ] && ! diff -q "$SRC_HOOK" "$DST_HOOK" >/dev/null 2>&1; then
  FILES_TO_UPDATE="$FILES_TO_UPDATE $SRC_HOOK>$DST_HOOK"
fi

# Optional: workflow.md (only with --migrate-workflow flag, UX-08)
if [ "$MIGRATE_WORKFLOW" -eq 1 ]; then
  echo "(--migrate-workflow set — workflow.md will also be diffed.)"
fi

N_DIFFS=$(echo "$FILES_TO_UPDATE" | wc -w | tr -d ' ')
if [ "$N_DIFFS" -eq 0 ]; then
  echo "All template files are already in sync. Nothing to update."
  exit 0
fi

echo "Files differing from plugin: $N_DIFFS"
```

### Step 4 — Backup folder

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_DIR=".book/.backup/update-$TS"
mkdir -p "$BACKUP_DIR"
echo "Backup folder: $BACKUP_DIR"
```

### Step 5 — Per-file 3-way merge gate

For each file pair `SRC>DST`:

1. Compute `diff -u` (or use `diff3` with the original-version-from-backup if present).
2. Print:
   ```
   ── <DST> ──
   <unified diff: max 30 lines>
   ```
3. Present an `AskUserQuestion`:
   - Title: «Update `<DST>`?»
   - Options:
     - `Use new template` — copy `SRC` over `DST` (after backing up `DST` to `BACKUP_DIR`).
     - `Keep local version` — skip; leave `DST` unchanged.
     - `Show full diff` — print the entire diff and re-ask.
     - `Skip remaining files` — break out of the loop.

For files where `DST` does not exist (new in this version), present a simpler:
- «New file `<DST>` exists in plugin but not in book. Add it?»

### Step 6 — Apply updates + record version

For each accepted file:

```bash
cp -p "$DST" "$BACKUP_DIR/$(echo "$DST" | sed 's|/|_|g')"
cp -p "$SRC" "$DST"
[ "${DST##*.}" = "sh" ] && chmod 0755 "$DST"
```

After all files processed, update `.book/config.yaml.bookbench_version` to `$PLUGIN_VER`:

```bash
awk -v v="$PLUGIN_VER" '
  /^bookbench_version:/ { print "bookbench_version: \"" v "\""; next }
  { print }
' .book/config.yaml > .book/config.yaml.tmp && mv .book/config.yaml.tmp .book/config.yaml
```

### Step 7 — Append to UPDATE-LOG.md

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[ -f .book/UPDATE-LOG.md ] || printf '# UPDATE-LOG.md\n\n' > .book/UPDATE-LOG.md

cat >> .book/UPDATE-LOG.md <<MD

## Update on $NOW

- From: $BOOK_VER → $PLUGIN_VER
- Major: $([ "$MAJOR" -eq 1 ] && echo yes || echo no)
- Migrated workflow: $([ "$MIGRATE_WORKFLOW" -eq 1 ] && echo yes || echo no)
- Backup folder: $BACKUP_DIR

### Files updated

(per-file decisions list)
MD

# Update STATE.md
printf '\n%s — `/book:update` — version %s → %s; backup %s\n' \
  "$NOW" "$BOOK_VER" "$PLUGIN_VER" "$BACKUP_DIR" >> .book/STATE.md
```

### Step 8 — Next-step message

```
Update done. Backup: $BACKUP_DIR
New version: $PLUGIN_VER

Recommended next:
  /book:doctor              — verify integrity after update.
  /book:status              — see overall progress.
  /book:workflow:check      — if workflow.md was migrated, re-validate.
```

### Constitutional rules

- **MUST** never touch `.book/agent-guidelines/`, `.book/agent-memory/`, `.book/context/`, `.book/chapters/`, `.book/config.yaml` content (except `bookbench_version` field), or any log file.
- **MUST** ask per-file, not batch. The author retains veto on every file.
- **MUST** create a backup before any overwrite. The backup includes the previous version of each replaced file.
- **MUST** require `--major` to cross a major version boundary.
- **MUST** require `--migrate-workflow` to touch `workflow.md` (UX-08, WF-04).
- **NEVER** silently overwrite files. Diff is shown in every gate.
- **NEVER** invoke any subagent — pure file-level operation.

</execution>
