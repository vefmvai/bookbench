---
description: Updates the BookBench plugin itself from GitHub marketplace and rewrites the Claude Code plugin registry. Default mode (layer 1) does git pull + safe registry rewrite with backup. --check is read-only. --apply-templates (layer 2) syncs new release assets into the current book with per-file confirmation, respecting sacred-policy D-41. --from <ref> rolls back to a tag or commit. Closes the UX gap that VSCode extension cannot auto-update plugins from marketplace. D-42, stage 25.
argument-hint: "[--check] [--apply-templates] [--from <ref>]"
allowed-tools: [Read, Write, Edit, Bash, Glob, AskUserQuestion]
---

# /bookbench:upgrade

<purpose>
Self-update entry point for the BookBench plugin. Layer 1 (mandatory, default) — git pull the marketplace clone and rewrite `installed_plugins.json` with backup. Layer 2 (optional, `--apply-templates`) — sync new release assets into the current book with per-file confirmation. Sacred policy D-41 strictly enforced: nothing under `.book/agent-guidelines/<role>/` or `.book/context/<status:confirmed>` is overwritten silently.
</purpose>

<sacred-policy-reference>
This command MUST follow `lib/sacred-policy.md` (D-41) for any write into `.book/agent-guidelines/<role>/` or `.book/context/`. See § Layer 2 below.
</sacred-policy-reference>

## Inputs

- `~/.claude/plugins/marketplaces/bookbench/` — local clone of the marketplace (created by Claude Code at first install).
- `~/.claude/plugins/installed_plugins.json` — Claude Code plugin registry (per-user).
- (Layer 2 only) `${CLAUDE_PLUGIN_ROOT}/templates/`, `${CLAUDE_PLUGIN_ROOT}/lib/` — new release assets.
- (Layer 2 only) `.book/` — current book in cwd.

## Outputs

- Layer 1: updated marketplace clone, updated registry entry for `bookbench@bookbench`, backup `installed_plugins.json.backup-<unix-ts>`, instruction message about Reload Window.
- `--check`: text report «Текущая X | Свежая Y | Доступно обновление: ДА|НЕТ». No file changes.
- Layer 2: updated assets in `.book/`, `.book/.backup/upgrade-<ts>/`, entry in `.book/UPDATE-LOG.md`.

<execution>

Procedural orchestrator with four mutually exclusive modes selected by argument parsing. Most security-sensitive parts: registry rewrite (layer 1) and sacred-policy gate (layer 2).

### Constitutional rules (apply to every mode)

- **MUST** create `installed_plugins.json.backup-<unix-timestamp>` **before** any write to the registry (default and `--from`).
- **MUST** check for `jq` in Step 0 and exit 1 with a clear message if missing.
- **MUST** use `git pull --ff-only` (never `git pull` alone, never `git reset --hard`).
- **MUST** ask per file via `AskUserQuestion` for any write into `.book/agent-guidelines/<role>/` (D-41).
- **NEVER** touch other marketplaces under `~/.claude/plugins/marketplaces/<other>/`.
- **NEVER** delete or modify other entries in `installed_plugins.json` — only the `bookbench@bookbench` entry, only fields `installPath`, `version`, `lastUpdated`, `gitCommitSha`.
- **NEVER** overwrite `.book/context/<file>.md` with `status: confirmed` even with confirmation (sacred policy D-41).
- **NEVER** invoke Reload Window programmatically — print the instruction for the author.

### Step 0 — Argument parsing and pre-flight

```bash
MODE="default"
APPLY_TEMPLATES=0
FROM_REF=""
SHIFT_NEXT=0

# Parse arguments. $ARGUMENTS is provided by Claude Code as the raw arg string.
set -- $ARGUMENTS
while [ $# -gt 0 ]; do
  case "$1" in
    --check)
      MODE="check"
      ;;
    --apply-templates)
      APPLY_TEMPLATES=1
      MODE="apply-templates"
      ;;
    --from)
      shift
      FROM_REF="$1"
      MODE="from"
      [ -z "$FROM_REF" ] && { echo "Error: --from requires a <ref> argument (tag or commit sha)."; exit 1; }
      ;;
    --from=*)
      FROM_REF="${1#--from=}"
      MODE="from"
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: /bookbench:upgrade [--check] [--apply-templates] [--from <ref>]"
      exit 1
      ;;
  esac
  shift
done

# Pre-flight: check tools
command -v git >/dev/null 2>&1 || { echo "Error: git is required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed. Install: brew install jq (macOS) or apt-get install jq (Linux)."; exit 1; }

# Resolve marketplace clone path. Default location of Claude Code marketplaces.
MARKETPLACE_DIR="${HOME}/.claude/plugins/marketplaces/bookbench"
REGISTRY_FILE="${HOME}/.claude/plugins/installed_plugins.json"

[ -d "$MARKETPLACE_DIR/.git" ] || { echo "Error: marketplace clone not found at $MARKETPLACE_DIR. Did you install via /plugin marketplace add vefmvai/bookbench?"; exit 1; }
[ -f "$REGISTRY_FILE" ] || { echo "Error: Claude Code plugin registry not found at $REGISTRY_FILE."; exit 1; }

# Validate registry JSON
if ! jq -e '.plugins["bookbench@bookbench"]' "$REGISTRY_FILE" >/dev/null 2>&1; then
  echo "Error: registry has no entry for bookbench@bookbench. Did you install via /plugin install bookbench@bookbench?"
  exit 1
fi
```

### Step 1 — Branch into mode

#### Mode `--check` — read-only inspection

```bash
if [ "$MODE" = "check" ]; then
  cd "$MARKETPLACE_DIR" || exit 1

  # Fetch without pull
  git fetch origin --quiet || { echo "Error: git fetch failed (network?)."; exit 2; }

  LOCAL_SHA=$(git rev-parse --short HEAD)
  REMOTE_SHA=$(git rev-parse --short origin/main)
  LOCAL_VER=$(jq -r '.version // "unknown"' plugins/bookbench/manifest.json 2>/dev/null || echo "unknown")
  REMOTE_VER=$(git show origin/main:plugins/bookbench/manifest.json 2>/dev/null | jq -r '.version // "unknown"' 2>/dev/null || echo "unknown")

  if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
    UPDATE_AVAILABLE="НЕТ"
  else
    UPDATE_AVAILABLE="ДА"
  fi

  echo "Текущая: ${LOCAL_SHA} (v${LOCAL_VER}) | Свежая: ${REMOTE_SHA} (v${REMOTE_VER}) | Доступно обновление: ${UPDATE_AVAILABLE}"
  exit 0
fi
```

**Guarantee for `--check`:** no `cp`, no `mv`, no edit of registry, no `git pull`, no `git checkout`. The marketplace clone stays clean.

#### Mode default or `--from` — Layer 1 (git pull + registry rewrite)

```bash
if [ "$MODE" = "default" ] || [ "$MODE" = "from" ]; then
  cd "$MARKETPLACE_DIR" || exit 1

  # Read OLD version BEFORE any change
  OLD_VER=$(jq -r '.plugins["bookbench@bookbench"][0].version' "$REGISTRY_FILE")
  OLD_SHA=$(jq -r '.plugins["bookbench@bookbench"][0].gitCommitSha' "$REGISTRY_FILE")

  if [ "$MODE" = "from" ]; then
    # Validate ref
    git fetch --tags --quiet origin || { echo "Error: git fetch failed."; exit 2; }
    git rev-parse --verify "$FROM_REF" >/dev/null 2>&1 || { echo "Error: ref '$FROM_REF' not found. Available tags: $(git tag -l | tr '\n' ' ')"; exit 1; }

    git checkout --quiet "$FROM_REF" || { echo "Error: git checkout $FROM_REF failed."; exit 2; }
  else
    # Default: fetch + ff-only pull
    git fetch origin --quiet || { echo "Error: git fetch failed (network?)."; exit 2; }

    # Ensure we are on main (not detached after a previous --from)
    if ! git symbolic-ref -q HEAD >/dev/null; then
      echo "Note: marketplace clone is in detached HEAD (probably after --from). Switching to main."
      git checkout main --quiet || { echo "Error: cannot switch to main."; exit 2; }
    fi

    git pull --ff-only origin main --quiet || { echo "Error: git pull --ff-only failed. Marketplace clone may have local divergence. Run 'cd $MARKETPLACE_DIR && git status' to inspect."; exit 2; }
  fi

  # Read NEW version AFTER pull/checkout
  NEW_VER=$(jq -r '.version // "unknown"' plugins/bookbench/manifest.json)
  NEW_SHA=$(git rev-parse --short HEAD)
  NEW_SHA_FULL=$(git rev-parse HEAD)

  # Compute installPath. Claude Code 2.x stores plugin under marketplace/plugins/<name>.
  NEW_INSTALL_PATH="${MARKETPLACE_DIR}/plugins/bookbench"
  NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

  # Step 1.1 — MANDATORY backup of registry BEFORE any write
  TS=$(date +%s)
  BACKUP_FILE="${REGISTRY_FILE}.backup-${TS}"
  cp -p "$REGISTRY_FILE" "$BACKUP_FILE" || { echo "Error: cannot create backup at $BACKUP_FILE."; exit 1; }
  echo "Backup создан: $BACKUP_FILE"

  # Step 1.2 — Rewrite ONLY 4 fields of the bookbench@bookbench entry. Other entries untouched.
  TMP_FILE="${REGISTRY_FILE}.tmp.$$"
  jq --arg installPath "$NEW_INSTALL_PATH" \
     --arg version "$NEW_VER" \
     --arg lastUpdated "$NOW_ISO" \
     --arg gitCommitSha "$NEW_SHA" \
     '.plugins["bookbench@bookbench"][0].installPath = $installPath
      | .plugins["bookbench@bookbench"][0].version = $version
      | .plugins["bookbench@bookbench"][0].lastUpdated = $lastUpdated
      | .plugins["bookbench@bookbench"][0].gitCommitSha = $gitCommitSha' \
     "$REGISTRY_FILE" > "$TMP_FILE" || {
       echo "Error: jq rewrite failed. Restore from backup: cp $BACKUP_FILE $REGISTRY_FILE"
       rm -f "$TMP_FILE"
       exit 1
     }

  # Atomic move
  mv "$TMP_FILE" "$REGISTRY_FILE" || { echo "Error: cannot replace registry. Restore from backup: cp $BACKUP_FILE $REGISTRY_FILE"; exit 1; }

  # Step 1.3 — Print instruction
  if [ "$MODE" = "from" ]; then
    echo ""
    echo "Готово. ${OLD_VER} (${OLD_SHA}) → ${NEW_VER} (${NEW_SHA}, ref=${FROM_REF})."
  else
    echo ""
    if [ "$OLD_SHA" = "$NEW_SHA" ] || [ "$OLD_VER" = "$NEW_VER" ]; then
      echo "Уже на свежей версии: ${NEW_VER} (${NEW_SHA}). Реестр обновлён (на случай рассинхронизации)."
    else
      echo "Готово. ${OLD_VER} → ${NEW_VER} (sha ${OLD_SHA} → ${NEW_SHA})."
    fi
  fi
  echo ""
  echo "Чтобы Claude Code увидел свежую версию плагина, перезагрузи окно:"
  echo "  CLI: запусти /reload-plugins (если поддерживается твоей версией)."
  echo "  VSCode: Cmd+Shift+P → Developer: Reload Window."
  echo ""
  echo "После перезагрузки проверь: /bookbench:doctor (должен показать ${NEW_VER})."

  exit 0
fi
```

#### Mode `--apply-templates` — Layer 2 (sync assets into the current book)

This mode runs **after** the author has done Reload Window and `${CLAUDE_PLUGIN_ROOT}` points to the new plugin code.

```bash
if [ "$MODE" = "apply-templates" ]; then
  # Pre-flight: must be inside a book
  [ -d .book ] || { echo "Error: .book/ not found in current directory. cd into your book folder first."; exit 1; }

  # Resolve plugin root (set by Claude Code when running plugin commands)
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
  if [ -z "$PLUGIN_ROOT" ] || [ ! -d "$PLUGIN_ROOT" ]; then
    echo "Error: \${CLAUDE_PLUGIN_ROOT} is not set or does not exist. Make sure you reloaded Claude Code after layer 1 (/bookbench:upgrade) and run this command from the plugin context."
    exit 1
  fi

  PLUGIN_VER=$(jq -r '.version // "unknown"' "$PLUGIN_ROOT/manifest.json" 2>/dev/null || echo "unknown")

  # Read current book version (preferred field, fallback for legacy)
  BOOK_VER=$(awk -F: '/^[[:space:]]*bookbench_version:/ {gsub(/^[ "]+|[" ]+$/, "", $2); print $2; exit}' .book/config.yaml 2>/dev/null)
  [ -z "$BOOK_VER" ] && BOOK_VER="unknown"

  echo "Книга: ${BOOK_VER} | Плагин: ${PLUGIN_VER}"

  if [ "$BOOK_VER" = "$PLUGIN_VER" ]; then
    echo "Книга уже на свежей версии плагина. Нечего применять."
    exit 0
  fi

  # Step 2.1 — Mandatory backup folder
  TS=$(date -u +%Y%m%dT%H%M%SZ)
  BACKUP_DIR=".book/.backup/upgrade-${TS}"
  mkdir -p "$BACKUP_DIR" || { echo "Error: cannot create $BACKUP_DIR."; exit 1; }
  echo "Backup folder: $BACKUP_DIR"

  # Step 2.2 — Build asset list
  # We sync three classes of files:
  #   class A: templates/agent-guidelines/<role>/*.md → .book/agent-guidelines/<role>/<file>.md  (D-41 sacred)
  #   class B: templates/hooks/*.sh                   → .book/.hooks/<file>.sh
  #   class C: lib/*.md                               — informational diff only (lib lives in plugin root, not copied to book)
  # We DO NOT touch:
  #   .book/context/<file>.md with status: confirmed (D-41 sacred)
  #   .book/config.yaml (other than installed.bookbench_version field at the very end)
  #   .book/sections/, .book/agent-memory/, .book/inputs/, .book/intel/, .book/debug/, .book/final/

  echo ""
  echo "=== Class A: agent-guidelines (sacred policy D-41 — confirmation per file) ==="

  ANY_CHANGE=0

  # Iterate over plugin's templates/agent-guidelines/<role>/<file>.md
  for SRC_FILE in $(find "$PLUGIN_ROOT/templates/agent-guidelines" -type f -name '*.md' 2>/dev/null); do
    REL_PATH="${SRC_FILE#$PLUGIN_ROOT/templates/}"   # agent-guidelines/<role>/<file>.md
    DST_FILE=".book/${REL_PATH}"

    if [ ! -f "$DST_FILE" ]; then
      # New file — sacred policy: ASK author per file (use AskUserQuestion via prompt)
      echo ""
      echo "── NEW: ${REL_PATH} ──"
      head -20 "$SRC_FILE"
      echo "(showing first 20 lines)"
      echo ""
      echo "Sacred policy D-41: новый файл в agent-guidelines/ требует подтверждения."
      echo "Подтверди добавление через диалог Claude (AskUserQuestion 'Добавить новый файл <REL_PATH> в книгу?')."
      echo "Если 'да' — выполни: mkdir -p \"$(dirname "$DST_FILE")\" && cp -p \"$SRC_FILE\" \"$DST_FILE\""
      echo "(в финальной реализации Claude использует AskUserQuestion и сам выполнит cp; этот скрипт-secy показывает контракт)"
      ANY_CHANGE=1
      # NOTE for the agent running this command:
      # Use the AskUserQuestion tool here with options:
      #   "Добавить новый файл <REL_PATH>" / "Пропустить" / "Показать полный diff"
      # On accept: cp -p "$SRC_FILE" "$DST_FILE" (mkdir -p the parent dir first).
      # On skip: continue.

    elif ! diff -q "$SRC_FILE" "$DST_FILE" >/dev/null 2>&1; then
      # Existing file with diff — sacred policy: ASK author per file
      echo ""
      echo "── DIFF: ${REL_PATH} ──"
      diff -u "$DST_FILE" "$SRC_FILE" | head -30
      echo "(diff truncated to 30 lines)"
      echo ""
      echo "Sacred policy D-41: правка agent-guidelines/ требует подтверждения."
      echo "Через AskUserQuestion: 'Принять новую версию <REL_PATH>?' (Yes / Keep local / Show full diff)."
      echo "Перед перезаписью — backup: cp -p \"$DST_FILE\" \"$BACKUP_DIR/$(echo "$REL_PATH" | sed 's|/|_|g')\""
      ANY_CHANGE=1
    fi
  done

  echo ""
  echo "=== Class B: hooks ==="
  for SRC_FILE in $(find "$PLUGIN_ROOT/templates/hooks" -type f -name '*.sh' 2>/dev/null); do
    REL_PATH="${SRC_FILE#$PLUGIN_ROOT/templates/}"   # hooks/<file>.sh
    HOOK_NAME=$(basename "$SRC_FILE")
    DST_FILE=".book/.hooks/$HOOK_NAME"

    if [ ! -f "$DST_FILE" ]; then
      echo "NEW hook: $HOOK_NAME (will be installed without prompt — hooks are infrastructure)."
      mkdir -p .book/.hooks
      cp -p "$SRC_FILE" "$DST_FILE"
      chmod 0755 "$DST_FILE"
      ANY_CHANGE=1
    elif ! diff -q "$SRC_FILE" "$DST_FILE" >/dev/null 2>&1; then
      echo "── DIFF hook: $HOOK_NAME ──"
      diff -u "$DST_FILE" "$SRC_FILE" | head -30
      echo "Перед перезаписью — backup в $BACKUP_DIR/_hooks_${HOOK_NAME}"
      echo "Через AskUserQuestion подтверди принятие новой версии hook."
      ANY_CHANGE=1
    fi
  done

  echo ""
  echo "=== Class C: lib/* (информационно, не копируется в книгу) ==="
  for SRC_FILE in $(find "$PLUGIN_ROOT/lib" -type f -name '*.md' 2>/dev/null); do
    BASENAME=$(basename "$SRC_FILE")
    echo "  lib/${BASENAME}: используется плагином напрямую через \${CLAUDE_PLUGIN_ROOT}; в книгу не копируется."
  done

  # Step 2.3 — Update bookbench_version in .book/config.yaml
  if [ "$ANY_CHANGE" = "1" ] && [ -f .book/config.yaml ]; then
    awk -v v="$PLUGIN_VER" '
      /^[[:space:]]*bookbench_version:/ { gsub(/"[^"]*"/, "\"" v "\""); print; matched=1; next }
      { print }
      END { if (!matched) print "bookbench_version: \"" v "\"" }
    ' .book/config.yaml > .book/config.yaml.tmp && mv .book/config.yaml.tmp .book/config.yaml
    echo "Обновлено .book/config.yaml > bookbench_version: $PLUGIN_VER"
  fi

  # Step 2.4 — Append to UPDATE-LOG.md
  NOW_LOG=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  [ -f .book/UPDATE-LOG.md ] || printf '# UPDATE-LOG.md\n\n' > .book/UPDATE-LOG.md
  cat >> .book/UPDATE-LOG.md <<MD

## upgrade-apply-templates on $NOW_LOG

- From: $BOOK_VER → $PLUGIN_VER
- Backup: $BACKUP_DIR
- Mode: --apply-templates (layer 2 of /bookbench:upgrade)
- Sacred policy D-41: per-file confirmation for agent-guidelines/.
MD

  echo ""
  echo "Готово. Backup: $BACKUP_DIR"
  echo "После применения templates рекомендуется: /bookbench:doctor (проверка целостности)."
  exit 0
fi
```

### Notes for the agent executing this command

When running this command in interactive Claude Code, use the `AskUserQuestion` tool at every point marked `# NOTE for the agent`. The bash above prints a contract; the actual confirmation dialog must be driven by `AskUserQuestion` so the author can answer in a single click. Files are then copied/skipped based on the answer.

For **Layer 1** (default and `--from`), no `AskUserQuestion` is used — the operation is fully automatic, the author only sees the final instruction and must do Reload Window manually.

</execution>

## Examples

```
# Most common case: standard upgrade
/bookbench:upgrade

# Read-only: am I on the latest?
/bookbench:upgrade --check

# Roll back to v0.3.2 (e.g. if 0.3.3 introduced a regression for me)
/bookbench:upgrade --from v0.3.2

# After Reload Window: also pull in new agent-guidelines templates and hooks for THIS book
/bookbench:upgrade --apply-templates
```

## Safety rationale (D-42)

- **Backup of registry before any write** — recovery is one `cp` away.
- **Per-file confirmation in agent-guidelines/** — sacred policy D-41 (these files affect every sentence the writer produces).
- **No `git reset --hard`** — fail-fast on divergence, never silently destroy local work in the marketplace clone.
- **No touching of other marketplaces or other plugins** — single-purpose entry-point, scoped to bookbench@bookbench only.
- **Reload Window is author's responsibility** — VSCode extension provides no programmatic API; printing the instruction is the safe contract.

---

*Created: 2026-05-10 (stage 25, T2-T6).*
