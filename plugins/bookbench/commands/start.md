---
description: Initialises a new BookBench book in the current folder. Runs an open coach-mode dialogue (no radio buttons), assembles four orthogonal dimensions (format, genre, audience, style-marker) plus addressing mode per matching-design.md, presents a Step 4b confirmation gate to the author, scaffolds the .book/ skeleton only after explicit approval, copies templates, registers the nine local subagents, and records the new book in the global registry. If the author attaches drafts, /bookbench:import is invoked automatically. Author-attached drafts never auto-populate voice-profile.md or agent-guidelines/ (see lib/sacred-policy.md and lib/voice-profile-lifecycle.md).
argument-hint: ""
allowed-tools: [Task, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
---

# /bookbench:start

<purpose>
Initialise a new book project in coach-mode (D-30 four dimensions; D-33 inline coach;
D-35 voice-profile lifecycle; D-36 genre pending sentinel; D-37 addressing_mode;
D-38 document_word; D-39 .book.proposed.yaml + Step 4b gate;
D-41 sacred policy for auto-created files).
Run open coach dialogue, assemble format/genre/audience/style-marker plus addressing
per matching-design.md, write a draft to .book.proposed.yaml, present a confirmation
gate, scaffold .book/ ONLY after explicit per-dimension approval, copy templates and
subagent bodies, auto-invoke /bookbench:import if author attached drafts.
</purpose>

<!-- Этап 22 (Milestone 2 0.3.0): Step 4 переписан под коуч-режим (D-33 inline; коуч-промпт вынесен в lib/start-coach-prompt.md по R-22-B=(б)). Step 11 — автоматический /bookbench:import. Закрывает issues I-01, I-02, I-04, I-06. -->
<!-- Этап 24 (Milestone 2 0.3.2): добавлен Step 4b шлюз подтверждения; промежуточный конфиг .book.proposed.yaml; ветка B3 genre pending; § 4a addressing_mode; voice-profile lifecycle (запрет автозаписи voice-profile.md без .draft); адаптивный финал через document_word; sacred-policy ссылка в шапке. Закрывает 6 классов ошибок live-теста «Спираль» 2026-05-10. -->

## Контракт безопасности перед изменениями

Перед каждой записью в `.book/agent-guidelines/<role>/` и `.book/context/<file>` со `status: confirmed` — обязательная сверка с `${PLUGIN_ROOT}/lib/sacred-policy.md`:
- Правило 1: запись в `agent-guidelines/` только с явным подтверждением автора (Step 4b).
- Правило 2: запись в `context/` со `status: confirmed` запрещена на `/bookbench:start`. Только `status: draft` или указатель.
- Правило 3: каждый авто-создаваемый артефакт несёт frontmatter `created_by: book-coordinator-coach` + `requires_confirmation: true|false` + `status:`.

Для voice-profile дополнительно действует `${PLUGIN_ROOT}/lib/voice-profile-lifecycle.md` (4 состояния none/draft/confirmed/calibrating; коуч пишет только `.draft` или указатель).

## Inputs

- Empty or near-empty current working directory.
- Author's free-text description (and optionally voice transcript / attached files) collected through the coach dialogue.
- Optional attached drafts/notes/screenshots — handled automatically via `/bookbench:import` (no flag needed).

## Outputs

- A populated `.book/` folder per `templates/book/` (only after Step 4b confirmation).
- A `CLAUDE.md` at the project root.
- A new entry in `${CLAUDE_PLUGIN_DATA}/registry.yaml` with `format` and `genre`.
- A next-step message inviting `/bookbench:plan-book` (with adaptive `${DOCUMENT_WORD}` substitution).
- Если genre оказался `pending` — `.book/context/genre-pending.md` stub и сообщение про необходимость `/bookbench:research-genre <slug>`.

<execution>

This command is a markdown prompt executed by Claude Code. The orchestrator pattern (validate → resolve paths → coach-dialogue → proposed-config → confirmation gate → scaffold → atomic state update) applies. The coach dialogue (Step 4) is conducted by the main coordinator inline (D-33) using the procedure file `lib/start-coach-prompt.md`. No subagent is invoked for the coach itself; subagents are invoked only for the optional `/bookbench:import` branch.

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
COUNT=$(find . -mindepth 1 -maxdepth 2 -not -path './.git*' -not -path './.DS_Store' -not -path './.book.proposed.yaml' | wc -l | tr -d ' ')
HAS_BOOK=0
HAS_PROPOSED=0
[ -d ".book" ] && HAS_BOOK=1
[ -f ".book.proposed.yaml" ] && HAS_PROPOSED=1
echo "CWD=$CWD COUNT=$COUNT HAS_BOOK=$HAS_BOOK HAS_PROPOSED=$HAS_PROPOSED"
```

Decision tree:

- If `HAS_BOOK=1` → STOP. Print: «В этой папке уже есть `.book/`. Запусти `/bookbench:resume`, чтобы продолжить.» Exit.
- If `HAS_PROPOSED=1` and `HAS_BOOK=0` → present an `AskUserQuestion`:
  - Title: «Найден черновик конфигурации»
  - Question: «В папке есть `.book.proposed.yaml` (черновик с прошлого незаконченного `/bookbench:start`). Что делаем?»
  - Options: `Удалить и начать сначала` / `Показать содержимое и решить` / `Прервать`.
  - On `Удалить и начать сначала` — `rm .book.proposed.yaml`, продолжить.
  - On `Показать содержимое` — Read и показать, затем re-ask.
  - On `Прервать` — exit.
- If `COUNT > 0` and `HAS_BOOK=0` → present an `AskUserQuestion`:
  - Title: «В папке уже есть файлы»
  - Question: «Найдено N файлов/папок. Что делаем?»
  - Options: `Продолжить (инициализировать рядом)` / `Прервать (уберу сначала)` / `Показать файлы`.
  - On `Прервать` — exit. On `Показать файлы` — list with `ls -la`, then re-ask.

### Step 3 — Read coach prompt

Read `${PLUGIN_ROOT}/lib/start-coach-prompt.md` into context. This file contains the full coach procedure (10 sections § 0–§ 10, including § 4a addressing_mode added in stage 24) per `matching-design.md` §§ 3.1–3.7. The main coordinator becomes the coach inline (no `Task` to a subagent — D-33).

Также прочитать `${PLUGIN_ROOT}/lib/voice-profile-lifecycle.md`, `${PLUGIN_ROOT}/lib/sacred-policy.md`, `${PLUGIN_ROOT}/lib/terminology-ru.md` — короткие политики, на которые ссылается коуч-промпт.

### Step 4 — Coach-mode dialogue (D-33 inline)

Apply the procedure from `lib/start-coach-prompt.md`:

1. **§ 1. Открытое приглашение** — say the opening line (с предупреждением «дальше будет короткая дискуссия, каждое решение — после твоего «да»»); wait silently for author's reply (text / voice / attached files).
2. **§ 6. Trigger → Action** — if author attached files → invoke `/bookbench:import` automatically (Step 4a below) BEFORE forming hypotheses. If no files → print the explicit reassurance per R-22-D=(б): «Окей, работаем с нуля; если позже найдёшь черновики — есть `/bookbench:import`».
3. **§ 2. Сборка format** — analyse the inputs by signals (matching-design.md § 3.2); ranked B1 (one hypothesis with reasoning) / B2 (`/bookbench:research-format` if no preset matches). Получить явное «да» от автора.
4. **§ 3. Сборка genre** — analyse (matching-design.md § 3.3); B1 (one hypothesis filtered by `compatible_genres`) / B2-research (`/bookbench:research-genre`) / **B3-pending** (sentinel `pending`, см. §3 ветка B3 — этап 24) / closest. Получить явное «да» от автора.
5. **§ 4. Сборка audience** — gather portrait (matching-design.md § 3.4); B1 (ready portrait) / B2 (open question + structured back-formulation) / B3 (archetypes as examples, not enum) / fallback (level of complexity). Получить явное «да» от автора.
6. **§ 4a. Addressing mode** — НОВОЕ в этапе 24 (D-37). Резолвить `derived_default` из `defaults.yaml` (приоритет: `genres.<genre>.addressing_default` > `formats.<format>.addressing_default` > `«вы»`). Задать прямой вопрос, получить явный ответ. **NEVER**: не выводить из черновиков, не выводить из voice-profile, не пропускать.
7. **§ 5. Style-marker** — TOV-08 preserved verbatim. ONLY collect path-marker per the four sub-branches (B1-confirmed / B1-derived / B2-pending / B2-confirmed / B3 / B3-pending — см. § 5 коуч-промпта). NEVER auto-extract voice-profile from drafts/briefs (D-35 voice-profile lifecycle). Save `.book/context/voice-profile.md.draft` (B1-confirmed) or `.book/context/voice-source-pointer.md` (B1-derived) или `.book/inputs/staged-voice-samples/<slug>.md` (B2-pending) ON STEP 6 — не сейчас.
8. **§ 7. Развилка «не уверен»** — one clarifying question if confidence below threshold; B2 research or fallback if still uncertain.
9. **§ 8. Recovery from Rule Break** — if author switches topic / rejects current hypothesis — adapt without blocking start.

After the four assemblies + § 4a + the optional auto-import, proceed to Step 5 with these variables filled:

- `BOOK_TITLE` — author-provided title (free text).
- `BOOK_FORMAT` — slug from § 2 (one of `article | long-read | book | monograph | dissertation` or a user preset).
- `BOOK_FORMAT_REASON` — short rationale (one sentence).
- `BOOK_GENRE` — slug from § 3 OR sentinel `pending` (with `BOOK_GENRE_PENDING_REASON`).
- `BOOK_AUDIENCE` — free-text portrait from § 4 (short variant; long variant goes to `BOOK_AUDIENCE_LONG`).
- `BOOK_AUDIENCE_LONG` — optional long portrait text (or empty).
- `BOOK_ADDRESSING_MODE` — one of `ты | вы | безличное | смешанное` from § 4a.
- `STYLE_MARKER` — `B1-confirmed | B1-derived | B2-pending | B2-confirmed | B3 | B3-pending` from § 5.
- `VOICE_SOURCE_PATH` — path to attached voice file (if any).
- `IMPORT_TRIGGERED` — `1` if author attached files and `/bookbench:import` was invoked, `0` otherwise.

### Step 4a — Auto-import branch (Trigger → Action § 6 of coach prompt)

If author attached files in Step 4:

```text
Task(
  subagent_type="book-classifier",
  description="Auto-import attached drafts during /bookbench:start.",
  prompt="""
  Run the import-classification skill on the files attached by the author
  to the current /bookbench:start session. Classify each file into:
    - section-draft (chapter/section/scene draft)
    - notes (research notes, ideas, references)
    - voice-samples (passages in the author's style)
    - audience-portrait (description of target reader)

  Return a structured summary {file, classification, summary}.
  Do not write to .book/ yet — .book/ has not been scaffolded.
  Save extracted texts to a temp staging directory under
  ${CLAUDE_PLUGIN_DATA}/staging/<session-id>/.

  After Step 6 of /bookbench:start (scaffold), the coordinator will
  move staging files into the appropriate slots:
    - section-draft → .book/inputs/source-drafts/
    - notes → .book/inputs/notes/
    - voice-samples → .book/inputs/staged-voice-samples/  (NOT agent-guidelines/)
    - audience-portrait → .book/context/audience.md  (only with author confirmation)
  """
)
```

Если classifier reports `voice-samples` — coach UI диалог с автором (черновик / готовое / просто пример) до записи в `agent-guidelines/`. См. § 5 ветку B2-pending коуч-промпта.
Если classifier reports `section-draft` files — coach uses them as additional signal for `format` hypothesis (e.g. multiple `глава-XX.md` → strong `book` hypothesis).

### Step 4b — Шлюз подтверждения перед развёртыванием (D-39)

**Trigger:** Step 4 завершён, все переменные собраны (но `.book/` ещё НЕ создан).

**Numbered Procedure:**

1. **Запись `.book.proposed.yaml`** (вне `.book/`!). Через Write:

   ```yaml
   # .book.proposed.yaml — черновик конфигурации, ещё не применён.
   # Удаляется автоматически после успешного развёртывания .book/, либо при отмене.
   # Не редактировать вручную — этот файл переживает один прогон /bookbench:start.
   proposed_at: <ISO 8601 timestamp>
   book:
     title: "${BOOK_TITLE}"
     format: ${BOOK_FORMAT}
     format_reason: "${BOOK_FORMAT_REASON}"
     genre: ${BOOK_GENRE}                        # slug или sentinel "pending"
     genre_pending_reason: "${BOOK_GENRE_PENDING_REASON}"   # если genre = pending
     audience: "${BOOK_AUDIENCE}"
     audience_long: "${BOOK_AUDIENCE_LONG}"      # опционально
     addressing_mode: "${BOOK_ADDRESSING_MODE}"
     voice_path: "${STYLE_MARKER}"
     voice_source_path: "${VOICE_SOURCE_PATH}"   # опционально
     language: ru
   import_triggered: ${IMPORT_TRIGGERED}
   ```

2. **Резолв адаптивных слов:**
   - `SECTION_WORD` ← `formats.${BOOK_FORMAT}.section_word` (D-31).
   - `DOCUMENT_WORD` ← `formats.${BOOK_FORMAT}.document_word` (D-38).
   - `DOCUMENT_WORD_CAPITALIZED` ← `formats.${BOOK_FORMAT}.document_word_capitalized`.
   - `DOCUMENT_WORD_GENDER_SUFFIX` ← `formats.${BOOK_FORMAT}.document_word_gender_suffix`.

3. **Сводка автору в человеко-читаемом виде:**

   ```text
   Перед тем как создать .book/, проверь — всё ли так:
     • Title:      «${BOOK_TITLE}»
     • Format:     ${BOOK_FORMAT} (единица работы — ${SECTION_WORD})
     • Genre:      ${BOOK_GENRE}${GENRE_PENDING_NOTE}
     • Audience:   ${BOOK_AUDIENCE_SHORT}
     • Addressing: ${BOOK_ADDRESSING_MODE}
     • Voice path: ${STYLE_MARKER_HUMAN}

   Полная конфигурация — в .book.proposed.yaml.
   ```

   `GENRE_PENDING_NOTE` = ` (отложен — потребует /bookbench:research-genre)` если `BOOK_GENRE = pending`, иначе пусто.

4. **`AskUserQuestion`:**
   - **question:** «Всё верно? Если что-то надо переобсудить — скажи.»
   - **options:** `Да, создавай .book/` / `Поправь Title` / `Поправь Format` / `Поправь Genre` / `Поправь Audience` / `Поправь Addressing` / `Поправь Voice path` / `Отмена (удалить proposed)`.

5. **Обработка ответа:**
   - `Да, создавай .book/` → установить `UNFOLD_CONFIRMED=1`, перейти к Step 5.
   - `Поправь <X>` → вернуться в § X коуч-диалога, перепрошить только это измерение, обновить `.book.proposed.yaml`, вернуться в Step 4b пункт 3 (новая сводка).
   - `Отмена` → `rm .book.proposed.yaml`, вывести «Старт отменён. Папка `.book/` не создана.» и exit.

6. **Только после явного «Да, создавай .book/»** — переход к Step 5+.

```bash
# Гард: переменная UNFOLD_CONFIRMED фиксируется только в Step 4b.
# Step 6 ниже стопится, если этой переменной нет.
```

### Step 5 — Read inputs

Read these files into context:

- `${CLAUDE_PLUGIN_ROOT}/defaults.yaml` — specifically `genres.${BOOK_GENRE}` (если не `pending`) и `formats.${BOOK_FORMAT}`. Fallback to `genres.popular-science` и `formats.book` если slug не существует.
- `${CLAUDE_PLUGIN_ROOT}/templates/claude-md/CLAUDE.md` — root `CLAUDE.md` template.
- `.book.proposed.yaml` — авторитетный источник для всех значений (читается заново из файла, чтобы избежать рассинхронизации с in-context переменными).

### Step 6 — Scaffold `.book/` (single transaction)

```bash
set -euo pipefail

# Hard guard: Step 4b confirmation gate.
if [ "${UNFOLD_CONFIRMED:-0}" != "1" ]; then
  echo "ERROR: directory unfolding attempted without Step 4b confirmation"
  exit 1
fi

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
mkdir -p .book/inputs
mkdir -p .book/inputs/staged-voice-samples
if [ ! -f CLAUDE.md ]; then
  cp "$PLUGIN_ROOT/templates/claude-md/CLAUDE.md" CLAUDE.md
fi
echo "scaffold ok"
```

### Step 6a — Move staged import artefacts (if Step 4a ran) — UPDATED in stage 24

If `IMPORT_TRIGGERED=1`, move the artefacts from `${CLAUDE_PLUGIN_DATA}/staging/<session-id>/`:

- `section-draft` files → `.book/inputs/source-drafts/`.
- `notes` → `.book/inputs/notes/`.
- `voice-samples` → `.book/inputs/staged-voice-samples/<slug>.md` (NOT `.book/agent-guidelines/writer/voice-samples.md`!). Frontmatter:
  ```yaml
  ---
  status: staged
  created_by: book-classifier
  created_at: <ISO>
  requires_confirmation: true
  source_kind: imported_voice_samples
  ---
  ```
- `audience-portrait` → `.book/context/audience.md` ТОЛЬКО если автор в Step 4b явно подтвердил «Да» по audience-измерению. В этом случае frontmatter:
  ```yaml
  ---
  status: confirmed
  created_by: book-coordinator-coach
  created_at: <ISO>
  requires_confirmation: false
  approved_by: author
  approved_at: <ISO>
  ---
  ```

**NEVER на этапе /bookbench:start (TOV-08 + D-35 + D-41):**
- НЕ создавать `.book/context/voice-profile.md` (без `.draft`!). Только `.book/context/voice-profile.md.draft` со `status: draft`, либо указатель `.book/context/voice-source-pointer.md` со `status: pointer`.
- НЕ записывать в `.book/agent-guidelines/writer/voice-samples.md` напрямую. Использовать `.book/inputs/staged-voice-samples/`.
- НЕ помечать style_marker как `B1-confirmed` только потому, что есть тексты автора — это `B2-pending`, требует `/bookbench:voice-build --from-staged`.

#### Style-marker artefacts (по § 5 коуч-промпта)

Согласно `STYLE_MARKER`:

- **B1-confirmed:** скопировать `${VOICE_SOURCE_PATH}` в `.book/context/voice-profile.md.draft` с frontmatter:
  ```yaml
  ---
  status: draft
  created_by: book-coordinator-coach
  created_at: <ISO>
  requires_confirmation: true
  source_kind: imported_voice_profile_file
  source_pointer: <VOICE_SOURCE_PATH>
  note: "Этот файл — черновик. Субагенты его не читают. Запусти /bookbench:voice-build для подтверждения."
  ---
  ```

- **B1-derived:** Write `.book/context/voice-source-pointer.md`:
  ```yaml
  ---
  status: pointer
  created_by: book-coordinator-coach
  created_at: <ISO>
  requires_confirmation: false
  source_kind: voice_section_in_wider_document
  source_pointer: <VOICE_SOURCE_PATH>
  ---
  ```
  Тело — короткое описание того, в каком разделе исходного документа упомянут стиль.

- **B2-pending / B2-confirmed / B3-pending:** см. § 5 коуч-промпта; voice-samples в `inputs/staged-voice-samples/`. Перенос в `agent-guidelines/writer/voice-samples.md` — только при `B2-confirmed` после явного «готовая работа / образец» от автора.

- **B3:** ничего не записывается; первая секция запустит `/bookbench:voice-build`.

#### Genre pending artefact (если `BOOK_GENRE = pending`) — D-36

Если `BOOK_GENRE = pending`:

- НЕ копировать жанровые гайдлайны из `defaults.yaml > genres.<X>` в `.book/agent-guidelines/<role>/`. Стартовые шаблоны из `templates/agent-guidelines/<role>/` уже скопированы Step 6 — этого достаточно.
- Создать `.book/context/genre-pending.md` со stub-шаблоном вопросов для `/bookbench:research-genre`. Frontmatter:
  ```yaml
  ---
  status: pending
  created_by: book-coordinator-coach
  created_at: <ISO>
  requires_confirmation: false
  pending_reason: "${BOOK_GENRE_PENDING_REASON}"
  ---
  ```
  Тело — список вопросов: «какой кастомный жанр нужен / какие близкие пресеты / что ещё нужно прояснить».
- В `.book/STATE.md` добавить строку: `genre: pending — required before /bookbench:plan-book`.

#### Addressing-rules artefacts (по § 4a) — D-37

Скопировать стартовые шаблоны:
- `templates/agent-guidelines/writer/addressing-rules.md` → `.book/agent-guidelines/writer/addressing-rules.md`.
- `templates/agent-guidelines/editor/addressing-rules.md` → `.book/agent-guidelines/editor/addressing-rules.md`.

В скопированных файлах заменить плейсхолдер `${ADDRESSING_MODE}` на значение из `.book.proposed.yaml > book.addressing_mode`.

После Step 6a — clean up the staging directory.

### Step 7 — Patch `.book/config.yaml` with coach-assembly results

Use the Edit tool. Substitute placeholders (исходник — `.book.proposed.yaml`):

- `book.title: "TBD"` → `book.title: "${BOOK_TITLE}"`
- `book.genre: popular-science` → `book.genre: ${BOOK_GENRE}` (включая sentinel `pending`).
- `book.format: book` → `book.format: ${BOOK_FORMAT}` (D-30).
- `book.audience: ""` → `book.audience: "${BOOK_AUDIENCE}"`.
- **NEW:** `book.addressing_mode: ""` → `book.addressing_mode: "${BOOK_ADDRESSING_MODE}"` (D-37).
- `book.registry_id: "TBD"` → `book.registry_id: "${REGISTRY_ID}"` (computed in Step 9).
- `book.language: ru` → keep default (or override if title is clearly ASCII English).

Если `BOOK_GENRE != pending`: copy `defaults.yaml > genres.${BOOK_GENRE}.{writing,quality_gates,guidelines}` into `.book/config.yaml` соответственно (по существующей логике WF-05).

Если `BOOK_GENRE = pending`: оставить шаблонные значения (`writing` по умолчанию, `quality_gates` по умолчанию), `guidelines` — пустые (стартовые шаблоны без жанровой надстройки).

Update `compatibility.created_with_bookbench` and `last_synced_with` to `${PLUGIN_VERSION}`.

### Step 8 — Initialise `.book/STATE.md` and `.book/PROJECT.md`

Patch `.book/STATE.md`:

- `current_section`: `book_level`
- `last_action`: `book initialised`
- `bookbench_version`: `${PLUGIN_VERSION}`
- `created_at`: current ISO 8601 timestamp
- `last_touched_at`: same ISO 8601 timestamp
- Append History line:
  ```
  <ISO 8601> — /bookbench:start — initialised "${BOOK_TITLE}" (format=${BOOK_FORMAT}, genre=${BOOK_GENRE}, audience="${BOOK_AUDIENCE}", addressing=${BOOK_ADDRESSING_MODE}, style_marker=${STYLE_MARKER}, import=${IMPORT_TRIGGERED})
  ```
- Если `BOOK_GENRE = pending` — добавить отдельную строку: `genre: pending — required before /bookbench:plan-book`.

Patch `.book/PROJECT.md` with title, genre, format, audience, addressing_mode, style-marker, import-flag. Использовать адаптивный `${DOCUMENT_WORD_CAPITALIZED}` в первой строке-комментарии (служебный заголовок `# Book project` оставляем как есть).

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

# H4: registry_record_upsert (records `format` per D-30)
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
    addressing_mode: $BOOK_ADDRESSING_MODE
    language: ru
    created: $NOW
    last_touched: $NOW
    bookbench_version: $PLUGIN_VERSION
    status: active
YAML
fi
echo "registry updated: id=$REGISTRY_ID format=$BOOK_FORMAT genre=$BOOK_GENRE addressing=$BOOK_ADDRESSING_MODE"
```

Patch `book.registry_id` in `.book/config.yaml` with `${REGISTRY_ID}` (Edit tool).

### Step 9a — Cleanup `.book.proposed.yaml`

```bash
# Successful unfolding — proposed config is no longer needed.
rm -f .book.proposed.yaml
echo "proposed config removed"
```

При отмене `/bookbench:start` (например, в Step 4b опция «Отмена») — `.book.proposed.yaml` тоже удаляется. При падении команды на середине — файл остаётся; при следующем запуске Step 2 предложит автору удалить его и начать сначала.

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

# Sacred policy invariants — после Step 6a / Step 7 / Step 9a:
[ ! -f .book.proposed.yaml ] || { echo "ERROR: .book.proposed.yaml not cleaned up"; exit 1; }
[ ! -f .book/context/voice-profile.md ] || { echo "ERROR: voice-profile.md (without .draft) created on /bookbench:start (forbidden by D-35)"; exit 1; }
echo "verify ok"
```

If any check fails, report and abort.

### Step 11 — Next-step message — UPDATED in stage 24 (D-38 adaptive document_word)

Print the final block. Adaptive substitution: read `formats.${BOOK_FORMAT}.section_word` AND `formats.${BOOK_FORMAT}.document_word` AND `document_word_capitalized` AND `document_word_gender_suffix` from `${PLUGIN_ROOT}/defaults.yaml`. For example, `BOOK_FORMAT=long-read` → `document_word_capitalized="Лонгрид"`, `document_word_gender_suffix=""` → «Лонгрид инициализирован».

Template:

```text
${DOCUMENT_WORD_CAPITALIZED} инициализирован${DOCUMENT_WORD_GENDER_SUFFIX}: «${BOOK_TITLE}»
  Формат:      ${BOOK_FORMAT} (${SECTION_WORD})
  Жанр:        ${BOOK_GENRE}${GENRE_PENDING_NOTE}
  Аудитория:   ${BOOK_AUDIENCE}
  Обращение:   ${BOOK_ADDRESSING_MODE}
  ID в реестре: ${REGISTRY_ID}

В .book/ создано 25+ файлов; CLAUDE.md в корне проекта.

${IMPORT_BLOCK}      # если IMPORT_TRIGGERED=1: «Прикреплённые файлы импортированы и разложены по слотам.»
${PENDING_BLOCK}     # если BOOK_GENRE=pending: «Жанр в статусе pending. Запусти /bookbench:research-genre <slug> перед /bookbench:plan-book.»
${VOICE_BLOCK}       # если STYLE_MARKER=B1-confirmed: «Профиль голоса — черновик. Перед первой ${SECTION_WORD} запусти /bookbench:voice-build (займёт пару минут).»
                     # если B2-pending: «Образцы голоса в .book/inputs/staged-voice-samples/. Перед первой ${SECTION_WORD} — /bookbench:voice-build --from-staged.»

Рекомендуемый следующий шаг:
  /bookbench:plan-book   — собрать план ${SECTION_WORD}-ов (через book-strategist).
  /bookbench:status      — посмотреть текущее состояние ${DOCUMENT_WORD} в любой момент.
```

### Constitutional rules for this command

**MUST:**
- **Всегда выслушать автора до формирования гипотезы.** Step 4 проводится строго по `lib/start-coach-prompt.md`: § 1 (открытое приглашение) → ждём ответ → анализируем → § 2-§ 5 (4 коуч-сборки) + § 4a (addressing_mode).
- **Формулировать ровно одну гипотезу с обоснованием, не меню.** Никаких radio-кнопок до коуч-диалога. Все 4 измерения собираются как «одна гипотеза агента» (или сводная, если автор всё описал чётко в § 0 узком MAY с тремя обязательными условиями).
- **Получать явное «да» по КАЖДОМУ измерению отдельно** через Step 4b шлюз. Сводное «да» по всем измерениям сразу принимается ТОЛЬКО при выполнении узкого MAY (см. § 0 коуч-промпта).
- **Адаптивная обёртка глава/раздел/часть.** В репликах автору используем `formats.<format>.section_word` (D-31).
- **Адаптивный термин документа.** В репликах автору про сам артефакт (книга / лонгрид / статья) используем `formats.<format>.document_word` (D-38). Финальное сообщение Step 11 — через `document_word_capitalized + document_word_gender_suffix`.
- **Если автор приложил файлы — автоматически вызвать `/bookbench:import`** (Step 4a) ДО формирования гипотез. Без флага `--from-existing`.
- **Если автор НЕ приложил файлы — явно зафиксировать «работаем с нуля»** (R-22-D=(б)).
- **Сохранить TOV-08 дословно + усилить через voice-profile lifecycle.** Step 4 § 5 собирает только метку пути B1-confirmed/B1-derived/B2-pending/B2-confirmed/B3/B3-pending; вопросы про 6 параметров `voice-profile` НЕ задаются. Gate стиля остаётся в `book-writer` перед первой `draft.md` + проверка frontmatter `status:` (D-35).
- **`chmod 0755`** для hook-скрипта (Step 6).
- **Идемпотентный upsert** реестра по `path` (Step 9; H4 helper).
- **Sacred policy перед каждой автозаписью** (см. блок «Контракт безопасности» в шапке + `lib/sacred-policy.md`).

**NEVER:**
- **Не показывать radio-кнопки до коуч-диалога.** Все 5 старых вопросов AskUserQuestion удалены.
- **Не задавать вопрос «когда секция считается готовой»** на старте. Значение по умолчанию `workflow.completion_format: editor_pass_plus_author_approval` уже в `templates/book/config.yaml` (T8). Закрывает I-06.
- **Не собирать 6 параметров `voice-profile`** (formality, paragraph length, sentence variety, emotional intensity, dash typography, anglicism tolerance) на старте. Это работа `voice-builder` перед первой секцией (TOV-08).
- **Не блокировать старт книги отсутствием audience-портрета.** Фолбэк через уровень сложности в `lib/start-coach-prompt.md` § 4.
- **Не показывать жанры/форматы/аудиторию как закрытый enum.** Audience B3 — архетипы как примеры, не radio.
- **Не использовать узкоконтекстные категории аудитории** (типа «студенты и преподаватели» из конкретного образовательного кейса).
- **Не перезаписывать существующий `.book/`.** Останавливаемся с подсказкой `/bookbench:resume` (Step 2).
- **Не вызывать `/bookbench:import` если автор не приложил файлы.** Тогда — короткая фиксация «работаем с нуля» (R-22-D).
- **Не модифицировать `${CLAUDE_PLUGIN_DATA}/installation.yaml.source` после первого создания.**
- **Не разворачивать `.book/` без Step 4b confirmation.** Гард `UNFOLD_CONFIRMED=1` в начале Step 6 — обязательный.
- **Не записывать `.book/context/voice-profile.md` (без `.draft`)** ни при каких условиях на этапе start (D-35).
- **Не записывать в `.book/agent-guidelines/writer/voice-samples.md` напрямую.** Только в `.book/inputs/staged-voice-samples/`. Перенос — через `/bookbench:voice-build --from-staged` после явного диалога (D-41 правило 1).
- **Не помечать `style_marker = B1-confirmed`** только потому, что в импорте есть тексты автора (это `B2-pending`).
- **Не выводить `addressing_mode` из черновиков, voice-profile или voice-samples.** Только явный ответ автора в § 4a (D-37).
- **Не записывать жанровые гайдлайны при `BOOK_GENRE = pending`.** Стартовые шаблоны без жанровой надстройки (D-36).
- **Не использовать кальки** «по дефолту», «воркфлоу», «скаффолдинг», «сэмплы» в репликах автору. См. `lib/terminology-ru.md` (D-40).

**MAY (узкое):**
- **Сжать 4 коуч-сборки в одну сводную гипотезу** ТОЛЬКО при выполнении всех трёх условий узкого MAY § 0 коуч-промпта: (а) автор в первом ТЕКСТОВОМ сообщении явно описал все 4 измерения; (б) сводная формулировка автора < 200 знаков; (в) явное подтверждение по каждому измерению ОТДЕЛЬНО на Step 4b (четыре «да», не одно общее). Скиданные файлы НИКОГДА не считаются «автор всё описал чётко».
- **Использовать тёплый партнёрский тон** («дружище», «расскажи как есть») как тональный ориентир, но не как обязательный приём. Главное — нейтрально-партнёрский регистр, не mentor-mode.

</execution>
