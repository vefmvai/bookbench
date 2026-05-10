# Установка

> Полный гайд по установке BookBench: предусловия, три режима, что инициализируется на первом запуске, перенос между машинами, удаление и переустановка.

---

## Содержание

1. [Предусловия](#предусловия)
2. [Три режима установки](#три-режима-установки)
3. [Обновление плагина](#обновление-плагина)
4. [Что инициализируется на первом запуске](#что-инициализируется-на-первом-запуске)
5. [После установки — два стартовых сценария](#после-установки--два-стартовых-сценария)
6. [Перенос между машинами](#перенос-между-машинами)
7. [Удаление и переустановка](#удаление-и-переустановка)
8. [Совместимость](#совместимость)

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
- Команда `/bookbench:evolve` **скрыта** из `/bookbench:help`.
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
- Команда `/bookbench:evolve` (propose / apply / status) **видна и доступна** — это меж-книжный анализ паттернов, который пишет diff в код плагина с git-коммитом. Подробности — в [`dev-mode.md`](dev-mode.md).
- Изменения в `${CLAUDE_PLUGIN_ROOT}` сразу подхватываются (этот путь — символическая ссылка или прямой путь к чекауту, в зависимости от платформы).
- Гарантии приватности evolver сохраняются: `/bookbench:evolve` **не читает текст глав**, только мета-файлы (`TUNING-LOG.md`, `REJECTIONS-LOG.md`, гайдлайны, конфиг).

### Режим 3. Marketplace (с 0.3.1, рекомендованный)

Это самый простой путь. Команды отличаются для двух сред — **CLI** и **VSCode-расширения**, потому что VSCode не поддерживает интерактивные `/plugin`-команды.

#### Если ты в Claude Code CLI (терминал)

```bash
> /plugin marketplace add vefmvai/bookbench
> /plugin install bookbench@bookbench
> /reload-plugins
```

После последнего reload в строке статуса должно появиться `1 plugin · 51 skills · …`. Проверь, что команды видны: набери `/bookbench:` — должно открыться автодополнение с ~30 командами (`start`, `write-section`, `plan-section`, `doctor` и т.д.).

#### Если ты в VSCode (расширение Claude Code)

Расширение не понимает интерактивные `/plugin`-команды (на их вызов отвечает «isn't available in this environment»). Вместо этого добавь две записи в `~/.claude/settings.json` (создать файл, если его нет):

```json
{
  "extraKnownMarketplaces": {
    "bookbench": {
      "source": {
        "source": "github",
        "repo": "vefmvai/bookbench"
      }
    }
  },
  "enabledPlugins": {
    "bookbench@bookbench": true
  }
}
```

Затем перезагрузи окно VSCode: **Cmd+Shift+P → «Developer: Reload Window»**. После перезагрузки расширение само склонирует marketplace и установит плагин. Команды `/bookbench:*` появятся в автодополнении.

> **Альтернатива для VSCode-пользователей:** установить плагин один раз через CLI (команды выше), а затем VSCode подхватит его автоматически — реестр установленных плагинов общий (`~/.claude/plugins/installed_plugins.json`). После первой установки в CLI достаточно перезагрузить окно VSCode (Reload Window).

#### Если установка не подхватила команды (диагностика)

Если после reload показывает `0 skills · 0 hooks` или `/bookbench:`-автодополнение пустое — это означает, что Claude Code применил пустой sparse-checkout к кэшу плагина. Симптом: в `~/.claude/plugins/cache/bookbench/bookbench/<sha>/` лежат только `README.md`, `LICENSE`, `CHANGELOG.md` без `commands/`, `skills/`, `manifest.json`.

Чистый фикс — снести кэш и поставить заново:

```bash
# 1. Закрой Claude Code (CLI и VSCode)
# 2. Снеси кэш плагина
rm -rf ~/.claude/plugins/cache/bookbench
# 3. Снеси указатель в реестре установленных плагинов
# (отредактируй ~/.claude/plugins/installed_plugins.json — удали запись про bookbench@bookbench
#  или сотри файл целиком, реестр восстановится при следующем install)
# 4. Открой Claude Code заново и поставь по инструкции выше
```

> **Пользователям 0.2.x и старше — обязательно полная переустановка.** Старые версии 0.2.x и 0.3.0 имели сломанный `git-subdir`-источник (Claude Code 2.1.x не разворачивал sparse-checkout до подпапки плагина). С 0.3.1 источник переведён на относительный путь `./plugins/bookbench`, как у официальных Anthropic-плагинов. Если у тебя в кэше остались поломанные сборки 0.2.x/0.3.0 — удали папку `~/.claude/plugins/cache/bookbench` целиком перед `install`. См. [`release-031-notes.md`](release-031-notes.md), раздел «Миграция».

---

## Обновление плагина

С версии **0.3.3** обновление плагина — одна команда вместо ~6 ручных bash-операций.

### Почему отдельная команда

Claude Code-расширение для VSCode **не умеет автоматически обновлять плагины** из github-marketplace. Локальный клон в `~/.claude/plugins/marketplaces/bookbench/` делается **один раз** при первой установке и потом игнорируется — `Reload Window` его не трогает. До 0.3.3 пользователю приходилось вручную: удалять кэш, править `installed_plugins.json`, делать `git pull` в клоне marketplace, перезагружать окно дважды. С 0.3.3 это закрывает команда **`/bookbench:upgrade`**.

> Команда **дополняет**, не заменяет существующую `/bookbench:update`. `/bookbench:update` переносит обновлённые тела субагентов **из плагина в книгу** (исходит из предположения «плагин уже свежий»). `/bookbench:upgrade` обновляет **сам плагин** — это шаг РАНЬШЕ.

### Стандартное обновление

```bash
# Внутри Claude Code (CLI или VSCode):
> /bookbench:upgrade
🤖 Backup создан: /Users/.../installed_plugins.json.backup-1778398123
🤖 Готово. 0.3.2 → 0.3.3 (sha 453c30d → abc1234).
🤖 Чтобы Claude Code увидел свежую версию плагина, перезагрузи окно:
🤖   CLI: /reload-plugins (если поддерживается)
🤖   VSCode: Cmd+Shift+P → Developer: Reload Window
```

После Reload Window: `/bookbench:doctor` покажет `version: 0.3.3`. Все правки реестра обратимы из бэкапа `installed_plugins.json.backup-<timestamp>` в `~/.claude/plugins/`.

**Гарантии безопасности:**
- ВСЕГДА создаётся бэкап `installed_plugins.json.backup-<unix-timestamp>` ДО любой записи.
- НЕ трогает другие плагины и другие marketplaces.
- НЕ делает `git reset --hard` (только `git pull --ff-only`, чтобы fail-fast при дивергенции).
- НЕ запускает Reload Window сам — это инструкция автору, потому что VSCode не предоставляет программный API для перезагрузки.

### Проверить, есть ли обновление, без правок

```bash
> /bookbench:upgrade --check
🤖 Текущая: 453c30d (v0.3.2) | Свежая: abc1234 (v0.3.3) | Доступно обновление: ДА
```

`--check` — read-only. Ни один файл не правится: `git status` в клоне marketplace остаётся `clean`, реестр не трогается, бэкап не создаётся.

### Перенести новые шаблоны в текущую книгу

После Reload Window в новой версии плагина могли появиться новые шаблоны `agent-guidelines/<role>/` или новые hook-скрипты. Если хочешь подтянуть их в **текущую** инициализированную книгу:

```bash
# Из папки книги (где есть .book/):
> /bookbench:upgrade --apply-templates
🤖 Backup folder: .book/.backup/upgrade-20260510T103000Z
🤖 === Class A: agent-guidelines (sacred policy D-41) ===
🤖 ── NEW: agent-guidelines/writer/addressing-rules.md ──
🤖 (показывает diff)
🤖 [AskUserQuestion: Добавить новый файл? / Пропустить / Показать полный diff]
🤖 ...
🤖 Готово. Backup: .book/.backup/upgrade-20260510T103000Z
```

**Sacred policy D-41 строго соблюдается:**
- Для каждого файла в `agent-guidelines/<role>/` — **обязательное подтверждение** (через `AskUserQuestion`).
- Файлы в `.book/context/<file>.md` со `status: confirmed` (например, `voice-profile.md`) **НЕ перезаписываются никогда** — даже с подтверждением.
- Перед каждой перезаписью — backup в `.book/.backup/upgrade-<timestamp>/`.
- Действие записывается в `.book/UPDATE-LOG.md`.

`--apply-templates` опционален — если ты не хочешь подтягивать новые шаблоны в существующую книгу, можно ничего не делать после `/bookbench:upgrade` (default), и книга продолжит работать с теми шаблонами, что были на момент `/bookbench:start`.

### Откат на предыдущую версию

Если новая версия принесла регрессию для твоего workflow:

```bash
> /bookbench:upgrade --from v0.3.2
🤖 Готово. 0.3.3 → 0.3.2 (sha abc1234 → 453c30d, ref=v0.3.2).
🤖 Чтобы Claude Code увидел свежую версию: Cmd+Shift+P → Developer: Reload Window.
```

`--from` принимает либо тег (`v0.3.2`), либо полный/короткий sha коммита. Клон marketplace остаётся в detached HEAD после `--from` — чтобы вернуться на `main`, повтори `/bookbench:upgrade` (без флагов).

### Если что-то пошло не так

| Симптом | Что делать |
|---|---|
| `Error: jq is required but not installed` | macOS: `brew install jq`. Linux: `apt-get install jq`. |
| `Error: marketplace clone not found at ~/.claude/plugins/marketplaces/bookbench` | Плагин не установлен через marketplace. См. раздел [Режим 3](#режим-3-marketplace-с-031-рекомендованный) выше. |
| `Error: registry has no entry for bookbench@bookbench` | Плагин не установлен. Прогон `/plugin install bookbench@bookbench`. |
| `Error: git pull --ff-only failed. Marketplace clone may have local divergence.` | Кто-то вручную правил клон. Восстанови: `cd ~/.claude/plugins/marketplaces/bookbench && git status` — посмотри что не то, и либо откати локальные правки (`git stash`), либо повтори `/bookbench:upgrade --from main`. |
| Реестр сломался после `/bookbench:upgrade` | Откатись из бэкапа: `cp ~/.claude/plugins/installed_plugins.json.backup-<TS> ~/.claude/plugins/installed_plugins.json` (выбери самый свежий бэкап по timestamp). |

---

## Что инициализируется на первом запуске

Плагин трогает три уровня данных. Подробности — в [`architecture.md`](architecture.md).

### Уровень 1. Код плагина (`${CLAUDE_PLUGIN_ROOT}`)

Создаётся при `/plugin install`. Стирается при `/plugin update`. Содержит:

- `manifest.json`, `.claude-plugin/plugin.json` — метаданные.
- `commands/` — 40+ файлов команд `/bookbench:*`.
- `agent-templates/` — 9 шаблонов тел субагентов (копируются в книгу при `/bookbench:start`).
- `skills/` — 10 скиллов (`base-methodology`, `anti-ai-cliche`, `voice-profile`, `voice-builder`, `factcheck-protocol`, `marketing-protocol`, `import-classification-protocol`, `import-synthesis-protocol`, `genre-researcher`, `genres/popular-science`).
- `defaults.yaml` — дефолты жанров.
- `templates/` — скелет папки книги, шаблоны гайдлайнов, hook-скрипт.
- `docs/`, `tests/` — документация и evaluation cases.

Никаких авторских данных здесь нет — это код, общий для всех пользователей плагина.

### Уровень 2. Данные плагина (`${CLAUDE_PLUGIN_DATA}`)

Создаётся при первом вызове любой `/bookbench:*` команды. **Переживает `/plugin update`** (официальный механизм Anthropic — гарантия неизменности данных). Содержит:

```
${CLAUDE_PLUGIN_DATA}/
├── installation.yaml     ← source (github / local-dev / marketplace) + путь
├── settings.yaml         ← глобальные настройки пользователя (default_genre,
│                            default_language)
├── registry.yaml         ← реестр всех зарегистрированных книг автора
├── scan-paths.yaml       ← пути для /bookbench:doctor (поиск осиротевших книг)
├── evolver/              ← история работы /bookbench:evolve (только в local-dev)
│   ├── analysis-history/
│   └── pending-changes/
└── cache/                ← кэшируемые данные (опционально)
```

Запись здесь — только при явных операциях:

- `/bookbench:start` → новая запись в `registry.yaml`.
- `/bookbench:archive`, `/bookbench:forget` → правка `registry.yaml`.
- `/bookbench:settings` → правка `settings.yaml`.
- `/bookbench:evolve propose|apply` → запись в `evolver/`.

### Уровень 3. Папка книги (`<my-book>/`)

Создаётся при `/bookbench:start`. **Никогда не трогается** ни `/plugin update`, ни `/bookbench:evolve`. Это территория автора.

```
my-book/
├── CLAUDE.md             ← инструкции для Claude в этой папке
└── .book/
    ├── PROJECT.md, ROADMAP.md, STATE.md
    ├── config.yaml, workflow.md
    ├── TUNING-LOG.md, REJECTIONS-LOG.md, UPDATE-LOG.md
    ├── context/           ← parameters, voice-profile, glossary, ...
    ├── agent-guidelines/  ← гайдлайны на 9 ролей (индивидуальность книги)
    ├── sections/          ← главы (spec, draft, factcheck, edited, marketing, summary)
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
> /bookbench:start
```

Команда задаёт первый вопрос — «У вас уже есть наброски / заметки / чаты?»:

- **Сценарий A — с чистого листа.** Ответ `n` → пять стандартных вопросов установочного интервью → развёртывание пустых реестров. Полный путь — в [`quickstart.md`](quickstart.md), раздел A.
- **Сценарий B — с существующих материалов.** Ответ `y` → запрос путей к материалам → запуск `/bookbench:import` → классификатор разбирает фрагменты → синтезатор собирает в структуру → реестры стартуют пополненными. Полный путь — в [`quickstart.md`](quickstart.md), раздел B.

В обоих сценариях после установки работает один и тот же микро-цикл главы; разница — в стартовом состоянии реестров и режиме `book-writer`.

> **Сквозное требование архитектуры.** Поддержка обоих сценариев — это не «удобная фича», а сквозное требование проекта (`PROJECT.md`). Все команды, гайдлайны и скиллы спроектированы так, чтобы корректно отрабатывать оба пути.

Также после установки доступна:

```
> /bookbench:list
🤖 Зарегистрировано книг: 0
```

— это покажет реестр всех твоих книг (читает `${CLAUDE_PLUGIN_DATA}/registry.yaml`). После первого `/bookbench:start` здесь появится запись.

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
2. Зарегистрируй книгу в реестре новой машины: `/bookbench:register ~/Documents/my-book` (нужно, потому что `${CLAUDE_PLUGIN_DATA}/registry.yaml` живёт на машине, а не в книге).
3. Проверь: `/bookbench:doctor` — должна найти книгу и подтвердить, что все 9 субагентов на месте.

### Что **не** копировать

- `${CLAUDE_PLUGIN_ROOT}` — устанавливается заново через `/plugin install`.
- `${CLAUDE_PLUGIN_DATA}` — `registry.yaml` пересобирается через `/bookbench:register` для каждой книги.
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

После этого можно установить заново через `/plugin install bookbench@<version>` — реестр книг (`registry.yaml`) подхватится, и `/bookbench:list` покажет все книги, как было до удаления.

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

Подумай дважды — `sections/` и `context/` не восстанавливаются.

### Переустановка после случайного `rm -rf`

Если удалил `.book/` случайно, но не плагин:

- В `${CLAUDE_PLUGIN_DATA}/registry.yaml` запись о книге останется (потому что папка плагина и папка книги — разные сущности).
- `/bookbench:doctor` обнаружит запись на отсутствующую папку и предложит `/bookbench:forget <book-id>` для очистки реестра.

Если есть бэкап в `.book/.backup/<timestamp>/` — восстанови его. Если нет — `/bookbench:start` развернёт пустую структуру заново.

---

## Совместимость

| Свойство | Значение |
|----------|----------|
| Claude Code | `^2.0` (см. `manifest.json`) |
| Подписки Claude | Pro / Max-5x / Max-20x / Team / API. Профиль моделей под подписку — в [`models-and-subscriptions.md`](models-and-subscriptions.md) |
| ОС | macOS, Linux, Windows (WSL) |
| Bash | 3.2+ (engine не использует ассоциативные массивы bash 4) |
| Языки книг | русский (приоритет 0.1); английский (anti-cliche корпус 34 паттерна готов); другие — нужны контрибуции в `skills/anti-ai-cliche/references/` |
| Жанры | научпоп — full support; остальные — on-demand через `/bookbench:research-genre <жанр>`, см. [`customization.md`](customization.md) |

---

## Что дальше

- [`quickstart.md`](quickstart.md) — сразу после установки: первые 30 минут с обоими сценариями
- [`architecture.md`](architecture.md) — что за каждая папка и стрелка
- [`upgrade-guide.md`](upgrade-guide.md) — `/plugin update` vs `/bookbench:update`, что не трогается
- [`dev-mode.md`](dev-mode.md) — local-dev режим, `/bookbench:evolve`
- [`faq.md`](faq.md) — кластер 1 «Установка и совместимость» (4 вопроса)
