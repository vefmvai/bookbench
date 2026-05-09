# Quality gate — `voice-builder` skill

> Прогон скилла `voice-builder` по двум опорам **одновременно** (правило проекта BookBench):
> (A) методичка автора по промпт-инжинирингу — Часть IX (4 чек-листа готовности);
> (B) док 03 Anthropic Skills best practices — жёсткие требования к структуре скилла.

Каждый пункт помечен статусом: «прошёл» / «есть замечания» / «исправлено».

---

## Чек-лист A — методичка автора, Часть IX (4 чек-листа)

### A.1 Структурный (~30 мин)

- **YAML frontmatter валиден** — `name: voice-builder`, `description: ...`, `model: sonnet`.
  Парсится. **Статус:** прошёл.
- **5-слойная Identity разглажена** — Identity скилла раскрыт через секции
  `# Voice builder skill`, `## When to use`, `## Three paths` (роль, триггеры,
  границы, пути активации, output-контракт). Не повторяется одно и то же,
  каждый слой добавляет уровень. **Статус:** прошёл.
- **Behavior блоки имеют clear triggers** — секции `## Path B1`, `## Path B2`,
  `## Path B3` каждая начинается с условия активации (точное место вызова и
  длительность). `## Algorithm` имеет precondition «used by both B1 and B3».
  **Статус:** прошёл.
- **Constitution содержит NEVER/ALWAYS** — есть в `## When to use`
  («Never activated on /book:start, ...»), в `## Output contract` («never
  writes anywhere else», «never inside the plugin code tree»), в `## Notes`
  («never carries time-sensitive information»). **Статус:** прошёл.
- **Numbered Procedures используют императив** — алгоритм проекции (Step 1
  «Collect signals», Step 2 «Map signals», ...) в стиле «Build three signal
  sets», «Walk every pair», «Compose» — без «you should». **Статус:** прошёл.

### A.2 Семантический (~1-2 ч)

- **Persona consistent** — голос скилла на всём протяжении: технический,
  процедурный, без mentor-mode и без «we'll help you». **Статус:** прошёл.
- **Нет противоречий между Identity и Behavior** — в `## When to use` сказано
  «Never activated on /book:start»; в Path B3 явно описано чтение артефактов
  книги (PROJECT.md, target-audience.md), что уже произошло до первой главы;
  противоречия нет. **Статус:** прошёл.
- **Output контракт реализуем** — `## Output contract` ясно перечисляет три
  файла (`voice-profile.md`, `voice-profile.yaml`, опционально
  `voice-samples.md`); все пути относительны `.book/`. **Статус:** прошёл.
- **Алгоритм проекции (5 шагов) имеет проверяемые переходы** — Step 1
  собирает три signal set, Step 2 мапит в 6 параметров с reasoning, Step 3
  ловит противоречия, Step 4 пишет прозу, Step 5 пишет файл. Каждый шаг
  имеет вход и выход. **Статус:** прошёл.

### A.3 Multi-turn stability (для трёх путей)

- **B1, B2, B3 не путают друг друга в одной сессии** — пути взаимоисключающие
  по триггеру (выбор `AskUserQuestion` в начале); B1 → B3 разрешённый
  fallback при uncertainty (case-02). **Статус:** прошёл.
- **Cap = 2 в B2 не превышается** — секция `## Path B2 § 7` явно фиксирует
  cap; case-03 проверяет это поведение. **Статус:** прошёл.
- **B3 partial edit не перезапускает весь цикл** — case-04 явно проверяет.
  В тексте скилла: «do not regenerate from scratch». **Статус:** прошёл.

### A.4 Финальный reminder

- **Воспроизведи системный промпт в одно предложение и сравни с description.**
  Одно предложение: «Скилл строит voice profile для книги, когда нет
  готовых текстов для импорта; запускается из book-writer перед первой
  главой, из /book:voice build, или из /book:voice rebuild; предлагает три
  пути B1/B2/B3 и проецирует абстрактные ответы автора на 6-параметрическую
  модель голоса с обязательным разделом Reasoning.»
  **Description содержит** триггеры (book-writer, /book:voice build,
  /book:voice rebuild), три пути с временными бюджетами, output-контракт
  (`voice-profile.md` с Reasoning), и явное «not activated on /book:start
  ...». Соответствие — **прошёл**.

---

## Чек-лист B — док 03 Anthropic Skills best practices

### B.1 `description` в третьем лице ≤ 1024 char

```bash
grep '^description:' SKILL.md | sed 's/^description: //' | tr -d '\n' | wc -c
# → 765
```

В описании используются формы «Builds», «Activated», «Offers», «Projects»,
«Outputs», «Not activated» — все в третьем лице. Никаких `I`, `we`, `you`.
**Статус:** прошёл (765 ≤ 1024).

### B.2 `name` ≤ 64 char, без зарезервированных «anthropic» / «claude»

```bash
grep '^name:' SKILL.md | sed 's/^name: //' | tr -d '\n' | wc -c
# → 13
```

`voice-builder` — 13 символов, нет «anthropic», нет «claude».
**Статус:** прошёл.

### B.3 SKILL.md ≤ 500 строк

```bash
wc -l SKILL.md
# → 398
```

**Статус:** прошёл (398 ≤ 500, запас 102 строки на будущие правки).

### B.4 Ссылки только на один уровень вглубь

В тексте упомянуты:
- `voice-profile` (related skill, нет файловой ссылки — упоминание имени);
- `bookbench/skills/voice-profile/SKILL.md` упомянут только в Notes как
  **related skill**, не как `[link](../voice-profile/SKILL.md)`.

`grep` по `\.\./` или `[\.\.\/]` — **0 совпадений**. **Статус:** прошёл.

### B.5 Нет time-sensitive информации

```bash
grep -E "(2024|2025|2026|recently published|по состоянию на|на момент|recent best)" SKILL.md
# → no matches
```

В тексте нет конкретных годов, версий моделей, фраз «as of XYZ»,
«recently». Упомянутые писатели (Sapolsky, Annie Dillard, Helen Macdonald,
Robert MacFarlane, Daniel Kahneman) — публичные литературные референсы,
не привязанные к конкретной дате. **Статус:** прошёл.

### B.6 ≥ 3 evaluation-кейсов (для voice-builder — 4)

```bash
ls tests/eval-cases/skills/voice-builder/
# → case-01-clear-author-b1.md
# → case-02-uncertain-author-fallback-to-b3.md
# → case-03-b2-iteration.md
# → case-04-b3-partial-edit.md
```

Каждый кейс содержит секции `## Setup` или эквивалент (Trigger + Input),
`## Expected behaviour/output`, `## Acceptance criteria`, `## Pass / fail`,
`## Privacy gate`. **Статус:** прошёл (4 ≥ 3).

### B.7 Examples без личных данных автора BookBench

Прогон опен-сорс grep по 7 запрещённым токенам проекта BookBench
(токены перечислены в CLAUDE.md проекта, раздел «опен-сорс гигиена»;
здесь не воспроизводим, чтобы сам grep не находил себя).

Результат: **0 совпадений** во всех файлах каталога `voice-builder/`.

Все примеры — generic publicly known authors (Sapolsky, Kahneman, Dillard,
Macdonald, MacFarlane). Темы книг в кейсах — generic placeholders
(photosynthesis, memoir, bird migration, computational biology). **Статус:**
прошёл.

### B.8 Дополнительно — нет `pip install` / `npm install` / Windows-paths

```bash
grep -E "(pip install|npm install)" SKILL.md
# → no matches

grep -E "[A-Z]:\\\\" SKILL.md
# → no matches
```

**Статус:** прошёл.

### B.9 YAML frontmatter парсится

`---` ... `---` в начале файла; три валидных ключа (`name`, `description`,
`model`); значения без переносов внутри значения, без специальных символов
требующих кавычек. **Статус:** прошёл.

### B.10 Нет XML angle brackets в `description`

`description` не содержит `<` или `>` (проверено визуально). Только текст.
**Статус:** прошёл.

---

## Сводка

| Чек-лист | Пунктов | Прошло | Замечания |
|----------|---------|--------|-----------|
| A.1 структурный | 5 | 5 | — |
| A.2 семантический | 4 | 4 | — |
| A.3 multi-turn | 3 | 3 | — |
| A.4 финальный reminder | 1 | 1 | — |
| B.1 description third person ≤1024 | 1 | 1 | — |
| B.2 name ≤64 без reserved | 1 | 1 | — |
| B.3 SKILL.md ≤500 | 1 | 1 | — |
| B.4 ссылки на один уровень | 1 | 1 | — |
| B.5 нет time-sensitive | 1 | 1 | — |
| B.6 ≥3 eval-кейсов | 1 | 1 | — |
| B.7 generic examples | 1 | 1 | — |
| B.8 нет install / Windows | 1 | 1 | — |
| B.9 YAML парсится | 1 | 1 | — |
| B.10 нет XML brackets | 1 | 1 | — |
| **Итого** | **23** | **23** | **0** |

**Замечаний нет — все 23 пункта обоих чек-листов прошли.**

---

## Что повторно проверить, если SKILL.md будет редактироваться

1. `wc -l SKILL.md` — должно остаться ≤ 500.
2. `wc -c` на содержимое поля `description:` — должно остаться ≤ 1024.
3. Опен-сорс grep по 7 запрещённым токенам (см. CLAUDE.md проекта) — должен возвращать 0 совпадений.
4. Number of files in `tests/eval-cases/skills/voice-builder/` — должно остаться ≥ 3.
5. Если изменён алгоритм проекции (Step 1-5 в `## Algorithm`) — пересмотреть кейсы 01 и 02 (они опираются на reasoning structure).
6. Если изменён cap = 2 в B2 — пересмотреть кейс 03.
7. Если изменена логика partial edit в B3 — пересмотреть кейс 04.

---

*Создан: 2026-05-08*
*Прогнал: волна A этапа 08.1*
*Опоры: методичка `infra/.planning/phases/08-финал-агента/08-PROMPT-ENGINEERING-GUIDE.md` Часть IX + `документы для создания своих агентов/03-skills-best-practices.md`*
