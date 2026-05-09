---
description: Инициализирует новую книгу BookBench в текущей папке. Проводит интервью из пяти вопросов, разворачивает каркас папки .book/, копирует шаблоны, регистрирует девять локальных субагентов и записывает новую книгу в глобальный реестр. Поддерживает флаг --from-existing для сценария, когда у автора уже есть наброски.
argument-hint: "[--from-existing]"
allowed-tools: [Task, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
---

# /book:start

<purpose>
Initialise a brand-new book project: run installation interview, scaffold .book/, copy templates and subagent bodies, optionally trigger /book:import for existing drafts.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Inputs

- Empty or near-empty current working directory.
- User answers to the installation interview (genre, working title, target audience, scope, language).
- Optional flag `--from-existing` to chain straight into `/book:import` after the interview.

## Outputs

- A populated `.book/` folder per `templates/book/`.
- A `CLAUDE.md` at the project root.
- A new entry in `${CLAUDE_PLUGIN_DATA}/registry.yaml`.
- An invitation to run `/book:plan-book` next.

## Notes for stage 13

The body of the command runs the COLD-START interview directly through `AskUserQuestion`, then copies `templates/book/` and `templates/claude-config/` into `.book/`. See `book-folder-structure.md` and `agents-placement.md` from etap 06. The `--from-existing` flag is a stub at stage 13 (real `/book:import` lands in stage 14, see PS-13-01..06).

<execution>

This command is a markdown prompt executed by Claude Code. The eight-step orchestrator pattern (validate → resolve paths → read inputs → AskUserQuestion → Task with `<files_to_read>` → verify outputs → atomic state update → next step) applies. Stage 13 does NOT call any subagent through `Task` for `/book:start` — the interview is conducted by the main coordinator directly via `AskUserQuestion`, and file scaffolding is plain Bash + Write.

### Step 1 — Parse arguments

Parse `$ARGUMENTS`:

- If it contains `--from-existing`, set `FROM_EXISTING=1`.
- Otherwise `FROM_EXISTING=0`.

### Step 2 — Resolve plugin paths

Read `${CLAUDE_PLUGIN_ROOT}/lib/plugin-data-helpers.md` once. Then via the Bash tool resolve:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && {
  for c in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    [ -f "$c/manifest.json" ] && PLUGIN_ROOT="$c" && break
  done
}
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
[ -z "$PLUGIN_DATA" ] && {
  if [ -n "${LOCALAPPDATA:-}" ]; then PLUGIN_DATA="$LOCALAPPDATA/bookbench"
  else PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"; fi
}
mkdir -p "$PLUGIN_DATA"
PLUGIN_VERSION="$(jq -r '.version // "0.1.0"' "$PLUGIN_ROOT/manifest.json" 2>/dev/null || echo unknown)"
echo "PLUGIN_ROOT=$PLUGIN_ROOT"
echo "PLUGIN_DATA=$PLUGIN_DATA"
echo "PLUGIN_VERSION=$PLUGIN_VERSION"
```

If `PLUGIN_ROOT` cannot be resolved, abort the command with the message: «Cannot find the BookBench plugin root. Set `CLAUDE_PLUGIN_ROOT` env var or reinstall the plugin.»

### Step 3 — Pre-flight: directory state (PS-13-05)

Run via Bash:

```bash
CWD="$(pwd)"
COUNT=$(find . -mindepth 1 -maxdepth 2 -not -path './.git*' -not -path './.DS_Store' | wc -l | tr -d ' ')
HAS_BOOK=0
[ -d ".book" ] && HAS_BOOK=1
echo "CWD=$CWD COUNT=$COUNT HAS_BOOK=$HAS_BOOK"
```

Decision tree:

- If `HAS_BOOK=1` → STOP. Print: «This folder already has a `.book/` directory. Run `/book:resume` to continue.» Exit.
- If `COUNT > 0` and `HAS_BOOK=0` → present an `AskUserQuestion`:
  - Title: «Folder is not empty»
  - Question: «Found N existing files/folders. How to proceed?»
  - Options: `Continue (initialise alongside existing files)` / `Abort (I will clean it up first)` / `Show files`.
  - On `Abort` — exit. On `Show files` — list with `ls -la`, then re-ask.

### Step 4 — Five-question interview (Numbered Procedure)

Conduct the five questions strictly via `AskUserQuestion` (one tool call per question or one call with five questions). Use neutral partner tone (no mentor-mode):

1. **Working book title.** Free text. Default suggestion: «My Book».
2. **Genre.** Single-choice from: `popular-science` (default), `narrative-non-fiction`, `academic-monograph`, `dissertation`, `other`. If `other` — follow up with «Genre name (free text)?».
3. **Target audience.** Free text. Default suggestion: «general public».
4. **Working chapter scope (estimate).** Free text or number. Default: «10 chapters».
5. **Chapter completion format** (when does a chapter count as «done»). Single-choice: `editor pass + author approval (default)` / `editor only` / `factcheck only` / `custom (specify)`.

Save answers as variables `BOOK_TITLE`, `BOOK_GENRE`, `BOOK_AUDIENCE`, `BOOK_SCOPE`, `BOOK_COMPLETION`.

If the genre is not one of the four built-in genres, set `BOOK_GENRE_RESOLVED=other` and write a note in `STATE.md` History line: «genre <X>: defaults from `popular-science` used; run `/book:research-genre` (stage 14) to generate a tailored skill.»

### Step 4.5 — Voice profile suggestion (etap 08.1, non-blocking)

After the five-question interview, before scaffolding `.book/`, surface voice-profile options to the author. This step is **NOT blocking** — `/book:start` completes successfully regardless of the choice. The real voice gate (TOV-08) fires later, in the body of `book-writer`, before the first `draft.md`.

```bash
# Resolve voices library path via lib/voices-helpers.md H1.
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
VOICE_COUNT=0
if [ -d "$VOICES_DIR" ]; then
  VOICE_COUNT=$(find "$VOICES_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
fi
echo "voice library: dir=$VOICES_DIR count=$VOICE_COUNT"
```

If `VOICE_COUNT >= 1` — print informationally (no `AskUserQuestion`):

```text
You have $VOICE_COUNT saved voice(s) in your personal library.
You can import one now via  /book:voice import <name>
or decide later — the writer-gate will offer three paths before your first chapter.
```

If `VOICE_COUNT == 0` — print informationally:

```text
You can configure your voice now via  /book:voice build  (a dedicated 15-20 min session)
or later — the writer-gate (etap 08.1, TOV-08) will surface three paths before your first chapter.
```

This step is purely informational. Proceed to Step 5 in either case.

### Step 5 — Read inputs

Read these files into context (small, ≤ 30 KB total):

- `${CLAUDE_PLUGIN_ROOT}/defaults.yaml` (specifically `genres.<BOOK_GENRE_RESOLVED>` if it exists; fallback to `genres.popular-science`).
- `${CLAUDE_PLUGIN_ROOT}/templates/claude-md/CLAUDE.md` (template for the root `CLAUDE.md`).

### Step 6 — Scaffold `.book/` (single transaction)

Run via Bash. The order matters: copy templates first, then patch with answers, then make hooks executable.

```bash
set -euo pipefail
mkdir -p .book
cp -R "$PLUGIN_ROOT/templates/book/." .book/
mkdir -p .book/.claude
cp -R "$PLUGIN_ROOT/templates/claude-config/." .book/.claude/
mkdir -p .book/.hooks
cp "$PLUGIN_ROOT/templates/hooks/anti-ai-cliche-lint.sh" .book/.hooks/anti-ai-cliche-lint.sh
chmod 0755 .book/.hooks/anti-ai-cliche-lint.sh
mkdir -p .book/agent-guidelines
mkdir -p .book/.backup
mkdir -p .book/.claude/agent-memory
# Copy CLAUDE.md template to root, but do not overwrite an existing CLAUDE.md.
if [ ! -f CLAUDE.md ]; then
  cp "$PLUGIN_ROOT/templates/claude-md/CLAUDE.md" CLAUDE.md
fi
echo "scaffold ok"
```

### Step 7 — Patch `.book/config.yaml` with interview answers

Use the Edit tool (or Bash sed — but Edit is preferred for review-ability). Substitute placeholders:

- `book.title: "TBD"` → `book.title: "${BOOK_TITLE}"`
- `book.genre: popular-science` → `book.genre: ${BOOK_GENRE_RESOLVED}`
- `book.language: ru` → keep as-is unless interview override (default `ru`; if title is English ASCII consider asking — but for stage 13 keep default)
- `book.registry_id: "TBD"` → `book.registry_id: "${REGISTRY_ID}"` (registry_id computed in Step 9)

Update `compatibility.created_with_bookbench` and `last_synced_with` to `${PLUGIN_VERSION}`.

For `popular-science` (default) the rest of `config.yaml` already matches `defaults.yaml.genres.popular-science` and no further edits are needed. For other genres at stage 13 — leave the values copied from the popular-science template and add a `STATE.md` note that the values are popular-science defaults pending a future `/book:research-genre`.

### Step 8 — Initialise `.book/STATE.md` and `.book/PROJECT.md`

Patch `.book/STATE.md`:

- `current_section`: `book_level`
- `current_chapter`: `null`
- `last_action`: `book initialised`
- `bookbench_version`: `${PLUGIN_VERSION}`
- `created_at`: current ISO 8601 timestamp
- `last_touched_at`: same ISO 8601 timestamp
- Append a History line: `<ISO 8601> — /book:start — initialised "${BOOK_TITLE}" (genre=${BOOK_GENRE_RESOLVED}, audience="${BOOK_AUDIENCE}")`.

Use Edit for the field replacements (replace `TBD` placeholders) and Bash append for the History line.

Patch `.book/PROJECT.md` with the title, genre, audience, scope, completion-format. Keep the rest of the template structure intact.

### Step 9 — Update `${CLAUDE_PLUGIN_DATA}` (helper H3 + H4)

Slugify the title and compute registry id:

```bash
slugify() {
  printf '%s' "$1" \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}
SLUG="$(slugify "$BOOK_TITLE")"
[ -z "$SLUG" ] && SLUG="book"
TODAY="$(date -u +%Y-%m-%d)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REGISTRY_ID="${SLUG}-${TODAY}"

# H3: ensure_installation_yaml
if [ ! -f "$PLUGIN_DATA/installation.yaml" ]; then
  cat > "$PLUGIN_DATA/installation.yaml" <<YAML
source: local-dev
installed_at: $NOW
plugin_version: $PLUGIN_VERSION
YAML
fi

# H4: registry_record_upsert
REGISTRY="$PLUGIN_DATA/registry.yaml"
[ ! -f "$REGISTRY" ] && printf 'books:\n' > "$REGISTRY"
BOOK_ABS="$(pwd)"
if grep -F "  path: $BOOK_ABS" "$REGISTRY" >/dev/null 2>&1; then
  awk -v p="$BOOK_ABS" -v ts="$NOW" '
    BEGIN{flag=0}
    {
      if ($0 ~ ("  path: " p)) flag=1
      if (flag && $0 ~ /^    last_touched:/) { sub(/last_touched: .*/, "last_touched: " ts); flag=0 }
      print
    }
  ' "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
else
  cat >> "$REGISTRY" <<YAML
  - id: $REGISTRY_ID
    title: $BOOK_TITLE
    path: $BOOK_ABS
    genre: $BOOK_GENRE_RESOLVED
    language: ru
    created: $NOW
    last_touched: $NOW
    bookbench_version: $PLUGIN_VERSION
    status: active
YAML
fi
echo "registry updated: id=$REGISTRY_ID"
```

Patch `book.registry_id` in `.book/config.yaml` with `${REGISTRY_ID}` (Edit tool).

### Step 10 — Verify outputs

Run via Bash:

```bash
EXPECTED=(
  ".book/PROJECT.md"
  ".book/ROADMAP.md"
  ".book/STATE.md"
  ".book/config.yaml"
  ".book/.claude/settings.json"
  ".book/.hooks/anti-ai-cliche-lint.sh"
  "CLAUDE.md"
)
for f in "${EXPECTED[@]}"; do
  [ -e "$f" ] || { echo "MISSING: $f"; exit 1; }
done
test -x .book/.hooks/anti-ai-cliche-lint.sh || { echo "hook not executable"; exit 1; }
ls .book/.claude/agents/ | wc -l   # expect 9
echo "verify ok"
```

If any check fails, report the error to the author and abort (do not invoke the next step).

### Step 11 — `--from-existing` branch (PS-13-01 stub)

If `FROM_EXISTING=1`:

- Print: «`/book:import` is implemented in stage 14. Your folder has been initialised. To import existing materials, place them in `.book/inputs/` and re-run `/book:import` once stage 14 lands.»
- Do NOT call `/book:import` (the command is a stub at stage 13).

### Step 12 — Next-step message

Print the final block (5–8 lines):

```
Book initialised: "${BOOK_TITLE}" (genre=${BOOK_GENRE_RESOLVED}).
Registered as: ${REGISTRY_ID}
Files created in .book/ — 25+; CLAUDE.md at the project root.

Recommended next step:
  /book:plan-book          — generate the chapter plan (book-strategist book-mode).
  /book:status             — see the current state at any time.
```

### Constitutional rules for this command

- **MUST** never overwrite an existing `.book/` directory; always halt with «run /book:resume».
- **MUST** copy hook with `chmod 0755`.
- **MUST** make registry update idempotent on `path` (PS-13-05 + H4).
- **NEVER** call `/book:import` directly at stage 13 — show stub message instead.
- **NEVER** modify `${CLAUDE_PLUGIN_DATA}/installation.yaml.source` after first creation (only stage 14 manages the dev/published switch).

</execution>
