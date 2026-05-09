# Установка

> Полный гайд по установке BookBench: предусловия, три режима, что инициализируется на первом запуске, перенос между машинами, удаление и переустановка.

---

## Содержание

1. [Предусловия](#предусловия)
2. [Три режима установки](#три-режима-установки)
3. [Что инициализируется на первом запуске](#что-инициализируется-на-первом-запуске)
4. [После установки — два стартовых сценария](#после-установки--два-стартовых-сценария)
5. [Перенос между машинами](#перенос-между-машинами)
6. [Удаление и переустановка](#удаление-и-переустановка)
7. [Совместимость](#совместимость)

---

## Предусловия

| Что | Минимум | Зачем |
|-----|---------|-------|
| **Claude Code** | `^2.0` | сервис команд, скиллов, субагентов, hooks. Версия фиксируется в `manifest.json` → `compatible_claude_code` |
| **Подписка Claude** | Pro / Max-5x / Max-20x / Team / API | пять субагентов на главу — без подписки потолок Opus выгорит за две главы. См. [`models-and-subscriptions.md`](models-and-subscriptions.md) |
| **bash 3.2+** | macOS / Linux нативно; Windows через WSL | для `anti-ai-cliche-lint.sh` и других hook-скриптов; engine построен на `perl-PCRE` без bash 4-фич, чтобы работать на дефолтном macOS bash 3.2 |
| **Git** (опционально) | любой | если хочешь версионировать книгу. Не обязательно — папка работает и без git |
| **MCP-серверы** | не обязательны | фактчекер по умолчанию использует встроенный WebSearch; MCP можно подключить опционально, см. ниже |

> **Можно ли без MCP?** Да. На 0.1 фактчекер использует `WebSearch` + `WebFetch` (встроенные tools Claude Code). MCP-серверы можно подключать опционально — например, MCP-Exa для academic search или MCP-PubMed для медицинской литературы. Конфигурация — в `.book/.claude/agents/book-factchecker.md` → секция `mcpServers`. См. также [`customization.md`](customization.md).

---

## Три режима установки

### Режим 1. GitHub release (рекомендуется большинству авторов)

Самый простой путь. Используется, если ты автор и пишешь книгу — не разрабатываешь сам плагин.

```bash
# Внутри Claude Code
> /plugin install bookbench@v0.2.0
🤖 Скачиваю bookbench@v0.1.0 с github.com/vefmvai/bookbench/releases/v0.1.0
🤖 Развёрнут в ${CLAUDE_PLUGIN_ROOT}
🤖 ${CLAUDE_PLUGIN_DATA} инициализирован: installation.yaml, settings.yaml, registry.yaml
✅ BookBench 0.2.0 установлен.
```

В этом режиме:

- `installation.yaml` записывает `source: github`.
- Команда `/book:evolve` **скрыта** из `/book:help`.
- `/plugin update bookbench` обновит плагин до новой релизной версии бесшовно.

### Режим 2. Local-dev (для контрибьюторов и для автора плагина)

Если ты разрабатываешь сам плагин или хочешь жить на bleeding edge — клонируй репо и установи из локального чекаута.

```bash
$ git clone https://github.com/vefmvai/bookbench
$ cd bookbench

# Внутри Claude Code
> /plugin install ./bookbench
🤖 Установлен из локального чекаута: /Users/.../bookbench
🤖 ${CLAUDE_PLUGIN_DATA} инициализирован.
🤖 source: local-dev — команды эволюции разблокированы.
✅ BookBench (local-dev) установлен.
```

В этом режиме:

- `installation.yaml` записывает `source: local-dev` (плюс абсолютный путь до чекаута).
- Команда `/book:evolve` (propose / apply / status) **видна и доступна** — это меж-книжный анализ паттернов, который пишет diff в код плагина с git-коммитом. Подробности — в [`dev-mode.md`](dev-mode.md).
- Изменения в `${CLAUDE_PLUGIN_ROOT}` сразу подхватываются (этот путь — символическая ссылка или прямой путь к чекауту, в зависимости от платформы).
- Гарантии приватности evolver сохраняются: `/book:evolve` **не читает текст глав**, только мета-файлы (`TUNING-LOG.md`, `REJECTIONS-LOG.md`, гайдлайны, конфиг).

### Режим 3. Marketplace (с 0.2.0)

Установка из Claude Code plugin marketplace:

```bash
# Внутри Claude Code
> /plugin marketplace add vefmvai/bookbench
> /plugin install bookbench@bookbench
> /reload-plugins
```

Это **рекомендованный путь начиная с 0.2.0**. До 0.2.0 marketplace-установка спотыкалась на sparse-checkout-фильтре Claude Code 2.1.x (плагин лежал в корне репо, и Claude Code не клонировал подпапки `commands/`, `skills/`, `agent-templates/`). В 0.2.0 структура репозитория переведена на каноническую — плагин теперь в подпапке `plugins/bookbench/`, и `git-subdir`-источник работает корректно.

> **Пользователям 0.1.x — обновитесь до 0.2.0.** В 0.1.x marketplace-установка работала только при ручном фиксе кэша. См. [`release-020-notes.md`](release-020-notes.md), раздел «Миграция».

---

## Что инициализируется на первом запуске

Плагин трогает три уровня данных. Подробности — в [`architecture.md`](architecture.md).

### Уровень 1. Код плагина (`${CLAUDE_PLUGIN_ROOT}`)

Создаётся при `/plugin install`. Стирается при `/plugin update`. Содержит:

- `manifest.json`, `.claude-plugin/plugin.json` — метаданные.
- `commands/` — 40+ файлов команд `/book:*`.
- `agent-templates/` — 9 шаблонов тел субагентов (копируются в книгу при `/book:start`).
- `skills/` — 10 скиллов (`base-methodology`, `anti-ai-cliche`, `voice-profile`, `voice-builder`, `factcheck-protocol`, `marketing-protocol`, `import-classification-protocol`, `import-synthesis-protocol`, `genre-researcher`, `genres/popular-science`).
- `defaults.yaml` — дефолты жанров.
- `templates/` — скелет папки книги, шаблоны гайдлайнов, hook-скрипт.
- `docs/`, `tests/` — документация и evaluation cases.

Никаких авторских данных здесь нет — это код, общий для всех пользователей плагина.

### Уровень 2. Данные плагина (`${CLAUDE_PLUGIN_DATA}`)

Создаётся при первом вызове любой `/book:*` команды. **Переживает `/plugin update`** (официальный механизм Anthropic — гарантия неизменности данных). Содержит:

```
${CLAUDE_PLUGIN_DATA}/
├── installation.yaml     ← source (github / local-dev / marketplace) + путь
├── settings.yaml         ← глобальные настройки пользователя (default_genre,
│                            default_language)
├── registry.yaml         ← реестр всех зарегистрированных книг автора
├── scan-paths.yaml       ← пути для /book:doctor (поиск осиротевших книг)
├── evolver/              ← история работы /book:evolve (только в local-dev)
│   ├── analysis-history/
│   └── pending-changes/
└── cache/                ← кэшируемые данные (опционально)
```

Запись здесь — только при явных операциях:

- `/book:start` → новая запись в `registry.yaml`.
- `/book:archive`, `/book:forget` → правка `registry.yaml`.
- `/book:settings` → правка `settings.yaml`.
- `/book:evolve propose|apply` → запись в `evolver/`.

### Уровень 3. Папка книги (`<my-book>/`)

Создаётся при `/book:start`. **Никогда не трогается** ни `/plugin update`, ни `/book:evolve`. Это территория автора.

```
my-book/
├── CLAUDE.md             ← инструкции для Claude в этой папке
└── .book/
    ├── PROJECT.md, ROADMAP.md, STATE.md
    ├── config.yaml, workflow.md
    ├── TUNING-LOG.md, REJECTIONS-LOG.md, UPDATE-LOG.md
    ├── context/           ← parameters, voice-profile, glossary, ...
    ├── agent-guidelines/  ← гайдлайны на 9 ролей (индивидуальность книги)
    ├── chapters/          ← главы (spec, draft, factcheck, edited, marketing, summary)
    ├── agent-memory/      ← реестры памяти 5 ролей цикла
    ├── intel/, debug/, inputs/, final/, .backup/
    ├── .claude/
    │   ├── settings.json
    │   ├── agents/        ← 9 локальных тел субагентов
    │   └── agent-memory/  ← реальные реестры (memory: project)
    └── .hooks/            ← anti-ai-cliche-lint.sh
```

---

## После установки — два стартовых сценария

После установки в любой директории:

```
> /book:start
```

Команда задаёт первый вопрос — «У вас уже есть наброски / заметки / чаты?»:

- **Сценарий A — с чистого листа.** Ответ `n` → пять стандартных вопросов установочного интервью → развёртывание пустых реестров. Полный путь — в [`quickstart.md`](quickstart.md), раздел A.
- **Сценарий B — с существующих материалов.** Ответ `y` → запрос путей к материалам → запуск `/book:import` → классификатор разбирает фрагменты → синтезатор собирает в структуру → реестры стартуют пополненными. Полный путь — в [`quickstart.md`](quickstart.md), раздел B.

В обоих сценариях после установки работает один и тот же микро-цикл главы; разница — в стартовом состоянии реестров и режиме `book-writer`.

> **Сквозное требование архитектуры.** Поддержка обоих сценариев — это не «удобная фича», а сквозное требование проекта (`PROJECT.md`). Все команды, гайдлайны и скиллы спроектированы так, чтобы корректно отрабатывать оба пути.

Также после установки доступна:

```
> /book:list
🤖 Зарегистрировано книг: 0
```

— это покажет реестр всех твоих книг (читает `${CLAUDE_PLUGIN_DATA}/registry.yaml`). После первого `/book:start` здесь появится запись.

---

## Перенос между машинами

### Что копировать

Всё, что нужно для продолжения работы над книгой на другой машине:

```
# 1. Папка книги (содержит весь контент и индивидуальность)
$ rsync -av my-book/ user@host:~/Documents/my-book/

# 2. Личная библиотека голосов (если есть и используешь между книгами)
$ rsync -av ~/.bookbench/voices/ user@host:~/.bookbench/voices/
```

После переноса на новой машине:

1. Установи плагин: `/plugin install bookbench@v0.2.0` (или local-dev).
2. Зарегистрируй книгу в реестре новой машины: `/book:register ~/Documents/my-book` (нужно, потому что `${CLAUDE_PLUGIN_DATA}/registry.yaml` живёт на машине, а не в книге).
3. Проверь: `/book:doctor` — должна найти книгу и подтвердить, что все 9 субагентов на месте.

### Что **не** копировать

- `${CLAUDE_PLUGIN_ROOT}` — устанавливается заново через `/plugin install`.
- `${CLAUDE_PLUGIN_DATA}` — `registry.yaml` пересобирается через `/book:register` для каждой книги.
- `installation.yaml` — пишется при установке плагина на новой машине.

> **Голосовая библиотека `~/.bookbench/voices/`** живёт **вне** плагина и **вне** папки книги — именно для того, чтобы переносилась независимо. Это per-машинное, per-авторское пространство; не часть git-репозитория книги (если ты её коммитишь). См. [`voice-management.md`](voice-management.md).

---

## Удаление и переустановка

### Удалить плагин (но сохранить данные)

```
> /plugin uninstall bookbench --keep-data
🤖 Удаляю ${CLAUDE_PLUGIN_ROOT}...
🤖 ${CLAUDE_PLUGIN_DATA} сохраняю (флаг --keep-data).
✅ BookBench удалён. Все папки книг (.book/) и голосовая библиотека остаются.
```

После этого можно установить заново через `/plugin install bookbench@<version>` — реестр книг (`registry.yaml`) подхватится, и `/book:list` покажет все книги, как было до удаления.

### Удалить плагин полностью (включая реестр)

```
> /plugin uninstall bookbench
🤖 Удаляю ${CLAUDE_PLUGIN_ROOT}...
🤖 Удалить ${CLAUDE_PLUGIN_DATA}? (y/n)
📝 y
✅ BookBench удалён вместе с данными.
```

Папки книг (`.book/`) **остаются нетронутыми** в любом случае — это территория автора, гарантия архитектуры (см. [`architecture.md`](architecture.md), стрелка #14).

### Полностью удалить и книгу

Это уже не команда плагина, а ручное действие:

```bash
$ rm -rf my-book/
```

Подумай дважды — `chapters/` и `context/` не восстанавливаются.

### Переустановка после случайного `rm -rf`

Если удалил `.book/` случайно, но не плагин:

- В `${CLAUDE_PLUGIN_DATA}/registry.yaml` запись о книге останется (потому что папка плагина и папка книги — разные сущности).
- `/book:doctor` обнаружит запись на отсутствующую папку и предложит `/book:forget <book-id>` для очистки реестра.

Если есть бэкап в `.book/.backup/<timestamp>/` — восстанови его. Если нет — `/book:start` развернёт пустую структуру заново.

---

## Совместимость

| Свойство | Значение |
|----------|----------|
| Claude Code | `^2.0` (см. `manifest.json`) |
| Подписки Claude | Pro / Max-5x / Max-20x / Team / API. Профиль моделей под подписку — в [`models-and-subscriptions.md`](models-and-subscriptions.md) |
| ОС | macOS, Linux, Windows (WSL) |
| Bash | 3.2+ (engine не использует ассоциативные массивы bash 4) |
| Языки книг | русский (приоритет 0.1); английский (anti-cliche корпус 34 паттерна готов); другие — нужны контрибуции в `skills/anti-ai-cliche/references/` |
| Жанры | научпоп — full support; остальные — on-demand через `/book:research-genre <жанр>`, см. [`customization.md`](customization.md) |

---

## Что дальше

- [`quickstart.md`](quickstart.md) — сразу после установки: первые 30 минут с обоими сценариями
- [`architecture.md`](architecture.md) — что за каждая папка и стрелка
- [`upgrade-guide.md`](upgrade-guide.md) — `/plugin update` vs `/book:update`, что не трогается
- [`dev-mode.md`](dev-mode.md) — local-dev режим, `/book:evolve`
- [`faq.md`](faq.md) — кластер 1 «Установка и совместимость» (4 вопроса)
