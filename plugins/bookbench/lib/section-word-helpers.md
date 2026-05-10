# section-word-helpers — Adaptive Substitution Procedure

## Назначение

Этот файл документирует механизм adaptive substitution: как субагенты BookBench определяют, какое слово использовать при обращении к автору про единицу работы над текстом («глава», «раздел», «часть»).

Файл предназначен для разработчиков фреймворка. Субагентам он **не обязателен** — они содержат краткий блок-памятку прямо в теле (см. ниже).

---

## Источник правды

`${CLAUDE_PLUGIN_ROOT}/defaults.yaml` → раздел `formats:` → поле `section_word`:

```yaml
formats:
  article:       section_word: "раздел"
  long-read:     section_word: "часть"
  book:          section_word: "глава"
  monograph:     section_word: "глава"
  dissertation:  section_word: "глава"
```

Значение `book.format` конкретной книги хранится в `.book/config.yaml`.

---

## Унифицированный блок для вставки в субагенты

Следующий блок (3-5 строк) вставляется в раздел `<constitution>` → блок **MUST** каждого субагента, который обращается к автору:

```
MUST: При упоминании единицы работы (глава / раздел / часть) в репликах автору —
  прочитай поле `book.format` из `.book/config.yaml`,
  найди `formats[<format>].section_word` в `${CLAUDE_PLUGIN_ROOT}/defaults.yaml`,
  используй ЭТО СЛОВО. По умолчанию при отсутствии `book.format`: «раздел».
  В технических контекстах (имена файлов, полей, путей) всегда используй «section».
```

---

## Алгоритм резолвинга (для субагентов)

```
Trigger: нужно написать автору про единицу работы

1. Read .book/config.yaml → извлечь book.format
2. If book.format не определён → использовать "раздел"
3. Read ${CLAUDE_PLUGIN_ROOT}/defaults.yaml → formats[book.format].section_word
4. Использовать полученное слово в репликах
```

---

## Технические контексты — всегда `section`

Независимо от `book.format`, в следующих контекстах всегда используется слово `section`:

- Имена файлов и директорий: `sections/<N>/`, `section-state.yaml`
- Имена полей в YAML/JSON: `current_section`, `section_word`, `section_chars_range`
- Имена команд: `/bookbench:write-section`, `/bookbench:plan-section`, `/bookbench:audit-section`
- Имена полей в STATE.md: `current_section`, `section_loop`
- Имена блоков workflow.md: `write-section`, `plan-section`
- Передача артефактов между субагентами: `sections/<N>/spec.md`, `draft.md`, `edited.md`

---

## Тест работоспособности

```
book.format = "article" → section_word = "раздел"
book.format = "long-read" → section_word = "часть"
book.format = "book" → section_word = "глава"
book.format = "monograph" → section_word = "глава"
book.format = "dissertation" → section_word = "глава"
book.format = (undefined) → "раздел" (значение по умолчанию)
```

---

*Добавлен: этап 21 (рефакторинг chapter → section)*
*D-31: adaptive substitution mechanism*
*Связанный файл: lib/voices-helpers.md (аналогичный паттерн для голосов)*
