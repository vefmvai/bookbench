# Настройка под книгу

> Полный гайд по настройке BookBench: каскад источников значений, три уровня кастомизации, override на главу, что нельзя изменить и почему. Все примеры — на синтетических темах.

---

## Содержание

1. [Каскад источников значений](#каскад-источников-значений)
2. [Уровень 1. Количественные параметры — `config.yaml`](#уровень-1-количественные-параметры--configyaml)
3. [Уровень 2. Гайдлайны команды — `agent-guidelines/<role>/`](#уровень-2-гайдлайны-команды--agent-guidelinesrole)
4. [Уровень 3. Тонкая настройка через `book-tuner`](#уровень-3-тонкая-настройка-через-book-tuner)
5. [Голос как настраиваемая сущность](#голос-как-настраиваемая-сущность)
6. [Override на конкретную главу](#override-на-конкретную-главу)
7. [Жанровая настройка](#жанровая-настройка)
8. [Что нельзя легко изменить](#что-нельзя-легко-изменить)

---

## Каскад источников значений

BookBench читает значения параметров из четырёх уровней, в порядке возрастающего приоритета:

```
1. Дефолты плагина (${CLAUDE_PLUGIN_ROOT}/defaults.yaml)
        ↓
2. Глобальные настройки пользователя (${CLAUDE_PLUGIN_DATA}/settings.yaml)
        ↓
3. Книга (.book/config.yaml)
        ↓
4. Override per-section (sections/<N>/spec.md > parameters)
```

Что побеждает: чем ниже в списке, тем выше приоритет. Параметр в `sections/07/spec.md` перебивает значение из `.book/config.yaml`; `config.yaml` перебивает `settings.yaml`; `settings.yaml` перебивает `defaults.yaml`.

Каскад работает per-параметр, а не «всё или ничего». Если `sections/07/spec.md` задаёт только `target_length`, остальные параметры берутся из `config.yaml`.

> **Зачем четыре уровня.** Один уровень становится нечитаемым (сотни параметров). Четыре дают чистое разделение: что общее для жанра, что общее для пользователя, что важно для всей книги, что специфично для главы. См. `D-17` в `PROJECT.md`.

---

## Уровень 1. Количественные параметры — `config.yaml`

Файл `.book/config.yaml` — основной инструмент настройки книги. Создаётся при `/bookbench:start` из дефолтов жанра (для научпопа — из `${CLAUDE_PLUGIN_ROOT}/defaults.yaml > genres.popular-science`).

Редактировать можно через интерактивную команду `/bookbench:config` или руками — это обычный YAML с inline-комментариями (выбран YAML, а не JSON, именно ради комментариев).

### Что обычно настраивают

```yaml
# .book/config.yaml

book:
  title: "История кофе: от Эфиопии до латте"
  genre: popular-science
  language: ru
  target_audience: "широкая аудитория без специальной подготовки"

section:
  target_length:
    min: 6500          # знаков в edited.md
    max: 8500
  paragraph_length:
    target: medium     # short | medium | long
    max_sentences: 6

  # Структура (Pyramid)
  pyramid:
    max_supports: 3    # классическое правило 1+3
    require_governing_thought: true

  # Редактура
  editor:
    target_compression: 0.10   # King's −10% rule; диапазон 0.05–0.15
    cohesion_window: 2          # читать N-1 и N-2 главы для cohesion check
    enable_double_audit: true   # двойной audit-pass анти-ИИ-клише

  # Фактчек
  factchecker:
    max_iterations: 3            # loop verification, DEC-03
    require_sources_for: [number, date, attribution, citation]
    allow_speculative: true      # разрешить тэг [SPECULATIVE] для нарратива

  # Маркетолог
  marketer:
    formats: [telegram, twitter, midjourney_prompt]
    telegram_length:
      min: 800
      max: 1500
    enable: true                 # выключить — фаза не запускается

agents:
  profile: balanced              # budget | balanced | quality, см. models-and-subscriptions.md
  model_overrides:
    # writer: opus               # форсить Opus на писателе вне зависимости от профиля
    # factchecker: haiku         # быстрый дешёвый фактчек

memory:
  compaction_threshold_kb: 10    # двухуровневая компакция: live + archive
  cross_section_strategy: N-1_N-2_N-5   # стратег читает summary разделов N-1, N-2, N-5

hooks:
  anti_ai_cliche:
    enabled: true
    reaction_policy:
      block: 12                  # сколько паттернов level=block (default 12)
      warn: 28                   # warn, default 28
      info: 6                    # info, default 6

privacy:
  include_in_evolver: true       # участвует ли книга в /bookbench:evolve анализе
  private: false                 # full opt-out (evolver вообще не видит)
```

Полный список параметров — в `defaults.yaml` плагина (~50 параметров). 19 из них имеют трассировку на этап 03 проекта (см. `quantitative-checklists.md`).

### Команда `/bookbench:config`

Интерактивный редактор:

```
> /bookbench:config section.target_length.min
🤖 Текущее значение: 6500
   Новое: 7000
   Записать? (y/n)
📝 y
🤖 ✅ .book/config.yaml обновлён.
```

Любое изменение через команду логируется в `TUNING-LOG.md` (вход для `/bookbench:tune`).

---

## Уровень 2. Гайдлайны команды — `agent-guidelines/<role>/`

Гайдлайны — это **индивидуальность команды под конкретную книгу**. Каждая из 9 ролей имеет свою папку:

```
.book/agent-guidelines/
├── coordinator/
│   └── README.md
├── strategist/
│   ├── README.md
│   ├── structural-rules.md
│   └── section-checklist.md
├── writer/
│   ├── README.md
│   ├── voice-samples.md          ← примеры стиля автора
│   ├── forbidden-phrases.md      ← фразы, которых не должно быть
│   └── favorite-metaphors.md     ← метафоры из мира книги
├── factchecker/
│   ├── README.md
│   ├── trusted-sources.md        ← домены и издания, которым доверяет
│   ├── outdated-sources.md
│   └── claim-tags-rules.md
├── editor/
│   ├── README.md
│   ├── cohesion-rules.md
│   └── author-deviations.md      ← осознанные отклонения автора от методологии
├── marketer/
│   ├── README.md
│   ├── brand-voice.md            ← маркетинговый голос (≠ базовый voice-profile)
│   └── telegram-tone.md
├── doc-classifier/, doc-synthesizer/, tuner/
```

> **Принцип Universal Body + Local Guidelines.** Тело субагента (`.book/.claude/agents/<role>.md`) — стабильное, обновляется через `/bookbench:update`. Индивидуальность книги — в гайдлайнах, **никогда не трогается** обновлениями. Это решает фундаментальный конфликт «централизованное обновление ↔ индивидуальность под книгу». См. `D-15` в `PROJECT.md`.

### Пример: настройка фактчекера

```markdown
# trusted-sources.md (для книги «История кофе»)

## High-trust (приоритет)
- britannica.com
- jstor.org (требует подтверждения через WebFetch)
- specialty-coffee-association.org
- worldcoffeeresearch.org

## Medium-trust
- wikipedia.org (только для общих фактов; всегда требует cross-reference)
- atlasobscura.com (этнография — ОК; даты — нужна дополнительная проверка)

## Domain-specific
- icon-coffeebean.com — индустриальная статистика
- perfectdailygrind.com — современные тренды

## Books (для CITED-claims)
- Pendergrast, M. (2010) "Uncommon Grounds"
- Cowan, B. (2005) "The Social Life of Coffee"
- Schapira, J. (2001) "The World of Caffeine"
```

Стартовый набор гайдлайнов копируется при `/bookbench:start` из шаблонов плагина (с подстановкой жанровых дефолтов). Дальше — пишешь руками или через `/bookbench:guidelines <role>`.

### Команда `/bookbench:guidelines <role>`

```
> /bookbench:guidelines factchecker
🤖 [book-coordinator] Что хочешь поправить в гайдлайнах фактчекера?
   1) trusted-sources.md
   2) outdated-sources.md
   3) claim-tags-rules.md
   4) добавить новый файл
📝 1
🤖 [интерактивный редактор]
🤖 ✅ Записано в .book/agent-guidelines/factchecker/trusted-sources.md
   Лог: .book/TUNING-LOG.md (запись TL-2026-05-08-3)
```

---

## Уровень 3. Тонкая настройка через `book-tuner`

Команда `/bookbench:tune` — это **9-я роль команды**, специализированная на анализе паттернов замечаний автора.

### Когда использовать

После 5-10 написанных глав. Tuner смотрит на:

- `TUNING-LOG.md` — все ручные правки гайдлайнов и конфига.
- `REJECTIONS-LOG.md` — все случаи, когда автор после `/bookbench:write-section` правил готовую главу руками (координатор фиксирует это автоматически на финальном гейте).

И ищет **систематические паттерны** (≥3 повторений). Например:

> «Автор 5 раз правил начало главы — каждый раз убирал sycophantic-вступление. В `agent-guidelines/writer/forbidden-phrases.md` уже есть 2 паттерна, но не покрывают эти кейсы. Предлагаю добавить generalized rule.»

### Workflow tuner'а

```
> /bookbench:tune
🤖 [book-tuner] Анализирую TUNING-LOG.md (16 записей) и REJECTIONS-LOG.md (8 записей).

   Нашёл 3 систематических паттерна (≥3 повторений):

   ┌── PATTERN 1 (priority: critical) ──────────────────────────────┐
   │ Автор 5 раз правил начало главы — убирал «вступительные оборо- │
   │ ты с обращением к читателю» («Дорогой читатель», «Представь    │
   │ себе», «Вы когда-нибудь задумывались»).                        │
   │                                                                │
   │ Предлагаемая правка:                                           │
   │ файл: .book/agent-guidelines/writer/forbidden-phrases.md       │
   │ добавить:                                                      │
   │ - «Дорогой читатель»                                           │
   │ - «Представь себе»                                             │
   │ - «Вы когда-нибудь задумывались»                               │
   │ + общий принцип: «не начинать главу с прямого обращения        │
   │    к читателю; вход — через сцену, факт или цитату»            │
   └────────────────────────────────────────────────────────────────┘

   ┌── PATTERN 2 (priority: important) ─────────────────────────────┐
   │ Фактчекер 4 раза тэгировал britannica.com как [CITED] вместо   │
   │ [VERIFIED]. Автор каждый раз менял тэг вручную.                │
   │ Предлагаемая правка:                                           │
   │ файл: .book/agent-guidelines/factchecker/trusted-sources.md    │
   │ переместить britannica.com из medium-trust в high-trust         │
   └────────────────────────────────────────────────────────────────┘

   ┌── PATTERN 3 (priority: optional) ──────────────────────────────┐
   │ Редактор 3 раза не сократил главу до целевых 10% (всегда       │
   │ оставался 4-6%). Автор 2 раза вручную сокращал ещё.            │
   │ Возможно, нужно ужесточить target_compression до 0.07.         │
   └────────────────────────────────────────────────────────────────┘

✋ Применить? Можно по одной (apply <id>) или все сразу (apply all).
📝 apply all
🤖 ✅ Применил 3 правки. Записал в TUNING-LOG.md.
```

Tuner **не правит сам** — только предлагает. Применение через `/bookbench:tune apply <id>` идёт через координатора. Это `D-18` в `PROJECT.md`.

### Команды

```
/bookbench:tune                  # анализ; пишет предложения в stdout
/bookbench:tune apply <id>       # применить конкретное предложение
/bookbench:tune apply all        # применить все
/bookbench:tune:guidelines       # анализ только в части гайдлайнов
/bookbench:tune:workflow         # анализ только в части workflow.md
```

См. также [`dev-mode.md`](dev-mode.md) — там описана эволюция плагина через `/bookbench:evolve`, который агрегирует tuner-паттерны **между книгами**.

---

## Голос как настраиваемая сущность

Голос автора — отдельная сущность, описанная подробно в [`voice-management.md`](voice-management.md). Здесь — кратко, потому что голос пересекается с `agent-guidelines/writer/`.

- Базовый голос книги — в `.book/context/voice-profile.md` (шесть параметров).
- Сэмплы стиля — в `.book/agent-guidelines/writer/voice-samples.md`.
- Маркетинговые голоса — в `.book/agent-guidelines/marketer/brand-voice.md` и `telegram-tone.md`. **Независимы** от базового (TOV-10).

Между книгами голос переносится через личную библиотеку `~/.bookbench/voices/` (вне плагина и вне книги) — пять команд `/bookbench:voice extract|save-as|import|list|build`.

Полный гайд — в [`voice-management.md`](voice-management.md).

---

## Override на конкретную главу

Иногда нужно изменить параметр только для одной главы. Например, глава-пролог должна быть короче обычного, или глава-эпилог — длиннее.

В `sections/<N>/spec.md` есть секция `## Параметры`, и значения из неё перебивают `config.yaml`:

```markdown
# sections/01/spec.md (пролог)

## Цель главы
...

## Параметры
- target_length:
  min: 3000     # короче дефолтных 6500
  max: 4000
- editor.target_compression: 0.05  # меньше сокращения
- enable_marketer: false           # пролог без маркетинговой упаковки
```

Это работает per-параметр; всё, что не указано — берётся из `config.yaml`.

Стратег обычно сам пишет адекватные параметры в `spec.md`, опираясь на роль главы в `ROADMAP.md` (для пролога / эпилога / переходной главы он знает, что нужно поменять). Авторская правка `spec.md` руками — нормальная практика.

---

## Жанровая настройка

Если жанр вашей книги не научпоп, а, например, «нарративный нон-фикшн с элементами биографии» — запустите genre-researcher:

```
> /bookbench:research-genre "нарративный нон-фикшн с элементами биографии"
🤖 [genre-researcher skill] запускаю 5-фазный workflow:
   1. Genre profiling — сравнить с известными жанрами
   2. Deep research — внешние источники по жанру
   3. Methodology generation — извлечь инварианты и переменные
   4. Workflow generation — пресет workflow.md под жанр
   5. 5-level validation — структурная, методологическая, согласованность с base, eval-кейсы, smoke-test

✅ Готов: skills/genres/narrative-nonfiction-biography/SKILL.md (327 строк)
✅ Готов: presets/narrative-nonfiction-biography.yaml
   Сохранён в ${CLAUDE_PLUGIN_DATA}/user-presets/ — будет доступен для следующих книг.

✋ Применить новый workflow к этой книге? (y/n)
📝 y
🤖 ✅ .book/workflow.md перезаписан (бэкап в .book/.backup/).
   .book/agent-guidelines/ заполнен жанро-специфичными гайдлайнами.
```

Подробности — в SKILL.md скилла `genre-researcher` (5 фаз + 5-level validation).

---

## Что нельзя легко изменить

Эти вещи захардкожены архитектурно и менять их можно только контрибуцией в код плагина (см. [`contributing.md`](contributing.md)):

- **23 инварианта `base-methodology`.** Универсальные принципы (структура, связность, черновик, нон-фикшн, анти-ИИ-клише) — общие для всех жанров. Если они блокируют твой кейс — это сигнал, что либо жанр требует своего скилла (`/bookbench:research-genre`), либо нужна контрибуция в `base-methodology` через issue.
- **Структура микро-цикла главы (`section-loop` block).** Состав фаз `strategist → writer → factchecker → editor → marketer` фиксирован для научпопа. Параметризуется через `workflow.md > section_loop.params` (можно отключать factchecker / marketer; нельзя поменять порядок). См. `WF-02` в `PROJECT.md`.
- **`tools` и `disallowedTools` ролей.** Например, фактчекер не имеет `Edit` (адверсариальная стойка); writer имеет `WebSearch` только если включён в `config.yaml`. Эти ограничения — структурные гарантии (`DEC-10`, `MEM-01`, `MEM-07` в `PROJECT.md`); меняются только через PR в `agent-templates/`.
- **9 ролей команды.** Состав ролей фиксирован для 0.x (`TR-06`). Новые роли — это мажорное архитектурное решение, не настройка под книгу.

---

## Что дальше

- [`section-cycle.md`](section-cycle.md) — какие параметры на какой фазе срабатывают
- [`voice-management.md`](voice-management.md) — голос как отдельная настраиваемая сущность
- [`dev-mode.md`](dev-mode.md) — `/bookbench:evolve` для меж-книжного анализа паттернов
- [`upgrade-guide.md`](upgrade-guide.md) — что не трогается при `/bookbench:update`
- [`contributing.md`](contributing.md) — что менять через PR, а не через настройку
