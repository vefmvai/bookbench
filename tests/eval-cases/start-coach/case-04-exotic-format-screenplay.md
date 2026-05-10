# Case 04 — Экзотический формат: автор пишет киносценарий (B2 ресёрч)

> **Покрытие:** ни один встроенный формат не описывает то, что делает автор. Активируется ветка B2 в § 2 — вызов `/bookbench:research-format screenplay`. После генерации пресета — возврат к B1.4 с гипотезой `screenplay`.
>
> **Источник правды:** `lib/start-coach-prompt.md` § 2 ветка B2; `matching-design.md` § 3.2 ветка B2; `research-format-spec.md` (шаги 1–7).

## Setup

- Текущая папка: `/tmp/test-screenplay/`.
- Папка пустая.
- `${CLAUDE_PLUGIN_DATA}/user-formats/` пустой (нет кастомных пресетов).
- 5 встроенных форматов в `defaults.yaml`: `article`, `long-read`, `book`, `monograph`, `dissertation`.
- Окружение `online` (есть WebSearch / WebFetch).

## Author messages

**Сообщение 1:**

> «Хочу написать сценарий полнометражного фильма. Драма, 90-100 страниц, три акта. Это для подачи на питчинг продюсерам.»

**Сообщение 2 (на ветку B2):**

> «Запускай ресёрч, давай создадим пресет для screenplay.»

**Сообщение 3 (после генерации пресета `/bookbench:research-format`):**

> «Согласен с пресетом, сохраняй.»

**Сообщение 4 (после возврата к B1 с гипотезой screenplay):**

> «Да, формат screenplay — то что нужно.»

**Сообщение 5 (на гипотезу жанра):**

> «Жанр — драма, можно записать как `fiction-screenplay` или просто `fiction`.»

**Сообщение 6 (на гипотезу аудитории):**

> «Аудитория — продюсеры и script readers на питчинге, знают язык формата, читают быстро, ищут крючок.»

## Expected agent behaviour

### § 1. Открытое приглашение
- Стартовая реплика, ожидание ответа.

### § 6. Trigger → Action
- Файлов нет → «Окей, работаем с нуля; если позже найдёшь черновики — есть `/bookbench:import`».

### § 2. Format — ветка B2 (нет пресета)
- Анализ признаков: «сценарий полнометражного фильма», «90-100 страниц», «три акта», «питчинг продюсерам» → ни один из 5 встроенных форматов не покрывает (article/long-read/book/monograph/dissertation — европейская рамка прозы).
- Уверенность всех пресетов ниже порога.
- Активируется B2:

  ```text
  Ни один из готовых форматов не описывает то, что ты делаешь, точно.
  У меня есть: статья, лонгрид, книга, монография, диссертация.

  То, что ты описываешь — это киносценарий. Три варианта:

    (а) Я могу запустить ресёрч и сгенерировать кастомный пресет под формат
        `screenplay` — займёт минут 5-10. Запустить?
    (б) Свободный текст с дефолтами от `book` (но единицы будут «глава», что неправильно).
    (в) Ближайший пресет — может быть `long-read`, но это не оно.

  Что выбираешь?
  ```

- Автор: «Запускай ресёрч».

### § 2 продолжение: вызов `/bookbench:research-format`
- `Task` (или прямой вызов команды): `/bookbench:research-format screenplay --description "сценарий полнометражного фильма, 90-100 страниц, три акта, для питчинга продюсерам"`.
- В команде:
  - **Step 3** валидирует `slug=screenplay` — не зарезервировано, в библиотеке нет.
  - **Step 6** показывает план Deep Research → автор подтверждает.
  - **Step 8** Deep Research через WebSearch:
    - section_word: «сцена»
    - section_chars_range: ~1500-3500 знаков (1 страница ≈ 1 минута экранного времени, средняя сцена 1-3 страницы)
    - document_sections_range: ~40-80 сцен (90-100 страниц / 1-2 страницы на сцену)
    - structure_skeleton: «трёхактная структура (setup / confrontation / resolution); inciting incident в первом акте; midpoint в середине второго; climax в третьем»
    - factcheck_density: «standard» (для драмы — но если biopic, то enhanced)
    - marketing_mode: «one-promo-per-document» (питчинговый pack: logline + synopsis + sample pages)
    - compatible_genres: `["fiction"]` (предположим, что в библиотеке уже есть `fiction` или будет создан через `/bookbench:research-genre`)
  - **Step 11** показывает сгенерированный пресет автору.
- Автор: «Согласен с пресетом, сохраняй.»
- **Step 12** записывает в `${CLAUDE_PLUGIN_DATA}/user-formats/screenplay.yaml`.

### § 2 после ресёрча: возврат к B1.4
- Агент: «Сохранил пресет screenplay. Возвращаюсь к нашему диалогу. Формат — `screenplay`. Согласен?»
- Автор: «Да, формат screenplay — то что нужно.»
- `BOOK_FORMAT = screenplay`.

### § 3. Genre
- Filter `formats.screenplay.compatible_genres` = `["fiction"]`.
- Гипотеза: «По описанию жанр — драма (художественный сюжетный текст). Запишу как `fiction`. Согласен?»
- Автор: «Жанр — драма, можно записать как fiction-screenplay или просто fiction.»
- Агент уточняет: «Раз пресет screenplay уже есть в библиотеке, жанр запишу как `fiction` — это тип, форма уже отражена в `format`. Согласен?»
- Подтверждение → `BOOK_GENRE = fiction`.
  - **Примечание:** на 0.3.0 `fiction` — встроенный жанр (см. `defaults.yaml > genres > fiction`). Если на момент кейса его нет — кейс продолжается через ветку B2 жанра (`/bookbench:research-genre fiction`). Для упрощения предположим, что `fiction` уже встроен.

### § 4. Audience (B1, готовый портрет)
- 4 аспекта в сообщении 6:
  - демография: «продюсеры и script readers»
  - предварительные знания: «знают язык формата»
  - мотив: «питчинг» (отбор)
  - ожидания: «крючок», «читают быстро»
- Структурирование: «Твой читатель — индустриальный профессионал (продюсер / script reader на питчинге). Они знают конвенции формата и читают быстро в режиме отбора. Ждут от первой страницы крючка. Согласен?»
- Автор подтверждает.
- `BOOK_AUDIENCE = "Индустриальный читатель (продюсер / script reader на питчинге), знает конвенции формата, читает быстро в режиме отбора, ищет крючок"`.

### § 5. Style-marker
- Подсказка → автор не приложил voice-samples → `STYLE_MARKER = B3`.

## Expected `${CLAUDE_PLUGIN_DATA}/user-formats/screenplay.yaml`

```yaml
screenplay:
  display_name_ru: "сценарий"
  section_word: "сцена"
  section_chars_range: { min: 1500, max: 3500 }
  document_sections_range: { min: 40, max: 80 }
  structure_skeleton: "трёхактная структура (setup / confrontation / resolution); inciting incident в первом акте; midpoint в середине второго; climax в третьем"
  factcheck_density: "standard"
  marketing_mode: "one-promo-per-document"
  compatible_genres: ["fiction"]
  default_for: "researched-by-user-on-2026-05-09"
  source_description: "сценарий полнометражного фильма, 90-100 страниц, три акта, для питчинга продюсерам; ресёрч по индустриальным конвенциям WGA / Hollywood format"
```

## Expected `.book/config.yaml`

```yaml
book:
  title: "<author-provided>"
  genre: fiction
  format: screenplay
  audience: "Индустриальный читатель (продюсер / script reader на питчинге), знает конвенции формата, читает быстро в режиме отбора, ищет крючок"
  language: ru
  registry_id: "<computed>"
workflow:
  completion_format: editor_pass_plus_author_approval
```

## Expected next-step message

`SECTION_WORD` для `format=screenplay` = «сцена» (по только что созданному пресету).

```text
Книга инициализирована: «<title>»
  Формат:    screenplay (сцена)
  Жанр:      fiction
  Аудитория: Индустриальный читатель (продюсер / script reader на питчинге), знает конвенции формата, читает быстро в режиме отбора, ищет крючок
  ID в реестре: <slug>-<date>

Рекомендуемый следующий шаг:
  /bookbench:plan-book   — собрать план сцен (через book-strategist).
```

## Acceptance criteria

- ✅ Ветка B2 в § 2 сработала.
- ✅ `/bookbench:research-format screenplay` вызвана.
- ✅ Пресет сохранён в `${CLAUDE_PLUGIN_DATA}/user-formats/screenplay.yaml`.
- ✅ После ресёрча — возврат к B1.4 с гипотезой `screenplay`.
- ✅ В `.book/config.yaml` `format: screenplay`.
- ✅ В next-step message адаптивная обёртка «сцена» (D-31 + новый пресет).

---

*Кейс: 04 exotic-format-screenplay.*
*Решение R-22-C=(б), покрывает § 3.2 ветка B2 + цикл коуч → research-format → возврат.*
