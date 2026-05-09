# Контрибуция в BookBench

> Как контрибьютить в фреймворк: что приветствуется, что осторожно, процесс PR, требования к стилю кода и SKILL.md, опен-сорс гигиена, тесты, благодарности, код поведения.

---

## Содержание

1. [Что приветствуется](#что-приветствуется)
2. [Что осторожно](#что-осторожно)
3. [Процесс PR](#процесс-pr)
4. [Стиль кода и контента](#стиль-кода-и-контента)
5. [Жёсткие требования к SKILL.md](#жёсткие-требования-к-skillmd)
6. [Опен-сорс гигиена](#опен-сорс-гигиена)
7. [Тесты](#тесты)
8. [Благодарности и credits](#благодарности-и-credits)
9. [Код поведения](#код-поведения)

---

## Что приветствуется

### Новые жанровые методологии

Самый ценный тип контрибуции: жанровый скилл под `skills/genres/<genre>/`.

В 0.1 готов один — `popular-science`. В backlog'е: `narrative-nonfiction`, `monograph-academic`, `dissertation-humanities`, `dissertation-stem`, `memoir-literary`, `business-nonfiction`, `tech-deep-dive`. Любой из них (и любой другой жанр нон-фикшн) — отличный кандидат на контрибуцию.

Структура жанрового скилла:

```
skills/genres/<genre>/
├── SKILL.md                  ← главный файл; ≤500 строк, см. требования ниже
├── references/
│   ├── methodology-notes.md
│   └── canonical-examples.md
└── tests/
    └── case-NN.md             ← минимум 3 evaluation case
```

Образец — `skills/genres/popular-science/SKILL.md` (176 строк). Используй его как референс структуры.

Запуск через `/book:research-genre <genre>` тоже может **сгенерировать** новый жанровый скилл — если результат хороший, это базис для PR.

### Расширение `anti-ai-cliche` на новые языки

Корпус 0.1: 34 английских паттерна + 12 русско-специфичных = 46. На очереди: украинский, польский, немецкий, испанский, китайский.

Структура контрибуции:

```
skills/anti-ai-cliche/references/
├── patterns.tsv               ← общий корпус; добавь паттерны со столбцом language
└── languages/
    ├── en.md                  ← заметки по специфике языка
    ├── ru.md
    └── <new-language>.md      ← добавь файл
```

Каждый паттерн в `patterns.tsv` — это TSV-строка:

```
id	language	level	pattern	description
35	ru	block	((?:М|м)ы|(?:В|в)ы) отправляемся в путешествие	travel-metaphor opening
46	uk	warn	(?:Д|д)ивовижний	miracle-marker
```

Обязательно: `≥3 evaluation case`'а под язык в `tests/`.

### Рецепты в FAQ

Если ты решил типовую проблему обходом — добавь вопрос в [`faq.md`](faq.md). Формат: вопрос (3-7 строк ответа) + ссылка на детали.

### Переводы документации

Контрибуции переводов на английский, испанский, китайский — приветствуются для 0.2+. На 0.1 политика D-23 фиксирует «только русский» (см. `PROJECT.md`); переводы пойдут в отдельной ветке после 0.1.0.

### Evaluation cases

Каждая роль и каждый скилл имеет директорию `*.eval/` с тестовыми случаями. На 0.1 общее количество — 63 case'а. Больше — лучше. Шаблон case'а — в `tests/templates/case-template.md`.

### Документация

Любые улучшения — описки, неудачные примеры, отсутствующие детали — приветствуются.

---

## Что осторожно

### Новые субагенты

Состав команды зафиксирован на 9 ролей в 0.x (`TR-06` в `PROJECT.md`). Это **не настройка**, а архитектурное решение. Новая роль — это мажорное архитектурное изменение, требующее:

- Issue-обсуждение перед PR.
- Обновления `architecture.md`.
- Обновления `coordinator-design.md` (как координатор будет вызывать новую роль).
- Минимум 5 evaluation case'ов.
- Согласия maintainer'ов.

В 0.1 принимаем только PR на существующие 9 ролей (улучшение тел, гайдлайнов, evaluation cases). Новые роли — возможно в 0.2+, через RFC.

### Новые команды

Каждая команда — это файл в `commands/<name>.md` плюс запись в `manifest.json`. Перед PR с новой командой:

- Открой issue с описанием use-case.
- Объясни, почему существующие 40+ команд не покрывают.
- Предложи имя в slash-namespace `/book:` (без префиксов вне `book:`).

Не любая идея — команда. Часто это конфигурация (через `config.yaml`), скилл (через `skills/`) или рецепт в FAQ.

### Изменения в `architecture.md`

Архитектура — продукт многих этапов проекта. Изменения — мажорное решение. PR с правкой `architecture.md` без issue-обсуждения не принимаются.

### Изменения в `voice-management.md`

Это интерфейсный документ голосовой подсистемы. Любое изменение должно сопровождаться обновлением SKILL.md скиллов `voice-profile` и `voice-builder` (если применимо).

### Изменения в `base-methodology`

23 инварианта универсальны для всех жанров. PR на их изменение требует:

- Подробного обоснования через issue.
- Анализа, как это повлияет на существующие жанровые скиллы.
- Согласия как минимум двух maintainer'ов.

---

## Процесс PR

### Шаги

1. **Issue первым.** Открой issue с описанием намерения. Если это maintain-fix (опечатка, битая ссылка, уточнение в документации) — issue не обязательно, можно сразу PR.
2. **Fork → branch.** Сделай fork репозитория на GitHub, создай branch с осмысленным именем: `add-narrative-nonfiction-skill`, `fix-voice-gate-edge-case`, `docs-improve-quickstart`.
3. **Local-dev режим.** Установи плагин из чекаута: `/plugin install ./bookbench`. Это разблокирует `/book:evolve` и позволяет тестировать на синтетических книгах.
4. **Внеси изменения.** В соответствии со стилем (см. ниже).
5. **Тесты.** Если меняешь скилл — добавь evaluation case'ы. Если меняешь hook — прогони `bookbench/templates/hooks/tests/anti-ai-cliche-lint.test.sh`.
6. **PR.** Сабмить PR с описанием:
   - Что меняется (кратко).
   - Зачем (мотивация).
   - Какой issue закрывает (если был).
   - Чек-лист тестов (что прогнано, что прошло).

### Что в PR-описании

Шаблон:

```markdown
## Что меняется
[1-3 строки]

## Зачем
[5-15 строк]

## Закрывает
- #<issue-number>

## Тесты
- [ ] `bookbench/templates/hooks/tests/anti-ai-cliche-lint.test.sh` — pass
- [ ] `skills/<changed-skill>/tests/` — pass
- [ ] Ручная проверка на синтетической книге [X]

## Обновлённая документация
- [ ] docs/<file>.md
- [ ] CHANGELOG.md (раздел [Unreleased])
```

### Code review

Maintainer'ы смотрят на:

- Соответствие стилю (см. ниже).
- Соблюдение требований к SKILL.md (если меняется скилл).
- Опен-сорс гигиену (нет личных данных, нет real-world specifics).
- Прохождение тестов.
- Обновление документации и CHANGELOG.md.

---

## Стиль кода и контента

### Файлы Markdown

- **Заголовки:** `#`, `##`, `###`. Каждый файл начинается с `#` (заголовок первого уровня).
- **Списки:** `-` для маркированных, `1.`, `2.`, ... для нумерованных.
- **Код:** ` ``` ` с указанием языка (`bash`, `yaml`, `markdown`, `text`).
- **Ссылки:** относительные внутри `bookbench/` (`docs/foo.md`, `../skills/bar/`); абсолютные URL — только для внешних ресурсов.
- **Длина строки:** мягкое ограничение 100 символов; жёсткого нет.

### YAML-фронтматтер

Команды и субагенты используют YAML-фронтматтер. Стиль:

```yaml
---
name: book-strategist
description: ...
tools:
  - Read
  - Write
disallowedTools:
  - Edit
skills:
  - base-methodology
  - genres/popular-science
memory: project
---
```

- `name` ≤64 char, без зарезервированных слов «anthropic» / «claude».
- `description` в третьем лице (не «I do X», а «book-strategist does X»), ≤1024 char.
- `tools` и `disallowedTools` — списки, не строки.

### Системные промпты субагентов

Архитектура: `Identity → Behavior → Constitution`. Это методичка автора по промпт-инжинирингу, обязательная для написания всех системных промптов BookBench (см. `D-13` в `PROJECT.md`).

- **Identity** (5-слойная): кто этот субагент, зачем существует, что не делает.
- **Behavior**: Numbered Procedures, Trigger→Action, Decision Tree, Brief-Then-Execute.
- **Constitution**: MUST/NEVER/MAY правила; Recovery from Rule Break.

Чек-листы готовности — в Части IX методички автора (`infra/.planning/phases/08-финал-агента/08-PROMPT-ENGINEERING-GUIDE.md`).

---

## Жёсткие требования к SKILL.md

Это требования Anthropic к скиллам Claude Code (см. `документы для создания своих агентов/03-skills-best-practices.md` в репозитории методологии). Они **обязательны** для любого PR со скиллом — gate перед merge.

### 1. Имя (`name`) ≤ 64 char

```yaml
---
name: anti-ai-cliche       # ✅ ОК
# name: a-very-long-name-that-violates-the-character-limit-set-by-anthropic-recommendations  # ❌ слишком длинно
---
```

Имя не должно содержать зарезервированных слов: `anthropic`, `claude`.

### 2. Описание (`description`) в третьем лице, ≤ 1024 char

```yaml
description: "anti-ai-cliche detects 46 patterns of AI-generated text and blocks writes when level=block patterns appear. Used by book-writer and book-editor in their respective phases."
# ✅ ОК — третье лицо, описывает что скилл делает
```

```yaml
description: "I detect AI-cliché patterns and block writes."
# ❌ первое лицо
```

```yaml
description: "Use this skill to detect AI-cliché patterns. Tell users to write with care. Avoid AI-cliché. ..." # 1300 chars
# ❌ слишком длинно; не описание, а инструкция
```

### 3. SKILL.md ≤ 500 строк

Если больше — выноси детали в `references/` (отдельные `.md`-файлы) и ссылайся на них из SKILL.md. Принцип: SKILL.md — это **манифест и main flow**; детали — отдельно.

### 4. Ссылки на один уровень

В SKILL.md — ссылки только на файлы того же скилла (`./references/foo.md`). Без cross-skill references на уровне SKILL.md (это зона code-плагина, не скилла).

### 5. Нет time-sensitive контента

Не упоминай конкретные даты в виде «после 2026 года это устарело» или «текущая версия 1.5». Скиллы должны быть стабильны во времени.

### 6. Минимум 3 evaluation case в `tests/`

Каждый скилл — минимум 3 case'а в директории `tests/`. Шаблон — в `tests/templates/case-template.md`. Проходит eval-driven development.

---

## Опен-сорс гигиена

Это **обязательные** правила для любого PR.

### Запретные термины

В коде, документации и тестах — никаких упоминаний:

- Конкретных книг, над которыми работает кто-то из maintainer'ов или авторов фреймворка.
- Имён реальных людей в качестве примеров.
- Религиозно-, политически-, этнически-окрашенных тем в качестве синтетических примеров (вместо них — нейтральные: «история кофе», «биография вымышленного учёного XIX века», «архитектура римских акведуков»).

### Что нельзя коммитить

- Реальные `voice-profile.md` или `voice-samples.md` авторов.
- Реальные тексты глав или фрагменты книг.
- API-ключи, токены, OAuth-credentials.
- Личные пути (`~/Documents/my-actual-book/...`).
- Логи (`TUNING-LOG.md`, `REJECTIONS-LOG.md`, `UPDATE-LOG.md`) с реальными данными.

В `bookbench/templates/book/.gitignore` уже исключены `context/voice-profile.md`, `agent-guidelines/writer/voice-samples.md` и реестры памяти. Если ты тестируешь на собственной книге в local-dev — твоя книга **вне** репозитория плагина (это собственность автора).

### Синтетические примеры

Все примеры в документации, evaluation cases, SKILL.md — на синтетических вымышленных авторах и нейтральных темах. Список рекомендованных синтетических тем:

- «История кофе: от Эфиопии до латте».
- «Биография вымышленного учёного XIX века».
- «Архитектура римских акведуков».
- «Эволюция велосипеда».
- «Как фотография меняла социальные нормы».

Если нужна другая тема — выбирай так, чтобы она была:

1. Нейтральной (не политика, не религия, не этнический конфликт).
2. Достаточно конкретной, чтобы примеры выглядели правдоподобно.
3. С достаточным количеством общедоступных источников (для evaluation case'ов фактчекера).

### Аудит чистоты перед PR

Перед сабмитом — прогон:

```bash
# Если ты в чекауте плагина
$ grep -ri "MyActualBookTitle\|MyName\|<твой-приватный-маркер>" bookbench/
# должен вернуть 0 совпадений

$ bookbench/tests/voice-data-audit.sh
# структурный тест: ни в templates/, ни в docs/, ни в skills/ нет реальных voice data
```

Этот аудит будет повторно прогоняться на этапе 17 (подготовка к публикации) и на каждом релизе.

---

## Тесты

### Структура

```
bookbench/tests/                  ← общие тесты (privacy, voice-data audit)
bookbench/templates/hooks/tests/  ← bash-тесты hook-engine
bookbench/skills/<skill>/tests/   ← evaluation case'ы скиллов
bookbench/agent-templates/<role>.eval/                 ← evaluation case'ы ролей
bookbench/tests/eval-cases/commands/<cmd>/             ← evaluation case'ы команд
bookbench/tests/eval-cases/skills/<skill>/             ← evaluation case'ы скиллов
```

### Запуск

```bash
# Hook engine
$ bash bookbench/templates/hooks/tests/anti-ai-cliche-lint.test.sh

# Privacy tests evolver
$ bash bookbench/tests/eval-cases/commands/evolve/privacy-test-01.sh
$ bash bookbench/tests/eval-cases/commands/evolve/privacy-test-02.sh
# ...

# Voice data audit
$ bash bookbench/tests/voice-data-audit.sh
```

Evaluation case'ы для скиллов и ролей — это `.md`-файлы; они исполняются вручную (читаешь case, прогоняешь на синтетической книге, сверяешь результат с expected output) или через будущий runner.

---

## Благодарности и credits

BookBench опирается на:

- **Методологию проекта BPD (Big Project Done)** и **GSD (Get Shit Done)** — источник идей по этапам, ROADMAP, файловому протоколу обмена артефактами.
- **Официальную документацию Anthropic** по Claude Code, Skills, Subagents, Building Effective Agents — технический фундамент платформенных механизмов. Загружено в `документы для создания своих агентов/` 2026-05-04.
- **Корпус 34 паттернов ИИ-клише** из исследований Wikipedia «AI-generated text patterns» и проекта Humanizer. Расширение русско-специфичных паттернов #35–46 — собственная разработка.
- **Шестипараметрическую модель голоса** — собственная разработка фреймворка, проверенная на синтетических авторах перед релизом.

Если ты что-то добавляешь, опираясь на стороннюю работу — упомяни в credits своего PR.

---

## Код поведения

Мы следуем стандартному [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) (v2.1). Кратко:

- Уважительная коммуникация.
- Конструктивная обратная связь.
- Принятие ответственности за ошибки.
- Фокус на том, что лучше для сообщества и проекта.

Нарушения — на email maintainer'ов или через GitHub abuse report.

---

## Что дальше

- [`architecture.md`](architecture.md) — общая картина для контрибьюторов
- [`dev-mode.md`](dev-mode.md) — local-dev workflow с `/book:evolve`
- [`chapter-cycle.md`](chapter-cycle.md) — что в каждой фазе цикла (для понимания, что менять)
- [`upgrade-guide.md`](upgrade-guide.md) — что не трогается при обновлении (важно для совместимости)
