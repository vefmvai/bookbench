# FAQ — Частые вопросы

> 24 типовых вопроса в пяти кластерах: установка и совместимость (4), генерация книги (5), голос (3), обновления (4), troubleshooting (8 — включая известные ограничения 0.1.0).

---

## Содержание

- [Кластер 1. Установка и совместимость](#кластер-1-установка-и-совместимость)
- [Кластер 2. Генерация книги](#кластер-2-генерация-книги)
- [Кластер 3. Голос автора](#кластер-3-голос-автора)
- [Кластер 4. Обновления и совместимость](#кластер-4-обновления-и-совместимость)
- [Кластер 5. Troubleshooting и known issues](#кластер-5-troubleshooting-и-known-issues)

---

## Кластер 1. Установка и совместимость

### 1.1. Какая версия Claude Code нужна?

Claude Code `^2.0`. Точное требование зафиксировано в `plugins/bookbench/manifest.json` → поле `compatible_claude_code`. Если у тебя 1.x — обнови. Если 2.x — всё работает.

Проверить: `claude --version`. Подробности по установке — в [`installation.md`](installation.md).

### 1.2. Какая подписка Claude нужна?

Работает на любом тарифе (Pro / Max-5x / Max-20x / Team / API), но дневной лимит Opus на Pro выгорает быстро, потому что три из пяти ролей цикла (стратег / писатель / маркетолог) — структурно на Opus.

Рекомендации по выбору профиля моделей:

| Подписка | Профиль | Что меняется |
|----------|---------|---------------|
| Pro ($20/mo) | `budget` | Verify-роли (фактчекер, редактор) на Haiku; creative core всё равно Opus |
| Max-5x | `balanced` | Дефолт. Verify-роли на Sonnet |
| Max-20x | `quality` | Synthesizer на Opus (для качественного импорта) |
| API | `quality` или ручная настройка | Себестоимость per-call; используй `model_overrides` |

Полное описание — в [`models-and-subscriptions.md`](models-and-subscriptions.md).

### 1.3. Можно ли работать без MCP-серверов?

Да. На 0.1 фактчекер использует встроенные `WebSearch` + `WebFetch`. MCP-серверы можно подключить **опционально** для специфичных доменов:

- `MCP-Exa` — academic search.
- `MCP-PubMed` — медицинская литература.
- `MCP-OpenLibrary` — book metadata.

Конфигурация — в `.book/.claude/agents/book-factchecker.md` → секция `mcpServers`. Никаких MCP по умолчанию не требуется и не устанавливается.

### 1.4. Что делать, если `/bookbench:doctor` показывает ошибку?

`/bookbench:doctor` диагностирует три вещи: совместимость с Claude Code, наличие папок `${CLAUDE_PLUGIN_ROOT}` и `${CLAUDE_PLUGIN_DATA}`, исполняемость bash-hooks. Типичные ошибки:

- `Bash hooks: not executable` → `chmod +x .book/.hooks/anti-ai-cliche-lint.sh` (если ты в папке книги).
- `Plugin data dir missing` → запусти любую `/bookbench:*` команду — `${CLAUDE_PLUGIN_DATA}` создастся автоматически.
- `Registry book at <path> not found` → `/bookbench:forget <book-id>` уберёт осиротевшую запись из реестра.
- `Claude Code version too old` → обнови Claude Code до 2.x.

Если `/bookbench:doctor` показывает зелёное «всё ОК» — инфраструктура в порядке, проблема в чём-то другом. Подробности — кластер 5 ниже.

---

## Кластер 2. Генерация книги

### 2.1. Что если стратег предложил странный план?

Прерви, открой `.book/PROJECT.md`, уточни:

- Описание книги (что именно ты хочешь рассказать).
- Целевую аудиторию (одна-две строки).
- Ограничения (если есть — например, «не более 25 глав», «без формул»).

Запусти `/bookbench:plan-book` ещё раз. Стратег идемпотентен — переписывает `ROADMAP.md` каждый раз заново.

Если план всё равно странный — проверь `agent-guidelines/strategist/structural-rules.md`. Возможно, дефолты жанра не подходят твоей книге.

### 2.2. Можно ли писать главы без `/bookbench:plan-book`?

Технически да: `/bookbench:plan-section 1` сработает и без `ROADMAP.md`. Стратег спросит про основные параметры главы и напишет `spec.md`. Но **не рекомендуется**: без `ROADMAP.md` red thread keywords не извлечены, cohesion между главами не контролируется, реестры памяти растут хаотично.

Для коротких книг (≤5 глав) можно. Для длинных (20+) — план обязателен.

### 2.3. Как работает `/bookbench:next`?

Это команда «умной подсказки». Координатор читает `STATE.md`, `workflow.md` и определяет, какой логический шаг следующий:

- Если книга только инициализирована, нет `ROADMAP.md` → `/bookbench:next` подсказывает запустить `/bookbench:plan-book`.
- Если есть план, но нет `sections/01/` → подсказывает `/bookbench:plan-section 1`.
- Если глава 1 готова, глава 2 не начата → `/bookbench:plan-section 2`.
- Если глава недописана (есть `draft.md`, нет `edited.md`) → подсказывает `/bookbench:write-section:edit <N>`.

Полная карта переходов — в `next-design.md` этапа 7.2 проекта.

### 2.4. У меня уже есть глава, написанная в Word. Что с ней делать?

Сценарий B — «с существующих материалов». Положи `.docx` в текущую папку и запусти `/bookbench:start` — на стартовом коуч-диалоге приложи файлы к сообщению, импорт сработает автоматически (флаг `--from-existing` отменён в 0.3.0). Если книга уже инициализирована — `/bookbench:import`.

Классификатор разберёт `.docx` на типизированные фрагменты (section-draft, voice-sample, glossary-entry, ...). Синтезатор привяжет фрагменты к будущим главам в `INGEST-DECISIONS.md`. Дальше `/bookbench:write-section <N>` запустится в режиме `from-existing`: писатель **дополняет** импортированный черновик, а не переписывает с нуля.

Полный путь — в [`quickstart.md`](quickstart.md), сценарий B.

### 2.5. Два стартовых сценария — как выбрать какой?

Простое правило:

- **Сценарий A — с чистого листа.** У вас есть только идея и пустая папка.
- **Сценарий B — с существующих материалов.** У вас есть **хотя бы один** из трёх:
  - Чаты `claude.ai` с прорабатыванием темы.
  - Заметки в Obsidian / Apple Notes / md-файлах.
  - Черновики глав или фрагменты в `.docx`.

В реальности у большинства авторов нон-фикшн-книг есть «багаж» — это сценарий B. Сценарий A полезен для начинающих авторов или для книг на новую тему.

В обоих случаях после установки команда субагентов одна и та же, файловый протокол один и тот же, микро-цикл главы один и тот же. Разница — только в стартовом состоянии реестров и режиме `book-writer`'а.

---

## Кластер 3. Голос автора

### 3.1. Где живёт мой голос?

Голос распределён по трём местам:

1. `.book/context/voice-profile.md` — описание прозы + шесть параметров (per-книга).
2. `.book/agent-guidelines/writer/voice-samples.md` — примеры твоего стиля (per-книга).
3. `~/.bookbench/voices/` — личная библиотека голосов (per-машина, **между книгами**).

Маркетинговые голоса — отдельные:

4. `.book/agent-guidelines/marketer/brand-voice.md` — голос для соцсетей (независим от базового).
5. `.book/agent-guidelines/marketer/telegram-tone.md` — для Telegram-постов.

Полная картина — в [`voice-management.md`](voice-management.md).

### 3.2. Как перенести голос на новую книгу?

```bash
# В книге A, где голос уже сформирован
> /bookbench:voice save-as my-warm-essay-voice
🤖 ✅ Сохранён в ~/.bookbench/voices/my-warm-essay-voice.md

# Позже, в новой книге B
$ cd ../book-b
> /bookbench:voice list
🤖 Доступно 3 голоса:
   - my-warm-essay-voice (сохранён 2026-04-15; informal-warm-medium)
   - my-academic-voice  (сохранён 2026-03-20)
   - test-voice         (сохранён 2026-02-10)

> /bookbench:voice import my-warm-essay-voice
🤖 ✅ Применён к этой книге.
```

Полные команды — `/bookbench:voice extract|save-as|import|list|build` в [`voice-management.md`](voice-management.md).

### 3.3. Можно ли писать без заполненного `voice-profile.md`?

Нет. Это структурная гарантия фреймворка (`TOV-08`): `book-writer` **не пишет ни строки** `draft.md`, пока `voice-profile.md` пуст или содержит только TBD-плейсхолдеры. Voice gate срабатывает в теле субагента, не в команде — никакая команда не может проскочить мимо него.

Если голос ещё не настроен — координатор предложит три пути:

- **B1** — быстрое интервью прямо в текущей сессии (5 мин, 5 вопросов).
- **B2** — отдельная сессия `/bookbench:voice build` (15-20 мин, с пробным абзацем и итерацией).
- **B3** — агент сам предложит профиль на основе плана книги (2-3 мин на подтверждение).

Подробности — [`voice-management.md`](voice-management.md), раздел «Three paths to build a voice».

---

## Кластер 4. Обновления и совместимость

### 4.1. Что делает `/plugin update`?

Это стандартная команда Claude Code. Обновляет код плагина в `${CLAUDE_PLUGIN_ROOT}`. **Никогда не трогает**:

- `${CLAUDE_PLUGIN_DATA}` (реестр книг, глобальные настройки) — переживает `/plugin update` (гарантия Anthropic).
- Все папки книг (`.book/`) — переживают `/plugin update` (гарантия архитектуры BookBench).

Это значит: после `/plugin update` все твои книги остаются в той версии, в какой были на момент инициализации (`WF-04`).

### 4.2. Что делает `/bookbench:update`?

Это команда, которая **внутри одной книги** опционально подтягивает обновления тел субагентов и hook-скрипта из новой версии плагина. Делает 3-way merge с подтверждением для каждого изменённого файла.

`/bookbench:update` **не трогает**:

- `.book/agent-guidelines/<role>/` (твои гайдлайны).
- `.book/context/` (факты о книге).
- `.book/sections/` (твой текст).
- Логи: `TUNING-LOG.md`, `REJECTIONS-LOG.md`, `UPDATE-LOG.md`.
- Реестры памяти: `.book/.claude/agent-memory/`.

`/bookbench:update` **может** обновить (с подтверждением):

- `.book/.claude/agents/<role>.md` (тело субагента).
- `.book/.hooks/anti-ai-cliche-lint.sh` (hook-скрипт).

Перед обновлением — бэкап в `.book/.backup/<timestamp>/`. После — запись в `UPDATE-LOG.md`.

Подробности — [`upgrade-guide.md`](upgrade-guide.md).

### 4.3. Потеряются ли мои правки после `/bookbench:update`?

Нет. Принцип архитектуры: «папка книги — собственность автора». Любые твои правки в `agent-guidelines/`, `context/`, `sections/` и логах **не трогаются никогда**. Тела субагентов и hook-скрипт могут обновиться — но только с твоим явным подтверждением через 3-way merge (см. предыдущий вопрос).

### 4.4. Можно ли откатиться, если `/bookbench:update` сломал что-то?

Да. Перед каждым `/bookbench:update` создаётся бэкап:

```
.book/.backup/2026-05-08-1432/
├── agents/
│   ├── book-coordinator.md  (старая версия)
│   ├── book-strategist.md
│   └── ...
└── .hooks/
    └── anti-ai-cliche-lint.sh
```

Откат — ручное копирование:

```bash
$ cp -r .book/.backup/2026-05-08-1432/agents/* .book/.claude/agents/
$ cp .book/.backup/2026-05-08-1432/.hooks/* .book/.hooks/
```

Подробности — [`upgrade-guide.md`](upgrade-guide.md), раздел «Откат».

---

## Кластер 5. Troubleshooting и known issues

### 5.1. Хук `anti-ai-cliche-lint.sh` не блокирует, хотя клише есть

Проверь по порядку:

1. **Исполняемость:** `ls -l .book/.hooks/anti-ai-cliche-lint.sh` — должен быть `755`. Если нет — `chmod +x`.
2. **Включён в `config.yaml`:** `hooks.anti_ai_cliche.enabled: true`.
3. **Тело субагента содержит hook:** `.book/.claude/agents/book-writer.md` → секция `hooks:` → `PostToolUse` на `Edit|Write` с путём к `anti-ai-cliche-lint.sh`.
4. **Корпус паттернов на месте:** `plugins/bookbench/skills/anti-ai-cliche/references/patterns.tsv` (внутри установленного плагина — просто `${CLAUDE_PLUGIN_ROOT}/skills/anti-ai-cliche/references/patterns.tsv`) — должен содержать 46 паттернов.

Если всё на месте, но клише пропускается — возможно, паттерн уровня `info` (6 семантических, не блокируют). Проверь `reaction_policy` в `config.yaml`.

### 5.2. Воркфлоу-команды (`/bookbench:next`, `/bookbench:run`) не работают как ожидаешь

**Известное ограничение 0.1.0 — `B-14-06`:** `/bookbench:next --execute` требует подтверждения механизма nested slash command dispatch в Claude Code. Workaround: используй `/bookbench:next` без `--execute` — она покажет рекомендуемую команду текстом, скопируй и вставь. Полный fix — в 0.2+.

### 5.3. `/bookbench:evolve` пишет «no patterns found», хотя у меня их много

**Известное ограничение 0.1.0 — `B-14-04`:** tuner не прогонялся на реальных REJECTIONS до релиза (только на синтетических тестах). На реальных данных могут всплыть граничные случаи распознавания паттернов. Workaround: запусти `/bookbench:tune` напрямую (внутри книги) — он использует те же алгоритмы, но на одиночной книге; если там паттерны находятся, проблема в евольвере. Сообщи через issue (см. [`contributing.md`](contributing.md)) — фикс пойдёт минорным релизом 0.1.x.

### 5.4. `/bookbench:research-genre` зависает на этапе deep research

**Известное ограничение 0.1.0 — `B-14-03`:** genre-researcher не прогонялся на реальном неизвестном жанре до релиза. Возможные причины:

- Без интернета — researcher переходит в fallback-режим (использует встроенные знания), но это медленнее.
- Нестандартный жанр (например, «эссе о квантовой кулинарии») — researcher делает много итераций.

Workaround: установи timeout на 5 минут (`/bookbench:research-genre <жанр> --timeout 300`); если не успевает — попробуй сформулировать жанр ближе к известным («научпоп о квантовой физике с кулинарными примерами»).

### 5.5. Privacy evolver — точно ли мой текст не утекает?

**Известное ограничение 0.1.0 — `B-14-02`:** 4 privacy-теста evolver'а прогонялись только на пустых запретных папках до релиза. На реальной книге с непустыми `sections/`, `inputs/`, `intel/`, `agent-memory/` теоретически возможны неучтённые случаи.

Workaround на 0.1: если работаешь с конфиденциальной темой, поставь в `config.yaml`:

```yaml
privacy:
  private: true
  include_in_evolver: false
```

Это **полностью** исключит книгу из любого анализа `/bookbench:evolve` — структурная гарантия на уровне фильтрации registry, не на уровне tools.

Подробности по архитектуре приватности — в [`dev-mode.md`](dev-mode.md), раздел «Privacy».

### 5.6. Микро-цикл главы прервался посередине

Координатор сохраняет состояние в `sections/<N>/section-state.yaml`. Восстановление:

```
> /bookbench:resume
🤖 [book-coordinator] Восстанавливаю состояние:
   ├─ section: 7
   ├─ phase: factcheck (loop iteration 2)
   └─ Продолжаю с итерации 3 фактчекера.
```

Если `/bookbench:resume` не помогает — `/bookbench:debug <slug>` открывает persistent debug-сессию. Подробности по recovery — в [`section-cycle.md`](section-cycle.md), раздел «Recovery».

**Известное ограничение 0.1.0 — `B-14-01`:** микро-цикл не прогонялся на реальной главе автора до релиза (только simulation). Граничные случаи восстановления могут потребовать ручной правки `section-state.yaml`.

### 5.7. Hook на реальном тексте даёт false positives

**Известное ограничение 0.1.0 — `B-14-05`:** hook не настраивался на реальных текстах глав (только на синтетических тестах). Возможны ложные срабатывания на правомерных конструкциях.

Workaround: добавляй исключения в `agent-guidelines/writer/forbidden-phrases.md` → секция `# Allowed (overrides default block)`. Если 3+ false positives на одну тему — `/bookbench:tune` обобщит правило.

### 5.8. Где сообщить о баге или предложить фичу?

GitHub issues: `https://github.com/vefmvai/bookbench/issues`. Шаблон issue — в [`contributing.md`](contributing.md).

---

## Что дальше

- [`installation.md`](installation.md) — кластер 1 подробнее
- [`section-cycle.md`](section-cycle.md) — кластер 2 подробнее
- [`voice-management.md`](voice-management.md) — кластер 3 подробнее
- [`upgrade-guide.md`](upgrade-guide.md) — кластер 4 подробнее
- [`contributing.md`](contributing.md) — как сообщить о баге или предложить фичу
