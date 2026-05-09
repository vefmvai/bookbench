---
description: Initialises a new BookBench book in the current folder. Runs an open coach-mode dialogue (no radio buttons), assembles four orthogonal dimensions (format, genre, audience, style-marker) per matching-design.md, scaffolds the .book/ skeleton, copies templates, registers the nine local subagents, and records the new book in the global registry. If the author attaches drafts, /book:import is invoked automatically.
argument-hint: ""
allowed-tools: [Task, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
---

# /book:start

<purpose>
Initialise a new book project in coach-mode (D-30 four dimensions; D-33 inline coach).
Run open coach dialogue, assemble format/genre/audience/style-marker per
matching-design.md, scaffold .book/, copy templates and subagent bodies,
auto-invoke /book:import if author attached drafts.
</purpose>

<!-- Этап 22 (Milestone 2 0.3.0): Step 4 переписан под коуч-режим (D-33 inline; коуч-промпт вынесен в lib/start-coach-prompt.md по R-22-B=(б)). Step 11 — автоматический /book:import. Закрывает issues I-01, I-02, I-04, I-06. -->

## Inputs

- Empty or near-empty current working directory.
- Author's free-text description (and optionally voice transcript / attached files) collected through the coach dialogue.
- Optional attached drafts/notes/screenshots — handled automatically via `/book:import` (no flag needed).

## Outputs

- A populated `.book/` folder per `templates/book/`.
- A `CLAUDE.md` at the project root.
- A new entry in `${CLAUDE_PLUGIN_DATA}/registry.yaml` with `format` and `genre`.
- A next-step message inviting `/book:plan-book`.

<execution>

This command is a markdown prompt executed by Claude Code. The orchestrator pattern (validate → resolve paths → coach-dialogue → scaffold → atomic state update) applies. The coach dialogue (Step 4) is conducted by the main coordinator inline (D-33) using the procedure file `lib/start-coach-prompt.md`. No subagent is invoked for the coach itself; subagents are invoked only for the optional `/book:import` branch.

### Step 1 — Resolve plugin paths

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

If `PLUGIN_ROOT` cannot be resolved, abort with: «Не могу найти корень плагина BookBench. Установи переменную `CLAUDE_PLUGIN_ROOT` или переустанови плагин.»

### Step 2 — Pre-flight: directory state

```bash
CWD="$(pwd)"
COUNT=$(find . -mindepth 1 -maxdepth 2 -not -path './.git*' -not -path './.DS_Store' | wc -l | tr -d ' ')
HAS_BOOK=0
[ -d ".book" ] && HAS_BOOK=1
echo "CWD=$CWD COUNT=$COUNT HAS_BOOK=$HAS_BOOK"
```

Decision tree:

- If `HAS_BOOK=1` → STOP. Print: «В этой папке уже есть `.book/`. Запусти `/book:resume`, чтобы продолжить.» Exit.
- If `COUNT > 0` and `HAS_BOOK=0` → present an `AskUserQuestion`:
  - Title: «В папке уже есть файлы»
  - Question: «Найдено N файлов/папок. Что делаем?»
  - Options: `Продолжить (инициализировать рядом)` / `Прервать (уберу сначала)` / `Показать файлы`.
  - On `Прервать` — exit. On `Показать файлы` — list with `ls -la`, then re-ask.

### Step 3 — Read coach prompt

Read `${PLUGIN_ROOT}/lib/start-coach-prompt.md` into context. This file contains the full coach procedure (10 sections § 0–§ 10) per `matching-design.md` §§ 3.1–3.7. The main coordinator becomes the coach inline (no `Task` to a subagent — D-33).

### Step 4 — Coach-mode dialogue (D-33 inline)

Apply the procedure from `lib/start-coach-prompt.md`:

1. **§ 1. Открытое приглашение** — say the opening line; wait silently for author's reply (text / voice / attached files).
2. **§ 6. Trigger → Action** — if author attached files → invoke `/book:import` automatically (Step 4a below) BEFORE forming hypotheses. If no files → print the explicit reassurance per R-22-D=(б): «Окей, работаем с нуля; если позже найдёшь черновики — есть `/book:import`».
3. **§ 2. Сборка format** — analyse the inputs by signals (matching-design.md § 3.2); ranked B1 (one hypothesis with reasoning) / B2 (`/book:research-format` if no preset matches).
4. **§ 3. Сборка genre** — analyse (matching-design.md § 3.3); B1 (one hypothesis filtered by `compatible_genres`) / B2 (`/book:research-genre`).
5. **§ 4. Сборка audience** — gather portrait (matching-design.md § 3.4); B1 (ready portrait) / B2 (open question + structured back-formulation) / B3 (archetypes as examples, not enum) / fallback (level of complexity).
6. **§ 5. Style-marker** — TOV-08 preserved verbatim. ONLY collect path-marker B1/B2/B3; no questions about the 6 voice-profile parameters. Save `voice-profile.md` (B1) or `voice-samples.md` (B2) if author attached corresponding files; otherwise B3 (no save now; first section will trigger collection).
7. **§ 7. Развилка «не уверен»** — one clarifying question if confidence below threshold; B2 research or fallback if still uncertain.
8. **§ 8. Recovery from Rule Break** — if author switches topic / rejects current hypothesis — adapt without blocking start.

After the four assemblies and the optional auto-import, proceed to Step 5 with these variables filled:

- `BOOK_TITLE` — author-provided title (free text).
- `BOOK_FORMAT` — slug from § 2 (one of `article | long-read | book | monograph | dissertation` or a user preset).
- `BOOK_GENRE` — slug from § 3.
- `BOOK_AUDIENCE` — free-text portrait from § 4 (short variant; long variant goes to `.book/context/audience.md`).
- `BOOK_AUDIENCE_LONG` — optional long portrait text (or empty).
- `STYLE_MARKER` — `B1`, `B2`, or `B3` from § 5.
- `IMPORT_TRIGGERED` — `1` if author attached files and `/book:import` was invoked, `0` otherwise.

### Step 4a — Auto-import branch (Trigger → Action § 6 of coach prompt)

If author attached files in Step 4:

```text
Task(
  subagent_type="book-classifier",
  description="Auto-import attached drafts during /book:start.",
  prompt="""
  Run the import-classification skill on the files attached by the author
  to the current /book:start session. Classify each file into:
    - section-draft (chapter/section/scene draft)
    - notes (research notes, ideas, references)
    - voice-samples (passages in the author's style)
    - audience-portrait (description of target reader)

  Return a structured summary {file, classification, summary}.
  Do not write to .book/ yet — .book/ has not been scaffolded.
  Save extracted texts to a temp staging directory under
  ${CLAUDE_PLUGIN_DATA}/staging/<session-id>/.

  After Step 6 of /book:start (scaffold), the coordinator will
  move staging files into the appropriate .book/ slots.
  """
)
```

If the classifier reports `voice-samples` — coach assigns `STYLE_MARKER=B2` (per `matching-design.md` § 3.6).
If the classifier reports `section-draft` files — coach uses them as additional signal for `format` hypothesis (e.g. multiple `глава-XX.md` → strong `book` hypothesis).

### Step 5 — Read inputs

Read these files into context:

- `${CLAUDE_PLUGIN_ROOT}/defaults.yaml` — specifically `genres.${BOOK_GENRE}` and `formats.${BOOK_FORMAT}`. Fallback to `genres.popular-science` and `formats.book` if the slug does not exist.
- `${CLAUDE_PLUGIN_ROOT}/templates/claude-md/CLAUDE.md` — root `CLAUDE.md` template.

### Step 6 — Scaffold `.book/` (single transaction)

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
if [ ! -f CLAUDE.md ]; then
  cp "$PLUGIN_ROOT/templates/claude-md/CLAUDE.md" CLAUDE.md
fi
echo "scaffold ok"
```

### Step 6a — Move staged import artefacts (if Step 4a ran)

If `IMPORT_TRIGGERED=1`, move the artefacts from `${CLAUDE_PLUGIN_DATA}/staging/<session-id>/`:

- `section-draft` files → `.book/inputs/` (will be processed by `/book:import` in full mode later if author runs it).
- `voice-samples` → `.book/agent-guidelines/writer/voice-samples.md` (concatenate if multiple).
- `audience-portrait` → `.book/context/audience.md` (and update `BOOK_AUDIENCE_LONG`).
- `notes` → `.book/inputs/notes/`.

After moving, clean up the staging directory.

### Step 7 — Patch `.book/config.yaml` with coach-assembly results

Use the Edit tool. Substitute placeholders:

- `book.title: "TBD"` → `book.title: "${BOOK_TITLE}"`
- `book.genre: popular-science` → `book.genre: ${BOOK_GENRE}`
- `book.format: book` → `book.format: ${BOOK_FORMAT}` (per D-30, etap 20).
- `book.audience: ""` → `book.audience: "${BOOK_AUDIENCE}"` (free-text portrait per D-30; long variant goes to `.book/context/audience.md`).
- `book.registry_id: "TBD"` → `book.registry_id: "${REGISTRY_ID}"` (computed in Step 9).
- `book.language: ru` → keep default (or override if title is clearly ASCII English).

Update `compatibility.created_with_bookbench` and `last_synced_with` to `${PLUGIN_VERSION}`.

For `popular-science` (default genre) the rest of `config.yaml` already matches `defaults.yaml.genres.popular-science`. For other genres — copy the corresponding section from `defaults.yaml > genres.${BOOK_GENRE}` into `.book/config.yaml > writing/agents/quality_gates`.

### Step 8 — Initialise `.book/STATE.md` and `.book/PROJECT.md`

Patch `.book/STATE.md`:

- `current_section`: `book_level`
- `last_action`: `book initialised`
- `bookbench_version`: `${PLUGIN_VERSION}`
- `created_at`: current ISO 8601 timestamp
- `last_touched_at`: same ISO 8601 timestamp
- Append History line:
  ```
  <ISO 8601> — /book:start — initialised "${BOOK_TITLE}" (format=${BOOK_FORMAT}, genre=${BOOK_GENRE}, audience="${BOOK_AUDIENCE}", style_marker=${STYLE_MARKER}, import=${IMPORT_TRIGGERED})
  ```

Patch `.book/PROJECT.md` with title, genre, format, audience, style-marker, import-flag. Keep the rest of the template structure intact.

### Step 9 — Update `${CLAUDE_PLUGIN_DATA}` (helpers H3 + H4)

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

# H4: registry_record_upsert (now records `format` per D-30)
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
    genre: $BOOK_GENRE
    format: $BOOK_FORMAT
    language: ru
    created: $NOW
    last_touched: $NOW
    bookbench_version: $PLUGIN_VERSION
    status: active
YAML
fi
echo "registry updated: id=$REGISTRY_ID format=$BOOK_FORMAT genre=$BOOK_GENRE"
```

Patch `book.registry_id` in `.book/config.yaml` with `${REGISTRY_ID}` (Edit tool).

### Step 10 — Verify outputs

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

If any check fails, report and abort.

### Step 11 — Next-step message

Print the final block. Adaptive substitution: read `formats.${BOOK_FORMAT}.section_word` from `${PLUGIN_ROOT}/defaults.yaml` and use it in the user-facing block (per D-31, etap 21). For example, if `BOOK_FORMAT=article` → "раздел"; if `BOOK_FORMAT=book` → "глава".

Template:

```text
Книга инициализирована: «${BOOK_TITLE}»
  Формат:    ${BOOK_FORMAT} (${SECTION_WORD})
  Жанр:      ${BOOK_GENRE}
  Аудитория: ${BOOK_AUDIENCE}
  ID в реестре: ${REGISTRY_ID}

В .book/ создано 25+ файлов; CLAUDE.md в корне проекта.

${IMPORT_BLOCK}  # если IMPORT_TRIGGERED=1: «Прикреплённые файлы импортированы и разложены по слотам.»

Рекомендуемый следующий шаг:
  /book:plan-book   — собрать план ${SECTION_WORD}-ов (через book-strategist).
  /book:status      — посмотреть текущее состояние книги в любой момент.
```

### Constitutional rules for this command

**MUST:**
- **Всегда выслушать автора до формирования гипотезы.** Step 4 проводится строго по `lib/start-coach-prompt.md`: § 1 (открытое приглашение) → ждём ответ → анализируем → § 2-§ 5 (4 коуч-сборки).
- **Формулировать ровно одну гипотезу с обоснованием, не меню.** Никаких radio-кнопок до коуч-диалога. Все 4 измерения собираются как «одна гипотеза агента» (или сводная, если автор всё описал чётко в § 3.1).
- **Адаптивная обёртка глава/раздел/часть.** В репликах автору используем `formats.<format>.section_word` (D-31, этап 21).
- **Если автор приложил файлы — автоматически вызвать `/book:import`** (Step 4a) ДО формирования гипотез. Без флага `--from-existing` (флаг отменён в этапе 22).
- **Если автор НЕ приложил файлы — явно зафиксировать «работаем с нуля»** (R-22-D=(б)).
- **Сохранить TOV-08 дословно.** Step 4 § 5 собирает только метку пути B1/B2/B3; вопросы про 6 параметров `voice-profile` НЕ задаются. Gate стиля остаётся в `book-writer` перед первой `draft.md`.
- **`chmod 0755`** для hook-скрипта (Step 6).
- **Идемпотентный upsert** реестра по `path` (Step 9; H4 helper).

**NEVER:**
- **Не показывать radio-кнопки до коуч-диалога.** Все 5 старых вопросов AskUserQuestion удалены.
- **Не задавать вопрос «когда секция считается готовой»** на старте. Дефолт `workflow.completion_format: editor_pass_plus_author_approval` уже в `templates/book/config.yaml` (T8). Закрывает I-06.
- **Не собирать 6 параметров `voice-profile`** (formality, paragraph length, sentence variety, emotional intensity, dash typography, anglicism tolerance) на старте. Это работа `voice-builder` перед первой секцией (TOV-08).
- **Не блокировать старт книги отсутствием audience-портрета.** Фолбэк через уровень сложности в `lib/start-coach-prompt.md` § 4.
- **Не показывать жанры/форматы/аудиторию как закрытый enum.** Audience B3 — архетипы как примеры, не radio.
- **Не использовать узкоконтекстные категории аудитории** (типа «студенты и преподаватели» из конкретного образовательного кейса).
- **Не перезаписывать существующий `.book/`.** Останавливаемся с подсказкой `/book:resume` (Step 2).
- **Не вызывать `/book:import` если автор не приложил файлы.** Тогда — короткая фиксация «работаем с нуля» (R-22-D).
- **Не модифицировать `${CLAUDE_PLUGIN_DATA}/installation.yaml.source` после первого создания.**

**MAY:**
- **Сжать 4 коуч-сборки в одну сводную гипотезу**, если автор в первом сообщении уже всё описал чётко (по `matching-design.md` § 3.1). Например: «пишу диссертацию по политологии для научных руководителей в академическом стиле» → одна гипотеза «формат — диссертация, жанр — академическая монография, аудитория — научные руководители (специалисты узкой области). Согласен?» вместо трёх отдельных раундов.
- **Использовать тёплый партнёрский тон** («дружище», «расскажи как есть») как тональный ориентир, но не как обязательный приём. Главное — нейтрально-партнёрский регистр, не mentor-mode.

</execution>
