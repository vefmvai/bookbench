# Changelog

Все значимые изменения в BookBench записываются здесь.

Формат — [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Версионирование — [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_n/a — все изменения текущего цикла вошли в 0.2.0._

---

## [0.2.0] — 2026-05-09

Major релиз. Структурный рефакторинг репозитория под канонічную структуру Claude Code marketplace. Без содержательных правок в коде команд, скиллов или агентов — только перестановка файлов, обновление `marketplace.json` и фикс относительных путей в инфраструктуре тестов.

### Changed

- **Плагин перенесён из корня репозитория в подпапку `plugins/bookbench/`.** Все исполняемые папки плагина (`commands/`, `skills/`, `agent-templates/`, `lib/`, `templates/`) и его манифесты (`.claude-plugin/plugin.json`, `manifest.json`, `defaults.yaml`, `blocks-catalog.md`) переехали в `plugins/bookbench/`. В корне репозитория остались только проектные файлы: `README.md`, `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, внешняя документация (`docs/`), инфраструктура тестов (`tests/`), а также сам маркетплейс-манифест (`.claude-plugin/marketplace.json`).
- **`marketplace.json` теперь использует `git-subdir` с `path: "plugins/bookbench"`** вместо `source: "url"` с полным клоном коррня репо. Версия маркетплейса (`metadata.version`) поднята до 0.2.0.
- **Версии в `plugin.json`, `manifest.json` и `marketplace.json` подняты до 0.2.0.**
- **`tests/audit-public-cleanliness.sh`:** дефолтный target обновлён с `bookbench/` на `plugins/bookbench/`.
- **`tests/voice-commands-privacy.test.sh`:** путь к каталогу команд обновлён на `../plugins/bookbench/commands` (тест проходит — 18/18 PASS).
- **Документация (`README.md`, `docs/installation.md`, `docs/quickstart.md`, `docs/architecture.md`, `docs/contributing.md`, `docs/faq.md`, `docs/dev-mode.md`):** примеры команд установки переписаны под `/plugin marketplace add vefmvai/bookbench` + `/plugin install bookbench@bookbench`; пути к файлам плагина обновлены на `plugins/bookbench/...` где это релевантно (внутри установленного плагина — по-прежнему `commands/`, `skills/`, `${CLAUDE_PLUGIN_ROOT}` указывает на `plugins/bookbench/`).

### Fixed

- **Sparse-checkout проблема устранена.** В 0.1.x при `/plugin install bookbench@bookbench` Claude Code 2.1.x применял к плагину фильтр `/*` + `!/*/` (только корневые файлы, без подпапок) и не клонировал в кэш `commands/`, `skills/`, `agent-templates/` и `lib/` — без них команды `/book:*` не появлялись. Структура `plugins/<name>/` каноническая для Claude Code marketplace, sparse-checkout срабатывает корректно (выкачивается именно подпапка плагина целиком).

### Migration (для пользователей 0.1.x)

```
/plugin uninstall bookbench@bookbench
/plugin marketplace update bookbench   # либо: remove bookbench + add vefmvai/bookbench
/plugin install bookbench@bookbench
/reload-plugins
```

### Known issues

- **35 редких команд всё ещё имеют английские описания** (наследие 0.1.5). Перевод запланирован на 0.2.1.
- **Префикс `/book:` против `/bookbench:`** — если в 0.1.5 не сработал, в 0.2.0 при `git-subdir`-источнике поведение Claude Code может измениться (теперь корректнее читается `plugin.json` целиком). Проверка эмпирическая — после релиза.

---

## [0.1.5] — 2026-05-09

Patch-релиз «Общая уборка». Пост-релизный hot-fix UX: после 0.1.4 плагин технически устанавливался корректно, но в автодополнении `/bookbench:*` всплывали eval-кейсы (тесты, не пользовательские команды), а описания всех 50 команд, 11 SKILL.md и 9 агентов оставались на английском, что противоречит D-23 «только русский в документации».

### Changed

- **Eval-кейсы переехали из `commands/` и `skills/` в `tests/eval-cases/`.** Перенесены: `commands/analyze-session.eval/` → `tests/eval-cases/commands/analyze-session/` (3 кейса), `commands/evolve.eval/` → `tests/eval-cases/commands/evolve/` (4 privacy-теста), `skills/voice-builder/voice-builder.eval/` → `tests/eval-cases/skills/voice-builder/` (4 кейса). Теперь Claude Code не подтягивает их как пользовательские команды — автодополнение `/bookbench:*` показывает только реальные команды. Внутренние ссылки в `commands/evolve.md`, `skills/voice-builder/SKILL.md`, `skills/voice-builder/quality-gate.md`, `docs/dev-mode.md` и `docs/contributing.md` обновлены на новые пути. Папки `agent-templates/<role>.eval/` оставлены на месте — они не сканируются Claude Code как команды.
- **35 описаний (`description:` в frontmatter) переведены с английского на русский** — точечная работа над топ-приоритетом, остальные 35 редких команд остаются на английском как «известный хвост» для 0.1.6/0.2:
  - 15 команд: `start`, `write-chapter`, `plan-book`, `plan-chapter`, `discuss-chapter`, `status`, `next`, `help`, `voice-build`, `voice-extract`, `voice-list`, `audit-chapter`, `audit-book`, `re-edit-chapter`, `import`.
  - 11 `SKILL.md`: `anti-ai-cliche`, `base-methodology`, `factcheck-protocol`, `genre-researcher`, `genres/.template`, `genres/popular-science` (был уже на русском), `import-classification-protocol`, `import-synthesis-protocol`, `marketing-protocol`, `voice-builder`, `voice-profile`.
  - 9 агентов: `book-coordinator`, `book-doc-classifier`, `book-doc-synthesizer`, `book-editor`, `book-factchecker`, `book-marketer`, `book-observer`, `book-strategist`, `book-tuner`, `book-writer`. Двойные копии в `templates/claude-config/agents/` синхронизированы (соблюдение A-14.1-01).
- **Терминология глоссария зафиксирована.** Принят единый глоссарий перевода: chapter→глава, draft→драфт, voice profile→профиль голоса, factcheck→факт-чекинг, workflow→воркфлоу, registry→реестр, audit→аудит, tune→тюнинг, eval→eval-кейс, subagent→субагент. Имена агентов (`book-writer`, `book-strategist` и т.д.), пути файлов, параметры команд, имена скиллов — не переводятся, остаются машинно-читаемыми.

### Fixed

- **Поле `slash_prefix` перенесено в `.claude-plugin/plugin.json`** — оно уже было в `manifest.json`, но Claude Code 2.1.x его, по-видимому, оттуда не читал и формировал слаш-префикс из `name` (отсюда `/bookbench:*` вместо желаемого `/book:*`). Теперь дублируется в стандартный `.claude-plugin/plugin.json`. Эффект на автодополнение проверяется автором после обновления плагина.

### Known issues

- **35 редких команд остаются с английскими описаниями** — `archive`, `register`, `forget`, `evolve`, `tune`, `tune-guidelines`, `tune-workflow`, `workflow-add-block`, `workflow-check`, `workflow-edit`, `workflow-move-block`, `workflow-remove-block`, `research-external`, `research-genre`, `research-internal`, `voice-save-as`, `voice-import`, `extract-learnings`, `ship`, `resolve`, `resume`, `run`, `settings`, `update`, `debug`, `doctor`, `config`, `guidelines`, `contribute-genre`, `list`, `analyze-session`, `write-chapter:draft`, `write-chapter:edit`, `write-chapter:factcheck`, `write-chapter:market`. Перевод запланирован на 0.1.6 или 0.2.
- **Префикс `/book:` против `/bookbench:`** — если перенос `slash_prefix` в `.claude-plugin/plugin.json` не сработает (Claude Code 2.1.x может игнорировать поле или брать имя из `name`), это известное ограничение остаётся до 0.2 без насилия над конфигом.

---

## [0.1.4] — 2026-05-09

Hot-fix №3 — главный фикс установки. В версиях 0.1.1–0.1.3 при `/plugin install` плагин «устанавливался успешно», но Claude Code применял к нему sparse-checkout фильтр (`/*` + `!/*/`) и **отбрасывал ВСЕ подпапки** — `commands/`, `skills/`, `agent-templates/`, `lib/`, `.claude-plugin/` и т.д. В кэше `~/.claude/plugins/cache/bookbench/.../<sha>/` оставались только корневые `.md`-файлы и `manifest.json` — и поэтому ни одна команда `/book:*` не появлялась после `/plugin install`.

### Fixed

- **`marketplace.json` поле `source.source`** — было `"git-subdir"` с `path: "."` (Claude Code понял это как «склонировать sparse, без подпапок»). Стало `"url"` с `url: "https://github.com/vefmvai/bookbench.git"` и `sha: "<commit>"` — это формат, который у Anthropic в их официальном маркетплейсе используют **все 82 url-плагина**. Полный клон коммита, без sparse-checkout.

### Технические детали отладки

При диагностике обнаружено:
- 168 плагинов в `claude-plugins-official` используют 4 типа `source`: `git-subdir` (35), `url` (82), `string-shorthand` (49), `github` (2).
- Из них **ни один git-subdir-плагин не использует `path: "."`** — все указывают подпапку. Это значит, `git-subdir` рассчитан на монорепы маркетплейсов с несколькими плагинами в одном репо, а не на отдельные плагины-репо.
- Для плагина, который **сам себе репозиторий** (как `bookbench`), правильный тип — `url` с обязательным `sha` (закрепление за конкретным коммитом).
- Все 82 url-плагина у Anthropic имеют `sha` — это безопасностно-обязательное поле.

---

## [0.1.3] — 2026-05-09

Hot-fix №2. В 0.1.2 поле `source` было типа `"github"` — Claude Code 2.1.128 такой тип не принимает («This plugin uses a source type your Claude Code version does not support»). Заменено на универсальный `"git-subdir"` с `path: "."`.

### Fixed

- **`marketplace.json` поле `source.source`** — было `"github"` (не поддерживается в 2.1.128), стало `"git-subdir"` с явным `url` (полный HTTPS) и `path: "."` (плагин лежит в корне репозитория, а не в подпапке). Это рабочий формат, использующийся официальным маркетплейсом Anthropic для всех плагинов.

---

## [0.1.2] — 2026-05-09

Hot-fix. Исправляет формат `source` в `marketplace.json`, без которого `/plugin install` падал с ошибкой «This plugin uses a source type your Claude Code version does not support».

### Fixed

- **`marketplace.json` поле `source`** — было `"source": "."` (плоская строка, Claude Code 2.1.x не понимает), стало объект `{"source": "github", "repo": "vefmvai/bookbench"}` (стандарт по `https://anthropic.com/claude-code/marketplace.schema.json`).

### Changed

- Добавлен `$schema` в `marketplace.json` (соответствие официальному JSON-schema Anthropic).
- Добавлено поле `author` в описание плагина.

---

## [0.1.1] — 2026-05-09

Patch-релиз. Делает плагин устанавливаемым через стандартную команду `/plugin install` без ручного клонирования репозитория.

### Added

- **`.claude-plugin/marketplace.json`** — манифест маркетплейса. Превращает репозиторий `vefmvai/bookbench` в полноценный Claude Code marketplace: после `/plugin marketplace add vefmvai/bookbench` плагин становится доступен через `/plugin install bookbench@bookbench`.

### Fixed

- Установка через `/plugin install` теперь работает (в 0.1.0 отсутствовал `marketplace.json`, и команда `/plugin install vefmvai/bookbench` возвращала ошибку «не найден маркетплейс»).

---

## [0.1.0] — 2026-05-09

Первый публичный релиз. Команда из 9 специализированных субагентов, 5-фазный микро-цикл главы, библиотека голосов, импорт существующих материалов, 40+ команд `/book:*`.

### Added

- **Команда из 9 субагентов:** `book-coordinator` (оркестратор), `book-strategist` (планирует главу), `book-writer` (пишет драфт), `book-factchecker` (проверяет факты), `book-editor` (правит стиль и связность), `book-marketer` (упаковывает финал), `book-doc-classifier` и `book-doc-synthesizer` (импорт), `book-tuner` (анализирует замечания и предлагает правки гайдлайнов).
- **5-фазный микро-цикл главы:** `spec.md → draft.md → factcheck.md → edited.md → marketing.md → summary.md`. Команда `/book:write-chapter <N>` запускает полный цикл; atomic-подкоманды `:draft`, `:factcheck`, `:edit`, `:market` — для повтора отдельной фазы.
- **Гейты автора и петли верификации.** Два обязательных гейта (после `spec.md` и после `marketing.md`); две автоматические петли (writer ↔ factchecker max 3 итерации; editor ↔ factchecker re-check при изменении фактов).
- **Анти-ИИ-клише hook.** 46 паттернов (34 английских + 12 русско-специфичных), три уровня реакции (block / warn / info). Срабатывает после каждого Write писателя и редактора. Bash 3.2-совместимый engine на perl-PCRE.
- **Voice management — голос автора:** шестипараметрическая модель (formality / paragraph length / sentence variety / emotional intensity / dash typography / anglicism tolerance). Voice gate в теле `book-writer` блокирует первый `draft.md` без заполненного `voice-profile.md`. Три пути формирования: B1 (быстрое интервью), B2 (отдельная сессия `/book:voice build`), B3 (агент сам предлагает на основе плана).
- **Личная библиотека голосов `~/.bookbench/voices/`** — per-машина, per-автор, вне плагина и вне книги. Пять команд: `/book:voice extract|save-as|import|list|build`. Голоса переносятся между книгами одной командой `/book:voice import <name>`.
- **Импорт существующих материалов.** Сценарий B: автор кладёт чаты `claude.ai`, заметки Obsidian, черновики `.docx` — `/book:start --from-existing` или `/book:import` запускает оркестратор: классификатор разбирает фрагменты по 11 типам, синтезатор собирает в структуру книги, реестры памяти стартуют пополненными.
- **Реестры уникальности через `memory: project` per role** для 5 ролей цикла. Двухуровневая компакция (live `MEMORY.md` + `archive/chapters-N-M.md` с порогом 10 KB) — на 50-й главе live-реестр всё ещё ≤10 KB.
- **Трёхуровневая архитектура.** Код плагина (`${CLAUDE_PLUGIN_ROOT}`, стирается при `/plugin update`) + данные плагина (`${CLAUDE_PLUGIN_DATA}`, переживает обновления) + папка книги (`.book/`, собственность автора, не трогается обновлениями).
- **Каскад настроек.** `defaults.yaml` (плагин) → `settings.yaml` (пользователь) → `.book/config.yaml` (книга) → override per-chapter в `spec.md`.
- **Гайдлайны команды.** `.book/agent-guidelines/<role>/` — индивидуальность книги (запрещённые фразы, доверенные источники, маркетинговые голоса). Никогда не трогаются обновлениями плагина. Принцип Universal Body + Local Guidelines (`D-15`).
- **`book-tuner` (9-я роль).** Анализирует `TUNING-LOG.md` и `REJECTIONS-LOG.md`, находит систематические паттерны (≥3 повторений), предлагает правки гайдлайнов и конфига. Команды: `/book:tune`, `/book:tune apply <id>`, `/book:tune:guidelines`, `/book:tune:workflow`.
- **`bookbench-evolver`** — dev-команда для меж-книжного анализа. Видна только в local-dev режиме. Команды: `/book:evolve propose|apply|status`. Структурные гарантии приватности: не читает `chapters/`, `inputs/`, `intel/`, `debug/`, `agent-memory/MEMORY.md`. Уважает флаги `private: true` и `include_in_evolver: false`.
- **40+ команд** в slash-namespace `/book:`:
  - **Жизненный цикл книги:** `/book:start`, `/book:status`, `/book:resume`, `/book:next`, `/book:run`, `/book:update`, `/book:help`.
  - **Планирование:** `/book:plan-book`, `/book:plan-chapter <N>`, `/book:discuss-chapter <N>`.
  - **Написание:** `/book:write-chapter <N>` + 4 atomic подкоманды.
  - **Аудит:** `/book:audit-chapter <N>`, `/book:audit-book`, `/book:re-edit-chapter <N>`.
  - **Импорт:** `/book:import`, `/book:resolve <variant-id>`.
  - **Реестр книг:** `/book:list`, `/book:doctor`, `/book:register`, `/book:archive`, `/book:forget`.
  - **Адаптация:** `/book:guidelines`, `/book:config`, `/book:settings`, `/book:tune`, `/book:tune apply`, `/book:tune:guidelines`, `/book:tune:workflow`.
  - **Голос:** `/book:voice build|extract|save-as|import|list|rebuild`.
  - **Жанры и workflow:** `/book:research-genre`, `/book:research-external`, `/book:research-internal`, `/book:workflow:check`, `/book:workflow:edit`.
  - **Финал и эволюция:** `/book:extract-learnings`, `/book:ship`, `/book:debug`, `/book:evolve` (dev-only), `/book:analyze-session`.
- **Жанровый скилл-ресёрчер** для on-demand генерации методологий новых жанров. 5-фазный workflow (genre profiling → deep research → methodology generation → workflow generation → 5-level validation). Жанровый пресет `popular-science` готов в 0.1; остальные генерируются под запрос автора.
- **Три профиля моделей** (`budget` / `balanced` / `quality`) для подбора под план Claude. Опус закреплён за тремя creative-core ролями (стратег, писатель, маркетолог) во всех профилях. См. `docs/models-and-subscriptions.md`.
- **Полная документация на русском** (политика D-23): `README.md` + 10 файлов в `docs/` + `CHANGELOG.md`. Без английских версий в 0.1; перевод — задача 0.2+ при подтверждённом интересе.

### Changed

- **Микро-цикл главы — 5 фаз вместо 4.** Фактчекер выделен в отдельный субагент с `disallowedTools: Edit` (адверсариальная стойка). В одной голове с писателем фактчек размывается; в отдельном контексте — глубже и надёжнее.
- **9 ролей вместо 8.** Добавлен `book-tuner` для адаптации гайдлайнов под книгу. Обоснование — `D-15`, `D-18`.
- **Все 9 субагентов — local** (отказ от модели «4 plugin + 4 local»). Тела копируются в `.book/.claude/agents/` при `/book:start`. Гибкость под книгу важнее автообновления тел.
- **Развёрнутая книга обновлений плагина не получает автоматически** (`WF-04`). После `/book:start` папка живёт автономно. `/book:update` — опциональная команда, по явному запросу.

### Deprecated

_n/a._

### Removed

_n/a._

### Fixed

_n/a — первый публичный релиз._

### Security

- **Privacy guarantees evolver'а — структурные**, не «обещанные». Запретные пути (`chapters/`, `inputs/`, `intel/`, `debug/`, `agent-memory/MEMORY.md`) — на уровне `disallowedTools` в системном промпте `bookbench-evolver`. 4 privacy-теста в `commands/evolve.eval/`.

---

## Известные ограничения 0.1.0

Эти ограничения известны нам и фиксы пойдут минорными релизами 0.1.x по мере боевого использования. Подробное описание и workaround — в [`docs/faq.md`](docs/faq.md), кластер 5 «Troubleshooting».

- **B-14-01:** микро-цикл главы не прогонялся на реальной главе автора до релиза (только simulation). Граничные случаи восстановления могут потребовать ручной правки `chapter-state.yaml`. Workaround: использовать `/book:resume`, при необходимости — `/book:debug <slug>` для persistent debug-сессии.
- **B-14-02:** 4 privacy-теста evolver'а прогонялись только на пустых запретных папках. На реальной книге с непустыми `chapters/`, `inputs/`, `intel/`, `agent-memory/` теоретически возможны неучтённые случаи. Workaround: для конфиденциальных книг ставить `privacy.private: true` в `config.yaml`.
- **B-14-03:** `/book:research-genre` не прогонялся на реальном неизвестном жанре. Может зависать на этапе deep research при нестандартных жанрах или без интернета. Workaround: установить timeout (`--timeout 300`); сформулировать жанр ближе к известным.
- **B-14-04:** tuner не прогонялся на реальных REJECTIONS до релиза. Может выдавать «no patterns found», когда паттерны есть. Workaround: использовать `/book:tune` напрямую (внутри книги) — на одиночной книге алгоритмы те же.
- **B-14-05:** hook anti-ai-cliche не настраивался на реальных текстах глав. Возможны false positives на правомерных конструкциях. Workaround: добавить исключения в `agent-guidelines/writer/forbidden-phrases.md` → секция `# Allowed (overrides default block)`.

### Отложено на 0.2+

- **B-14-06:** `/book:next --execute` требует подтверждения механизма nested slash command dispatch в Claude Code. На 0.1 — без `--execute` (показывает рекомендуемую команду текстом).
- **B-14-07:** `/book:contribute-genre` PR mechanics — не реализованы.
- **B-14-08:** `/book:workflow:add-block`, `:remove-block`, `:move-block` — atomic operators для редактирования workflow.md.
- **B-14-09:** `/book:evolve --ci` mode — режим автоматической работы в CI без подтверждений.
- **Voice profile inheritance (`extends:`).** Каждый профиль самодостаточен; между книгами переносится через `/book:voice save-as`/`import`.
- **Agent teams Claude Code** (split-pane через `tmux`). Оставлено как опциональная ветка для 0.2+.

---

[Unreleased]: https://github.com/vefmvai/bookbench/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/vefmvai/bookbench/releases/tag/v0.2.0
[0.1.5]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.5
[0.1.4]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.4
[0.1.3]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.3
[0.1.2]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.2
[0.1.1]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.1
[0.1.0]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.0
