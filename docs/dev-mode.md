# Local-dev режим и эволюция плагина

> Local-dev — режим установки плагина из локального чекаута для контрибьюторов и для maintainer'ов фреймворка. Разблокирует команду `/bookbench:evolve` — меж-книжный анализ паттернов с гарантиями приватности.

---

## Содержание

1. [Что такое local-dev](#что-такое-local-dev)
2. [Как установить в local-dev](#как-установить-в-local-dev)
3. [Дополнительные команды](#дополнительные-команды)
4. [Workflow эволюции плагина](#workflow-эволюции-плагина)
5. [Приватность evolver — структурные гарантии](#приватность-evolver--структурные-гарантии)

---

## Что такое local-dev

Local-dev — это режим установки плагина, при котором `${CLAUDE_PLUGIN_ROOT}` указывает на твой локальный чекаут репозитория, а не на скачанный с GitHub release. Используется в двух случаях:

1. **Ты разрабатываешь сам плагин** — пишешь PR, тестируешь изменения на синтетических книгах.
2. **Ты maintainer фреймворка с несколькими собственными книгами** — хочешь анализировать паттерны замечаний между ними и подтягивать улучшения в код плагина.

В обоих случаях `installation.yaml` пишет `source: local-dev`, и фреймворк разблокирует:

- Команду `/bookbench:evolve [propose|apply|status]` — меж-книжный анализ.
- Команду `/bookbench:update --from-local-dev <path>` — обновление книги из конкретного локального чекаута (полезно при тестировании).

Эти команды **не видны** в режимах GitHub release и Marketplace. Это структурная гарантия: конечный пользователь не может случайно сделать коммит в код плагина из своей сессии.

---

## Как установить в local-dev

```bash
# 1. Клонируй репозиторий
$ git clone https://github.com/vefmvai/bookbench
$ cd bookbench

# 2. Установи из локального чекаута внутри Claude Code
> /plugin install ./bookbench
🤖 Установлен из локального чекаута: /Users/.../bookbench
🤖 ${CLAUDE_PLUGIN_DATA} инициализирован.
🤖 source: local-dev — команды эволюции разблокированы.
✅ BookBench (local-dev) установлен.

# 3. Проверь
> /bookbench:doctor
🤖 BookBench (local-dev) — диагностика
   ├─ Source: /Users/.../bookbench (local-dev)
   ├─ /bookbench:evolve: visible (разблокирована)
   └─ ...
```

После этого:

- Изменения в `${CLAUDE_PLUGIN_ROOT}` (твой чекаут) сразу подхватываются.
- Файл `${CLAUDE_PLUGIN_DATA}/installation.yaml` содержит:

```yaml
source: local-dev
path: /Users/your-name/dev/bookbench
installed_at: 2026-05-08T14:32:11Z
```

### Переключение между local-dev и release

Если ты установлен в local-dev, но хочешь перейти на стабильный GitHub release (например, чтобы протестировать релизный путь):

```
> /plugin uninstall bookbench --keep-data
> /plugin install bookbench@v0.1.0
```

`--keep-data` сохранит `registry.yaml` (реестр книг), `settings.yaml` и `evolver/` (если есть история анализа). Ничего не теряется.

И обратно — из release в local-dev:

```
> /plugin uninstall bookbench --keep-data
> /plugin install ./bookbench
```

---

## Дополнительные команды

### `/bookbench:evolve propose`

Анализ паттернов в **зарегистрированных книгах** автора. Читает только мета-файлы каждой книги (см. раздел приватности ниже), ищет систематические паттерны (≥3 повторений в одной книге; ≥2 книги — для меж-книжного паттерна).

```
> /bookbench:evolve propose
🤖 [bookbench-evolver] Анализирую зарегистрированные книги...
   ├─ Книга «История кофе» (registered 2026-04-10): 16 TUNING-LOG записей, 8 REJECTIONS
   ├─ Книга «Биография учёного XIX в.» (registered 2026-03-05): 23 / 12
   └─ Книга «Архитектура римских акведуков» (registered 2026-02-15): 9 / 4

   Меж-книжных паттернов найдено: 2

   PATTERN 1 (priority: critical, occurs in 3/3 books):
   Все три писателя 7-12 раз правились на «вступительные обороты с обращением
   к читателю». Текущий agent-templates/book-writer.md → secondary memory не
   содержит явного запрета на этот паттерн.

   Предлагаемая правка кода плагина:
   файл: agent-templates/book-writer.md
   diff:
   + secondary_memory.constitution:
   +   - "NEVER start a section with direct reader address ('Dear reader',
   +      'Imagine yourself', 'Have you ever wondered'). Start with scene,
   +      fact, or quote."

   PATTERN 2 (priority: optional, occurs in 2/3 books):
   ...

   Записал в ${CLAUDE_PLUGIN_DATA}/evolver/pending-changes/2026-05-08-1645/
✅ /bookbench:evolve propose завершён. Используй /bookbench:evolve apply <id> для применения.
```

Ничего не пишется в код плагина без явного `apply`.

### `/bookbench:evolve apply <pending-id>`

Применение предложенной правки. Делает:

1. Записывает diff в `${CLAUDE_PLUGIN_ROOT}/...` (твой чекаут).
2. Создаёт git commit в чекауте: `git commit -m "evolve: apply <pattern-id> from <book-list>"`.
3. Архивирует в `${CLAUDE_PLUGIN_DATA}/evolver/analysis-history/`.

```
> /bookbench:evolve apply 2026-05-08-1645
✋ Применить PATTERN 1 (правка agent-templates/book-writer.md)?
   Diff:
   [...]
   (a) применить
   (b) пропустить (оставить в pending)
   (c) отвергнуть (пометить как not-applicable)
📝 a
🤖 ✅ Записал в /Users/.../bookbench/plugins/bookbench/agent-templates/book-writer.md
🤖 ✅ git commit: evolve: apply pattern-1 from coffee/scientist-bio/aqueducts
🤖 ✅ Архивирован в analysis-history/2026-05-08-1645/.
```

Дальше — обычный maintainer-flow: тестирование на синтетической книге, PR в основной репозиторий, релиз 0.1.x.

### `/bookbench:evolve status`

Текущее состояние:

```
> /bookbench:evolve status
🤖 Pending changes: 2
   ├─ 2026-05-08-1645 (PATTERN 1, critical, 3 books, awaiting apply)
   └─ 2026-05-07-2210 (PATTERN 2, optional, 2 books, awaiting apply)

   Applied this session: 0
   Total applied (history): 7
```

### `/bookbench:update --from-local-dev <path>`

Обновление папки книги из конкретного локального чекаута. Полезно при тестировании: ты сделал правку в `agent-templates/book-writer.md`, и хочешь увидеть её в твоей синтетической книге **без** релиза.

```
> /bookbench:update --from-local-dev /Users/.../bookbench
🤖 [book-coordinator] 3-way merge с чекаутом /Users/.../bookbench
   ├─ .book/.claude/agents/book-writer.md — изменён, предлагаю обновить
   ├─ .book/.hooks/anti-ai-cliche-lint.sh — без изменений
   └─ ...
```

Подробности по `/bookbench:update` — в [`upgrade-guide.md`](upgrade-guide.md).

---

## Workflow эволюции плагина

Полный цикл превращения наблюдений в работе с книгой в улучшения кода плагина:

### Шаг 1. Автор пишет книги, копит замечания

В каждой книге:

- `TUNING-LOG.md` — все правки гайдлайнов и конфига (через `/bookbench:tune apply`, через `/bookbench:guidelines`, через ручные правки).
- `REJECTIONS-LOG.md` — все случаи, когда автор после `/bookbench:write-section` правил готовую главу руками.

Это происходит автоматически по ходу работы.

### Шаг 2. После 3+ книг — `/bookbench:evolve propose`

Maintainer (в local-dev) запускает анализ. Evolver читает только мета-файлы из всех зарегистрированных книг, агрегирует паттерны, предлагает правки в код плагина.

### Шаг 3. Maintainer рецензирует pending-changes

Открывает `${CLAUDE_PLUGIN_DATA}/evolver/pending-changes/<id>/`, читает diff, решает: применить, пропустить, отвергнуть.

### Шаг 4. `/bookbench:evolve apply <id>` — запись в код плагина

Команда пишет diff в `${CLAUDE_PLUGIN_ROOT}` и делает git commit в чекауте.

### Шаг 5. Тестирование

На синтетической книге (или на одной из реальных книг maintainer'а) — `/bookbench:write-section` с обновлённым телом субагента. Если работает корректно — продолжаем.

### Шаг 6. PR в основной репозиторий

Из ветки чекаута — стандартный PR-процесс (см. [`contributing.md`](contributing.md)).

### Шаг 7. Релиз 0.1.x

Maintainer'ы фреймворка собирают накопленные правки в минорный релиз. Авторы книг получают улучшения через `/plugin update bookbench` (но папки книг не трогаются — `WF-04`; для подтягивания обновлений тел субагентов в существующую книгу — `/bookbench:update`).

---

## Приватность evolver — структурные гарантии

Это **критически важный** раздел. Evolver работает между книгами; гарантии приватности — структурные, не «обещанные».

### Что evolver НЕ читает (никогда)

- `sections/<N>/spec.md`, `draft.md`, `factcheck.md`, `edited.md`, `marketing.md`, `summary.md`.
- `inputs/` (исходные материалы автора).
- `intel/classifications/` (результат импорта).
- `debug/` (debug-сессии автора).
- `agent-memory/<role>/MEMORY.md` (содержимое реестров уникальности).

Это запрещённые пути на уровне `disallowedTools` в системном промпте `bookbench-evolver`. Структурная гарантия: даже если evolver «захочет» прочитать эти файлы, инструмент `Read` для них не разрешён.

### Что evolver читает

- `${CLAUDE_PLUGIN_DATA}/registry.yaml` — список зарегистрированных книг.
- В каждой книге, разрешённые пути:
  - `TUNING-LOG.md` — лог правок гайдлайнов.
  - `REJECTIONS-LOG.md` — лог отвержений (метаданные: какая глава, какая фаза, какой паттерн; **не содержит** текст главы).
  - `agent-guidelines/<role>/` — гайдлайны (это правила, не контент).
  - `config.yaml` — параметры.
  - `workflow.md` — workflow.

### Флаги opt-out

В `.book/config.yaml` каждой книги:

```yaml
privacy:
  include_in_evolver: true   # default
  private: false              # default
```

- `include_in_evolver: false` — книга **не участвует** в анализе, evolver её игнорирует.
- `private: true` — книга **полностью невидима** для evolver (опт-аут на уровне registry).

Эти флаги — структурные: `bookbench-evolver` фильтрует registry до начала любых операций. Книги с `private: true` или `include_in_evolver: false` отсутствуют в самой выборке, не маскируются ex post.

### 4 privacy-теста

В `bookbench/tests/eval-cases/commands/evolve/`:

- `privacy-test-01.md` — evolver не читает `sections/`.
- `privacy-test-02.md` — evolver не читает `inputs/`.
- `privacy-test-03.md` — evolver не читает `intel/`, `debug/`.
- `privacy-test-04.md` — evolver не читает `agent-memory/<role>/MEMORY.md`.

Каждый тест проверяет, что попытка чтения возвращает ошибку tool permissions. На 0.1 тесты прогонялись на пустых запретных папках (известное ограничение `B-14-02` в [`faq.md`](faq.md)) — на этапе 17 (подготовка к публикации) тесты пройдут на непустых, и фикс при необходимости попадёт в 0.1.x.

### Что записывает evolver

В `${CLAUDE_PLUGIN_DATA}/evolver/analysis-history/<timestamp>/`:

- `summary.md` — найденные паттерны (только агрегированные паттерны, без содержимого глав).
- `proposed-changes.diff` — предложенный diff в код плагина.
- `source-books.yaml` — список книг, которые участвовали в анализе.

В `${CLAUDE_PLUGIN_DATA}/evolver/pending-changes/<timestamp>/`:

- Та же структура, но pending до явного `apply` или `reject`.

В содержимом analysis-history и pending-changes **никогда не появляется**:

- Текст главы.
- Voice profile или voice samples (есть в гайдлайнах, но evolver не читает их в смысле, в котором их можно бы было раскрыть в diff'е).
- Имена реальных людей, мест, событий из книг автора.

---

## Что дальше

- [`contributing.md`](contributing.md) — как контрибьютить, требования к стилю и SKILL.md
- [`upgrade-guide.md`](upgrade-guide.md) — `/bookbench:update` и его связь с local-dev
- [`architecture.md`](architecture.md) — где живёт `${CLAUDE_PLUGIN_DATA}/evolver/` в общей картине
- [`customization.md`](customization.md) — `/bookbench:tune` (внутрикнижный аналог `/bookbench:evolve`)
