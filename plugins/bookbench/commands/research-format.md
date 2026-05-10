---
description: Researches a target text format on demand (e.g. screenplay, graphic novel, multimedia long-read) and produces a YAML preset under ${CLAUDE_PLUGIN_DATA}/user-formats/. Symmetric to /book:research-genre. Refresh regenerates an existing preset; offline forces the no-internet fallback. Output is one YAML file saved after a structural validation gate and an explicit author confirmation.
argument-hint: "<format-name> [--description \"<text>\"] [--refresh] [--offline]"
allowed-tools: [Read, Write, AskUserQuestion, WebSearch, WebFetch, Task, Bash, Glob]
---

# /book:research-format

<purpose>
Generate a reusable YAML preset for a non-default text format (screenplay,
graphic novel, multimedia long-read, transcript of a multi-episode podcast,
etc.). Symmetric counterpart to /book:research-genre. The preset is saved
to ${CLAUDE_PLUGIN_DATA}/user-formats/<name>.yaml and becomes available for
all future books.
</purpose>

<!-- Stage 22, T4: implementation per research-format-spec.md (stage 20). -->

## Step 1 — Parse arguments

```bash
RAW="${ARGUMENTS:-}"
FORMAT_NAME=""
DESCRIPTION=""
REFRESH=0
OFFLINE=0

# Простой парсер с поддержкой --description "<text>" в кавычках.
set -- $RAW
FORMAT_NAME="${1:-}"
shift 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --description)
      shift
      DESCRIPTION="${1:-}"
      ;;
    --refresh)     REFRESH=1 ;;
    --offline)     OFFLINE=1 ;;
    *) echo "research-format: unknown flag '$1'" 1>&2 ;;
  esac
  shift
done

if [ -z "$FORMAT_NAME" ]; then
  echo "Использование: /book:research-format <format-name> [--description \"<текст>\"] [--refresh] [--offline]"
  echo "Примеры:"
  echo "  /book:research-format screenplay --description \"сценарий полнометражного фильма\""
  echo "  /book:research-format graphic-novel"
  echo "  /book:research-format podcast-transcript --offline"
  exit 0
fi

echo "research-format: name='$FORMAT_NAME' refresh=$REFRESH offline=$OFFLINE"
```

## Step 2 — Resolve plugin paths

Read `${CLAUDE_PLUGIN_ROOT}/lib/plugin-data-helpers.md` once for the H1 / H2 / H6 procedures. Then:

```bash
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
[ -z "$PLUGIN_DATA" ] && {
  if [ -n "${LOCALAPPDATA:-}" ]; then PLUGIN_DATA="$LOCALAPPDATA/bookbench"
  else PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"; fi
}
mkdir -p \
  "$PLUGIN_DATA/user-formats" \
  "$PLUGIN_DATA/research-archives"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && {
  for c in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    [ -f "$c/manifest.json" ] && PLUGIN_ROOT="$c" && break
  done
}
[ -z "$PLUGIN_ROOT" ] && {
  echo "research-format: не удалось определить CLAUDE_PLUGIN_ROOT. Установи переменную или переустанови плагин."
  exit 0
}
echo "research-format: plugin_root=$PLUGIN_ROOT plugin_data=$PLUGIN_DATA"
```

## Step 3 — Slugify and validate name

```bash
SLUG="$(printf '%s' "$FORMAT_NAME" | LC_ALL=C tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

# Проверка длины и формата (snake-case / kebab-case, ≤ 64 символов).
if [ -z "$SLUG" ] || [ "${#SLUG}" -gt 64 ]; then
  echo "research-format: имя '$FORMAT_NAME' невалидно. Используй латиницу, цифры, дефисы, ≤ 64 символов."
  exit 0
fi

# Зарезервированные имена (служебные ключи в defaults.yaml).
case "$SLUG" in
  template|.template|default-for|formats|genres)
    echo "research-format: '$SLUG' — зарезервированное имя. Выбери другое."
    exit 0
    ;;
esac
echo "research-format: slug='$SLUG'"
```

## Step 4 — Pre-flight on existing files

Проверить, что формат не существует ни в `defaults.yaml > formats:`, ни в `${CLAUDE_PLUGIN_DATA}/user-formats/`:

```bash
PRESET_FILE="$PLUGIN_DATA/user-formats/$SLUG.yaml"
HAS_USER_PRESET=0
[ -f "$PRESET_FILE" ] && HAS_USER_PRESET=1

# Проверка против встроенных форматов в defaults.yaml.
HAS_BUILTIN=0
if [ -f "$PLUGIN_ROOT/defaults.yaml" ]; then
  if awk -v slug="$SLUG" '
    BEGIN { in_formats = 0 }
    /^formats:/ { in_formats = 1; next }
    /^[a-zA-Z]/ && !/^formats:/ { in_formats = 0 }
    in_formats && $0 ~ "^  " slug ":" { found = 1; exit }
    END { exit (found ? 0 : 1) }
  ' "$PLUGIN_ROOT/defaults.yaml"; then
    HAS_BUILTIN=1
  fi
fi

if [ "$HAS_BUILTIN" -eq 1 ] && [ "$REFRESH" -eq 0 ]; then
  echo "research-format: формат '$SLUG' уже есть в библиотеке (встроенный)."
  echo "Используй /book:config book.format $SLUG чтобы применить к текущей книге."
  exit 0
fi

if [ "$HAS_USER_PRESET" -eq 1 ] && [ "$REFRESH" -eq 0 ]; then
  echo "research-format: пресет '$SLUG' уже сохранён в $PRESET_FILE."
  echo "Запусти с --refresh, чтобы перегенерировать, или используй /book:config book.format $SLUG."
  exit 0
fi

if [ "$HAS_USER_PRESET" -eq 1 ] && [ "$REFRESH" -eq 1 ]; then
  TS_PREV="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
  mkdir -p "$PLUGIN_DATA/research-archives/format-$SLUG"
  cp "$PRESET_FILE" "$PLUGIN_DATA/research-archives/format-$SLUG/$TS_PREV-prev-preset.yaml" 2>/dev/null || true
  echo "research-format: refresh — резервная копия в research-archives/format-$SLUG/$TS_PREV-prev-preset.yaml"
fi
```

## Step 5 — Get format description from author

Если описание не передано через `--description`, запросить через `AskUserQuestion`:

> «Опиши формат `<SLUG>`, который ты хочешь добавить в библиотеку. Что это? Чем отличается от стандартных форматов (статья / лонгрид / книга / монография / диссертация)? Какая типичная единица работы (сцена / акт / выпуск / часть / эпизод)? Какие типичные объёмы и структура?»

Сохранить ответ в переменную `DESCRIPTION`. Если описание короче 50 символов или явно пустое — переспросить ещё раз.

## Step 6 — Confirm research launch

Перед запуском Deep Research показать автору план:

```text
Я планирую найти типичные параметры формата `<SLUG>`:
  • типичная единица работы (section_word)
  • типичный объём секции (section_chars_range)
  • типичный объём документа (document_sections_range)
  • структурный каркас (structure_skeleton)
  • плотность фактчекинга (factcheck_density)
  • режим маркетинга (marketing_mode)
  • совместимые жанры (compatible_genres)

Это займёт ~5-10 минут. Запустить?
```

`AskUserQuestion`: «Запустить ресёрч?» с вариантами `Да, запускай` / `Уточни описание` / `Отмена`.

Если `Отмена` — выйти. Если `Уточни описание` — вернуться к Step 5.

## Step 7 — Decide run environment

```bash
if [ "$OFFLINE" -eq 1 ]; then
  ENV="no-internet"
else
  ENV="normal"
fi
echo "research-format: run_environment=$ENV"
```

В режиме `no-internet` — пропустить Step 8 (внешний поиск) и сразу перейти к Step 9 со значениями по умолчанию от `book` (по `research-format-spec.md` → «Edge cases → Что делать, если ресёрч не дал результата»).

## Step 8 — Deep Research (если `ENV=normal`)

Структурированный поиск по 7 параметрам. Используй WebSearch / WebFetch для:

1. **Section word** — типичная единица работы. Запрос: `"typical section unit in <FORMAT_NAME>"` или `"<FORMAT_NAME> structure conventions"`.
2. **Section chars range** — средний размер секции. Запрос: `"<FORMAT_NAME> typical scene length"` (для сценариев) / `"<FORMAT_NAME> chapter word count"` (для книжных форматов).
3. **Document sections range** — сколько секций в типичном произведении.
4. **Structure skeleton** — нужен ли `plan-book.md`, какая стандартная структура (трёхактная / пять-актная / ad hoc).
5. **Factcheck density** — для художественных форматов: `standard`; для документальных: `standard` или `enhanced`.
6. **Marketing mode** — `one-promo-per-document` (короткие формы) / `promo-per-section` (длинные/эпизодические) / `minimal` (академические).
7. **Compatible genres** — какие жанры из библиотеки подходят к этому формату (валидируется на Step 10 против существующих жанров).

Результаты ресёрча — в виде структуры:

```text
RESEARCH_RESULTS:
  section_word: "<value>"
  section_chars_min: <int>
  section_chars_max: <int>
  doc_sections_min: <int>
  doc_sections_max: <int>
  structure_skeleton: "<text>"
  factcheck_density: "<standard|enhanced>"
  marketing_mode: "<one-promo-per-document|promo-per-section|minimal>"
  compatible_genres: [<list>]
  sources: [<list of {title, url}>]
```

## Step 9 — Generate YAML preset

Скопировать шаблон из `${CLAUDE_PLUGIN_ROOT}/defaults.yaml > formats..template` и заполнить значения. Если ресёрч не дал результата — использовать значения по умолчанию от `book` для числовых параметров, `section_word` берётся из описания автора, `compatible_genres: []` с пометкой.

```yaml
<SLUG>:
  display_name_ru: "<русское название формата>"
  section_word: "<сцена / акт / выпуск / часть / ...>"
  section_chars_range: { min: <int>, max: <int> }
  document_sections_range: { min: <int>, max: <int> }
  structure_skeleton: "<краткое описание структуры>"
  factcheck_density: "<standard | enhanced>"
  marketing_mode: "<one-promo-per-document | promo-per-section | minimal>"
  compatible_genres: ["<genre1>", "<genre2>"]
  default_for: "researched-by-user-on-<YYYY-MM-DD>"
  source_description: "<краткое описание автора + резюме ресёрча>"
```

Поле `default_for` помечает пресет как пользовательский (отличает от встроенных `default_for: "0.3.0"`). Поле `source_description` сохраняет историю.

## Step 10 — Validate preset structure

Перед сохранением проверить:

| Проверка | Условие |
|----------|---------|
| Все 8 полей заполнены | Нет пустых строк и нулевых диапазонов |
| Имя в snake-case / kebab-case | `^[a-z][a-z0-9-]*$`, ≤ 64 символов |
| `section_chars_range.min < max` | Логическая корректность |
| `document_sections_range.min < max` | Логическая корректность |
| `factcheck_density ∈ {standard, enhanced}` | Допустимые значения |
| `marketing_mode ∈ {one-promo-per-document, promo-per-section, minimal}` | Допустимые значения |
| `compatible_genres` — массив строк, элементы из библиотеки | Сверка против `defaults.yaml > genres:` ∪ `${CLAUDE_PLUGIN_DATA}/user-presets/`. Если жанра нет — предложить запустить `/book:research-genre` или убрать из массива. |

При фейле — исправить и повторить Step 11 (показ автору).

## Step 11 — Author confirmation

Показать сгенерированный YAML автору:

```text
Вот что у меня получилось для формата `<SLUG>`:

<YAML preset>

Параметры подобраны по типичным конвенциям этого формата (источники: <N> ссылок).
Согласен или докрутить какие-то параметры?
```

`AskUserQuestion`: «Согласен с пресетом?» с вариантами `Да, сохраняй` / `Поправь параметр X` / `Отмена`.

При `Поправь` — уточнить какой именно параметр и пересчитать. При `Отмена` — пресет не сохраняется, команда выходит.

## Step 12 — Persist preset

```bash
# Записать YAML в ${CLAUDE_PLUGIN_DATA}/user-formats/<slug>.yaml.
# Сначала записываем во временный файл, потом atomic mv.
TMP_FILE="$PRESET_FILE.tmp"
# (Тело YAML — через Write tool с проверкой структуры.)
mv "$TMP_FILE" "$PRESET_FILE" 2>/dev/null || true

# Запись в research-log.md (или эквивалент).
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LOG="$PLUGIN_DATA/research-log.md"
[ -f "$LOG" ] || printf '# Research log\n\n' > "$LOG"
echo "- $TS — created format \`$SLUG\` via /book:research-format" >> "$LOG"
```

Атрибут `Write` использовать для самого YAML (через `tools: Write` в front-matter).

## Step 13 — Append History to .book/STATE.md (if inside book context)

Если команда вызвана внутри папки книги (`.book/` существует), добавить запись в History:

```bash
if [ -d .book ]; then
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- $TS — /book:research-format $SLUG — preset created" >> .book/STATE.md
fi
```

Это **не обязательно** при автономном вызове (например, во время `/book:start` до создания `.book/`). В таком случае шаг пропускается без ошибки.

## Step 14 — Return / next-step message

Если команда вызвана из `/book:start` (контекст коуч-диалога):
- Вернуть имя формата `$SLUG` в коуч-диалог.
- Алгоритм матчинга формата (`matching-design.md` § 3.2 ветка B2) переходит к шагу B1.4 с гипотезой `$SLUG`.

Если самостоятельный вызов:

```text
research-format: пресет для `$SLUG` сохранён.
  Файл: $PLUGIN_DATA/user-formats/$SLUG.yaml

Следующие шаги:
  • Применить к текущей книге:    /book:config book.format $SLUG
  • Стартовать новую книгу:        /book:start (выбери формат `$SLUG` в коуч-диалоге)
  • Перегенерировать пресет:       /book:research-format $SLUG --refresh
```

## Notes

- Команда работает по той же модели, что `/book:research-genre` (см. `commands/research-genre.md`). Симметрия архитектуры — ключевой принцип D-30: расширяемые библиотеки `genre` и `format`.
- Команда никогда не пишет в `${CLAUDE_PLUGIN_ROOT}` (это файл плагина, read-only во время выполнения). Только `${CLAUDE_PLUGIN_DATA}/user-formats/` и `${CLAUDE_PLUGIN_DATA}/research-log.md`.
- При совпадении имени пользовательского пресета со встроенным форматом будущей версии плагина — приоритет у пользовательского (каскад D-17, локальное переопределяет глобальное). Это безопасное поведение для D-21 (`/book:update`).
- `--refresh` архивирует предыдущий пресет в `research-archives/format-<slug>/<timestamp>-prev-preset.yaml` для возможности отката.
- `--offline` — резервный режим без интернета: используются значения по умолчанию от `book`, `section_word` берётся из описания автора, `compatible_genres: []`. Пресет помечается в `source_description`: «ресёрч недостаточен; параметры на основе значений по умолчанию формата `book`».
- Privacy: команда читает только описание автора (через `--description` или AskUserQuestion) и публичные веб-источники. Не читает `.book/sections/`, `.book/inputs/`, `.book/intel/`.

## Constitutional rules for this command

- **MUST** проверить, что имя формата не совпадает с встроенным или существующим пользовательским — до запуска ресёрча (Step 4).
- **MUST** показать автору сгенерированный YAML до сохранения — без явного подтверждения автора пресет не пишется (Step 11).
- **MUST** атомарная запись YAML (запись во временный файл → mv) — не оставлять полузаписанные пресеты при сбое.
- **NEVER** писать в `${CLAUDE_PLUGIN_ROOT}/defaults.yaml` — это файл плагина, изменяется только релизами.
- **NEVER** удалять существующий пресет без `--refresh` (тогда — архивация, не удаление).
- **NEVER** запускать `/book:research-format` для встроенных форматов без `--refresh` (выйти с подсказкой `/book:config book.format <name>`).
