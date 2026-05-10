# Changelog

Все значимые изменения в BookBench записываются здесь.

Формат — [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Версионирование — [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_n/a — все изменения текущего цикла вошли в 0.3.4._

---

## [0.3.4] — 2026-05-10

Patch-релиз: косметическое исправление сквозного рассогласования slash-префикса между подсказками плагина и реальным поведением Claude Code. До 0.3.4 в коде плагина и публичной документации везде фигурировал `/book:` (≈909 вхождений в коде плагина + ≈301 в документации), хотя реально работают только команды вида `/bookbench:start`, `/bookbench:write-section` и т.д. Никаких breaking changes для пользователя — реально работающие команды не изменились.

### Changed

- **Массовый replace `/book:` → `/bookbench:`** в коде плагина (`plugins/bookbench/commands/`, `skills/`, `agent-templates/`, `lib/`, `templates/`, `defaults.yaml`, `blocks-catalog.md`) и публичной документации (`README.md`, `docs/`, `CONTRIBUTING.md`, `SECURITY.md`, `tests/eval-cases/`). Итого: ~909 вхождений в коде плагина + ~301 в документации + 56 в тестовых eval-кейсах + 2 в корневых публичных документах = ~1268 правок в ~150 файлах. Команды отныне единообразно фигурируют под тем префиксом, под которым они реально доступны в Claude Code.
- **Версии в трёх манифестах** (`plugins/bookbench/manifest.json`, `plugins/bookbench/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`) синхронно подняты с `0.3.3` до `0.3.4`.

### Why

Поле `slash_prefix: "book"` в манифестах **не описано в официальной документации Claude Code 2.x** (`https://code.claude.com/docs/en/plugins-reference`). Клиент его молча игнорирует и формирует префикс slash-команд из `manifest.name`. Поскольку `manifest.name = "bookbench"`, реальный префикс — `/bookbench:`, а не `/book:`. Этот этап приводит подсказки и документацию в соответствие с реальностью.

**Что НЕ изменилось (защита границ):**

- `manifest.name = "bookbench"` оставлен без изменений (любое его изменение было бы breaking change для всех текущих установок 0.3.3).
- Поле `slash_prefix: "book"` в манифестах **сохранено** на случай, если будущая версия Claude Code включит его поддержку — в этом случае плагин сразу подхватит короткий префикс без изменений.
- Исторические упоминания `/book:*` в записях прошлых релизов настоящего CHANGELOG.md **сохранены без изменений** (они описывают факты прошлых релизов; переписывать их означало бы фальсифицировать историю).
- Архитектурные решения D-15..D-42 не переоткрывались. Никаких новых архитектурных решений на этом этапе не принято.

### Migration (для пользователей 0.3.3)

Никаких ручных шагов. Команды как работали (`/bookbench:start`, `/bookbench:write-section`, `/bookbench:upgrade` и т.д.), так и работают. Изменилось только то, что в подсказках, описаниях команд, документации и сообщениях субагентов теперь везде указан правильный префикс `/bookbench:`. Самый удобный путь обновления — `/bookbench:upgrade` (требует Reload Window после).

### Known issues

- Live dogfooding-проверка `/bookbench:upgrade` 0.3.3 → 0.3.4 — задача автора после публикации релиза 0.3.4 на GitHub. Это одновременно и финальная валидация этого этапа, и первая живая проверка команды `/bookbench:upgrade` из этапа 25.

---

## [0.3.3] — 2026-05-XX <!-- TODO заменить XX на реальную дату публикации при git tag v0.3.3 -->

Patch-релиз: одна команда самообновления плагина. До 0.3.3 пользователю VSCode-расширения нужно было ~6 ручных bash-операций, чтобы перейти с 0.3.1 на 0.3.2, потому что VSCode не умеет обновлять плагины автоматически из github-marketplace. С 0.3.3 — одна команда `/bookbench:upgrade` + Reload Window.

### Added

- **`/bookbench:upgrade`** — новая команда самообновления плагина. Четыре режима:
  - **default** (`/bookbench:upgrade`) — `git pull` локального клона marketplace + перезапись записи `bookbench@bookbench` в `~/.claude/plugins/installed_plugins.json` (поля `installPath`, `version`, `lastUpdated`, `gitCommitSha`) с предварительным бэкапом реестра. После — инструкция «сделай Cmd+Shift+P → Developer: Reload Window». Команда полностью автономна, без интерактивных вопросов.
  - **`--check`** — read-only: показывает текущую/свежую версию и наличие обновления, не правит файлы (`git status` в клоне marketplace остаётся clean, реестр не трогается, бэкап не создаётся).
  - **`--apply-templates`** — после Reload Window переносит в `.book/` текущей книги новые ассеты релиза (новые `templates/agent-guidelines/<role>/*.md`, новые hook-скрипты в `templates/hooks/`) с **подтверждением каждого файла** через `AskUserQuestion`. **Sacred policy D-41 строго соблюдается:** для файлов в `.book/agent-guidelines/<role>/` — диалог обязателен; для файлов в `.book/context/<file>.md` со `status: confirmed` — НЕ перезаписываются никогда. Перед каждой перезаписью — backup в `.book/.backup/upgrade-<timestamp>/`. Запись в `.book/UPDATE-LOG.md`.
  - **`--from <ref>`** — откат на конкретный коммит/тег (например, `--from v0.3.2`), затем тот же путь правки реестра.
- **`bookbench/docs/installation.md`** — новый раздел «Обновление плагина» с примерами всех четырёх режимов команды (заменяет ручной workflow с `rm -rf` кэша + ручной правкой `installed_plugins.json` + `git pull`).

### Changed

- **`plugins/bookbench/manifest.json`** — добавлен `commands/upgrade.md` в массив `commands` (между `update.md` и `help.md`); общее количество команд увеличилось на 1.

### Migration (для пользователей 0.3.2)

После установки 0.3.3 у пользователя сама команда `/bookbench:upgrade` появится автоматически:

```
# Если ты в CLI — старый ручной путь сработает один последний раз:
/plugin marketplace update bookbench
/plugin install bookbench@bookbench
/reload-plugins

# Если ты в VSCode — один последний раз через ручной workflow из docs/installation.md «Если установка не подхватила команды (диагностика)».

# Дальше всегда:
/bookbench:upgrade
# (+ Cmd+Shift+P → Developer: Reload Window в VSCode)
```

Никаких breaking changes по структуре `.book/` или составу субагентов. Existing книги 0.3.2 совместимы — `/bookbench:upgrade --apply-templates` опционален.

### Known issues

- **Live dogfooding-проверка `/bookbench:upgrade` 0.3.2 → 0.3.3 — задача автора** после установки 0.3.3 на dogfooding-машине. Pre-release static review кода команды (T11 этапа 25): backup-логика присутствует, sacred-policy guard для agent-guidelines/ присутствует, NEVER-блок про другие marketplaces присутствует.

---

## [0.3.2] — 2026-05-10

Patch-релиз: закрытие 6 классов ошибок коуч-диалога `/book:start`, выявленных при первом живом запуске 0.3.0/0.3.1 на статье-манифесте «Спираль» 2026-05-10. Никаких breaking changes по структуре `.book/` относительно 0.3.1.

### Fixed

- **Класс ошибки #1: коуч развернул `.book/` без явного «да» по каждому измерению.** Добавлен **Step 4b — шлюз подтверждения** в `commands/start.md`: между коуч-диалогом и развёртыванием `.book/` команда показывает автору сводку и принимает «Да, создавай .book/» либо «Поправь <X>» (X — одно из 5 измерений: Title / Format / Genre / Audience / Addressing / Voice path). Hard guard `if [ "${UNFOLD_CONFIRMED:-0}" != "1" ]; then exit 1` в начале Step 6. § 0 коуч-промпта: узкое MAY-сжатие — три обязательных условия (а) автор всё описал в первом ТЕКСТОВОМ сообщении; (б) сводка <200 знаков; (в) явное «да» по каждому измерению отдельно. Скиданные файлы НИКОГДА не считаются «всё описано чётко».
- **Класс ошибки #2: коуч записал «временный popular-science» вместо пустого custom.** Добавлена ветка **B3-pending** в `lib/start-coach-prompt.md` § 3: автор может выбрать «оставить genre в pending до следующей сессии». В `.book/config.yaml > book.genre` — sentinel `pending` (плюс `genre_pending_reason`). Команды `/book:plan-book`, `/book:plan-section`, `/book:write-section` блокируются с подсказкой запустить `/book:research-genre <slug>`. Жанровые гайдлайны из `defaults.yaml` НЕ копируются в `.book/agent-guidelines/<role>/` при pending.
- **Класс ошибки #3: коуч использовал «ты» вместо «вы» по умолчанию.** Введён первоклассный параметр `book.addressing_mode` (`ты | вы | безличное | смешанное`) в `templates/book/config.yaml`. Новый § 4a в коуч-промпте: вопрос автору с derived_default из `defaults.yaml` (приоритет `genres.<genre>.addressing_default` > `formats.<format>.addressing_default` > общий fallback `«вы»`). Запрет выводить регистр из voice-profile или черновиков. Каскадно прокидывается в `.book/agent-guidelines/{writer,editor}/addressing-rules.md`.
- **Класс ошибки #4 (КРИТИЧЕСКИЙ): коуч извлёк `voice-profile.md` из черновика без согласия автора.** Введён **voice-profile lifecycle** (`lib/voice-profile-lifecycle.md`): 4 состояния `none / draft / confirmed / calibrating`, контракт «субагент ИГНОРИРУЕТ файл со status:draft|calibrating» через MUST-блок в `book-writer.md` и `book-editor.md`. На `/book:start` запрещена запись `.book/context/voice-profile.md` (без `.draft`); только `voice-profile.md.draft` или указатель `voice-source-pointer.md`. § 5 коуч-промпта переписан: B1-confirmed (явный заголовок voice-profile) / B1-derived (раздел «стиль» в широком документе → указатель) / B2-pending (тексты в стиле автора → `.book/inputs/staged-voice-samples/`, не agent-guidelines/) / B2-confirmed (явное «готовое / образец» от автора) / B3 (ничего не приложено).
- **Класс ошибки #5: финальное сообщение «Книга инициализирована» при формате long-read.** Введён адаптивный `document_word` (D-38, симметрично D-31) в `defaults.yaml > formats.<format>`: три поля `document_word`, `document_word_capitalized`, `document_word_gender_suffix`. Step 11 `commands/start.md` использует `${DOCUMENT_WORD_CAPITALIZED} инициализирован${DOCUMENT_WORD_GENDER_SUFFIX}`: «Лонгрид инициализирован» (long-read), «Статья инициализирована» (article), «Книга инициализирована» (book), «Монография инициализирована» (monograph), «Диссертация инициализирована» (dissertation). MUST-блок про `document_word` в `book-writer.md` и `book-editor.md`.
- **Класс ошибки #6: англицизмы-кальки в русскоязычных текстах.** Создан `lib/terminology-ru.md` — глоссарий 14+ калек («дефолт», «воркфлоу», «скаффолдинг», «сэмплы», «батч» и др.) с русскими эквивалентами. Создан `templates/hooks/terminology-lint.sh` (отдельный лёгкий hook от `anti-ai-cliche-lint.sh`) с двумя уровнями реакции: «блок» (exit 2) для калек с прямым эквивалентом; «предупреждение» (exit 0) для остальных. Вычищены существующие вхождения в `commands/{next,research-format,start}.md`, `lib/{section-word-helpers,start-coach-prompt}.md`. Сохранены: «лонгрид», «фреймворк», «коуч», «markdown», «frontmatter».

### Added

- **`lib/voice-profile-lifecycle.md`** — описание 4 состояний voice-profile с frontmatter-схемой и переходами (D-35).
- **`lib/sacred-policy.md`** — три правила автогенерации файлов: запрет автозаписи в `.book/agent-guidelines/`, запрет автозаписи в `.book/context/<status:confirmed>`, обязательный frontmatter `created_by` + `requires_confirmation` (D-41).
- **`lib/terminology-ru.md`** — глоссарий калек и терминологическая политика BookBench (D-40).
- **`.book.proposed.yaml`** — промежуточный конфиг между коуч-диалогом и развёртыванием `.book/` (D-39). Удаляется после успешного Step 6 или при отмене.
- **`templates/agent-guidelines/{writer,editor}/addressing-rules.md`** — шаблоны для четырёх режимов обращения с плейсхолдером `${ADDRESSING_MODE}` (D-37).
- **`templates/hooks/terminology-lint.sh`** — отдельный PostToolUse hook для проверки калек (D-40).
- **5 новых eval-кейсов в `tests/eval-cases/start-coach/`** — case-06 (Step 4b gate), case-07 (B3 genre pending), case-08 (addressing mode), case-09 (voice lifecycle), case-10 (document_word long-read).
- **`tests/start.test.sh`** — snapshot-тест регрессий 7 пакетов проверок (Step 4b gate / voice-profile lifecycle / genre pending / addressing_mode / document_word / sacred-policy / terminology). 35 PASS / 0 FAIL.
- **Поле `addressing_mode`** в `templates/book/config.yaml` под `book` (D-37).
- **Поле `addressing_default`** в каждом жанре и каждом формате `defaults.yaml` (D-37).
- **Поля `document_word*`** в каждом из 5 форматов `defaults.yaml` (D-38).
- **Sentinel `pending`** в комментарии к полю `genre` `templates/book/config.yaml` (D-36).
- **Режим `--from-staged`** в `commands/voice-build.md` — использует `.book/inputs/staged-voice-samples/` как стартовый материал диалога (D-35).
- **Guard на `genre: pending`** в `commands/{plan-book,plan-section,write-section}.md` Step 1/2/3 — exit 2 с подсказкой про `/book:research-genre` (D-36).

### Changed

- **§ 0 `lib/start-coach-prompt.md`:** MAY-сжатие сужено до трёх обязательных условий + явный запрет на использование скиданных файлов как доказательство «автор всё описал чётко».
- **§ 1 `lib/start-coach-prompt.md`:** open-invitation усилена предупреждением о диалоговой природе фазы — «короткая дискуссия, каждое решение — после твоего "да"».
- **§ 5 `lib/start-coach-prompt.md`:** убрано «или эквивалент» из B1; разделено на B1-confirmed (явный заголовок voice-profile) и B1-derived (раздел «стиль» в широком документе — указатель, без структуризации).
- **§ 6 `lib/start-coach-prompt.md` пункт 6:** автоимпорт текстов в авторском стиле — НЕ в `agent-guidelines/`, а в `.book/inputs/staged-voice-samples/` с диалогом «черновик / готовое / просто пример».
- **`commands/start.md` Step 11:** хардкод `Книга инициализирована: «${BOOK_TITLE}»` заменён на адаптивный `${DOCUMENT_WORD_CAPITALIZED} инициализирован${DOCUMENT_WORD_GENDER_SUFFIX}: «${BOOK_TITLE}»` с резолвингом из `defaults.yaml`.
- **`agent-templates/book-writer.md` Voice gate (TOV-08):** усилен через проверку frontmatter `status:` (D-35); файлы со `status: draft|calibrating` или только `.draft`-файлы трактуются как `none`.
- **`agent-templates/book-editor.md`:** добавлен MUST-блок про `document_word` (D-38), MUST-блок про lifecycle voice-profile (D-35), MUST-блок про `addressing_mode` (D-37).

### Migration (для пользователей 0.3.1)

```
/plugin uninstall bookbench@bookbench
/plugin marketplace remove bookbench
/plugin marketplace add vefmvai/bookbench
/plugin install bookbench@bookbench
/reload-plugins
/book:doctor   # должно показать BookBench 0.3.2
```

Никаких breaking changes по структуре `.book/`. Существующие книги 0.3.1 автоматически совместимы — поле `book.addressing_mode` отсутствует, но субагенты знают как работать без него (editor flag-ит без правки до явного указания).

### Known issues

- **35 редких команд по-прежнему имеют английские описания** (наследие 0.1.5, перенесено как known issue в 0.2.0). Перевод отложен на 0.3.x patch.
- **T10 контрольный сценарий «Спираль»** проверен в режиме статической верификации (snapshot-тест + eval-кейсы). Реальный live-run с `brief.md` + `spiral.md` остаётся за автором после установки 0.3.2.

---

## [0.3.1] — 2026-05-09

Hot-fix: marketplace install через `/plugin install bookbench@bookbench` не работал в 0.3.0 — Claude Code 2.1.x клонировал только корневые файлы репо (README, CHANGELOG, LICENSE) без подпапки `plugins/bookbench/`, поэтому плагин «устанавливался» как пустышка (0 commands, 0 skills, 0 agents). Корневая причина — антипаттерн `git-subdir`-ссылки на собственный репо в `marketplace.json`.

### Fixed

- **`.claude-plugin/marketplace.json` поле `source`:** было полное `git-subdir` с url + path + ref + sha (Claude Code не разбирал эту самореференцию корректно и падал на дефолтный sparse-checkout `/*` + `!/*/`, который выкидывает все подпапки). Стало простой строкой с относительным путём `"source": "./plugins/bookbench"` — индустриальный стандарт для marketplace.json внутри своего же репо (используется официальными плагинами 42Crunch, Sentry и др.). Теперь Claude Code корректно находит плагин в подпапке и устанавливает все `commands/`, `skills/`, `agent-templates/`, `lib/`, `templates/`.
- **Поле `version` плагина в marketplace.json** добавлено явно (`"version": "0.3.1"`) рядом с `source` — раньше его не было, теперь следует паттерну Sentry/42Crunch.

### Migration (для пользователей 0.3.0)

```
/plugin uninstall bookbench@bookbench
/plugin marketplace remove bookbench
/plugin marketplace add vefmvai/bookbench
/plugin install bookbench@bookbench
/reload-plugins
/book:doctor   # должно показать BookBench 0.3.1, команды /book:* появятся
```

Если `/book:doctor` не работает или команды `/book:*` не видны — проверьте `~/.claude/plugins/cache/bookbench/bookbench/<sha>-<hash>/` — там должны лежать `manifest.json`, `commands/`, `skills/`, `.claude-plugin/plugin.json`.

---

## [0.3.0] — 2026-05-09

> ⚠️ **Сломанный marketplace install.** В 0.3.0 marketplace install через `/plugin install bookbench@bookbench` не работает (Claude Code клонирует только корень репо без подпапки плагина). Используйте 0.3.1.

Major-релиз. Переосмысление стартового онбординга и разделение четырёх измерений работы автора (`genre / style / format / audience`) как ортогональных первоклассных сущностей фреймворка. Структурный рефакторинг терминологии `chapter` → `section` во всём коде плагина (~150 файлов). Релиз вырос из первого живого запуска `/book:start` на статье-манифесте «Спираль» в мае 2026 — четыре серьёзных UX-проблемы стартового интервью + одна концептуальная развилка стали Milestone 2.

### Added

- **Коуч-режим `/book:start`.** Заменили жёсткое 5-вопросное radio-интервью на открытый коуч-диалог. Команда принимает свободное описание автора, голосовой ввод и приложенные файлы (drafts, voice-samples, заметки); агент анализирует вход + опционально вызывает `/book:import` автоматически; формулирует одну гипотезу понимания «формат — X, ближайший жанр — Y, аудитория — Z, метка стиля — B1/B2/B3» с подтверждением автора. Реализовано inline в команде с физическим выносом коуч-промпта в `lib/start-coach-prompt.md` (433 строки, 4 коуч-сборки по `matching-design.md` §§ 3.1–3.7). Архитектурное решение D-33 (без 11-го субагента; состав команды остаётся 9 субагентов + voice-builder Skill).
- **Поле `book.format` в `config.yaml`** с дефолтом `book` и значениями `article | book | monograph | dissertation | other`. Влияет на единицу работы, ожидаемый объём, workflow книги и адаптивную подстановку слов «глава / раздел / часть» в диалогах субагентов.
- **Поле `book.audience` как свободный текст-портрет** (не enum). Заполняется на основе описания автора в коуч-диалоге.
- **Поле `workflow.completion_format` с дефолтом `editor_pass_plus_author_approval`** (закрывает непонятный вопрос «когда глава готова» из старого стартового интервью). Меняется через `/book:config`.
- **Новая команда `/book:research-format`** (336 строк) — симметрично `/book:research-genre`. Запускает Deep Research по произвольному формату (например, screenplay, longread, photo-essay), генерирует пресет в `${CLAUDE_PLUGIN_DATA}/user-formats/` для повторного использования.
- **5 пресетов форматов в `defaults.yaml`** (`article`, `book`, `monograph`, `dissertation`, `other`) + ключ `compatible_formats` ко всем 4 жанровым пресетам с обязательной симметрией жанр ↔ формат.
- **Поле `formats.<format>.section_word`** для adaptive substitution: каждый субагент читает `book.format` из `.book/config.yaml`, находит `section_word` и подставляет его в диалоги с автором («глава» / «раздел» / «часть»). В технических контекстах (имена файлов, путей, полей) везде `section`. Архитектурное решение D-31.
- **Четырёхмерная модель работы автора (D-30)** — `genre / style / format / audience` как ортогональные первоклассные сущности фреймворка. Формат — расширяемая библиотека (как жанры), не enum. Стиль собирается отдельно через `voice-builder` с отлётом до первой секции (TOV-08 сохранён дословно).
- **5 eval-кейсов `tests/eval-cases/start-coach/`** — happy-path научпоп / voice-samples B2 / drafts автоимпорт / screenplay (B2 ресёрч) / uncertain (развилка «не уверен»).
- **`lib/section-word-helpers.md`** — документация процедуры adaptive substitution для контрибьюторов.
- **Документация `docs/section-cycle.md`** — полный цикл работы над секцией (раньше был `chapter-cycle.md`, переименован под D-31).

### Changed

- **`chapter` → `section` во всём коде плагина** (~150 файлов): переименована директория шаблона `templates/book/chapters/` → `templates/book/sections/`; переименованы поля `current_chapter` → `current_section`, `chapter_loop` → `section_loop`, `chapter_target_chars` → `section_target_chars` в шаблонах `templates/book/STATE.md`, `PROJECT.md`, `ROADMAP.md`, `config.yaml`. Адаптивная подстановка «глава/раздел/часть» в диалогах с автором — через `formats.<format>.section_word` + 5-строчный MUST-блок в каждом из 10 субагентов (D-31).
- **9 slash-команд переименованы:** `/book:write-chapter` → `/book:write-section` (+ atomic подкоманды `:draft`, `:factcheck`, `:edit`, `:market`); `/book:plan-chapter` → `/book:plan-section`; `/book:audit-chapter` → `/book:audit-section`; `/book:re-edit-chapter` → `/book:re-edit-section`; `/book:discuss-chapter` → `/book:discuss-section`. Манифест плагина обновлён под новые имена.
- **Тела всех 10 субагентов** (`agent-templates/` + зеркало `templates/claude-config/agents/`, по A-14.1-01) — все упоминания `chapter` в системных промптах заменены на `section` + добавлен 5-строчный MUST-блок D-31 по чтению `book.format` и подстановке `section_word`.
- **11 SKILL.md** обновлены под новую терминологию (`anti-ai-cliche`, `base-methodology`, `factcheck-protocol`, `genre-researcher`, `genres/.template`, `genres/popular-science`, `import-classification-protocol`, `import-synthesis-protocol`, `marketing-protocol`, `voice-builder`, `voice-profile`).
- **`argument-hint` команды `/book:start`** — флаг `--from-existing` удалён. Автоимпорт срабатывает автоматически по приложенным файлам.
- **Документация `docs/`** — все 14 файлов проверены на упоминания `chapter` / «глава», обновлены под адаптивный термин или прямой `section` по контексту.

### Removed

- **9 старых слаш-команд** (`write-chapter`, `write-chapter:draft|factcheck|edit|market`, `plan-chapter`, `audit-chapter`, `re-edit-chapter`, `discuss-chapter`) удалены из `manifest.json` без deprecation aliases (D-32). У нас нет инициализированных книг 0.2.x на момент релиза, миграция обратной совместимости не нужна.
- **Старая директория шаблона `templates/book/chapters/`** и связанные файлы.
- **Файл `docs/chapter-cycle.md`** — заменён на `docs/section-cycle.md`.

### Breaking changes

- Структура `.book/` несовместима с 0.2.x: пути секций (`sections/` вместо `chapters/`), поля конфига (`current_section`, `chapter_loop` → `section_loop`, добавлены `book.format`, `book.audience`, `workflow.completion_format`).
- Slash-команды переименованы (`/book:write-chapter` → `/book:write-section` и т.д.) — старые имена не работают.
- Step 4 `/book:start` не показывает radio-кнопки — принимает свободный текст и/или приложенные файлы.

**Миграция:** так как у пользователей нет инициализированных книг 0.2.x, требуется только чистая переустановка плагина (см. блок ниже).

### Migration (для пользователей 0.2.x)

```
/plugin uninstall bookbench@bookbench
/plugin marketplace remove bookbench
/plugin marketplace add vefmvai/bookbench
/plugin install bookbench@bookbench
/reload-plugins
/book:doctor   # должно показать BookBench 0.3.0
```

Если у вас уже есть инициализированная книга 0.2.x — см. секцию «Обновление с 0.2.x на 0.3.0» в `docs/upgrade-guide.md`.

### Known issues

- **35 редких команд по-прежнему имеют английские описания** (наследие 0.1.5, перенесено как known issue в 0.2.0). Перевод отложен на 0.3.x patch.
- **Префикс `/book:` против `/bookbench:`** — статус прежний, поведение зависит от версии Claude Code, проверка эмпирическая.

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
  - 15 команд: `start`, `write-section`, `plan-book`, `plan-section`, `discuss-chapter`, `status`, `next`, `help`, `voice-build`, `voice-extract`, `voice-list`, `audit-chapter`, `audit-book`, `re-edit-chapter`, `import`.
  - 11 `SKILL.md`: `anti-ai-cliche`, `base-methodology`, `factcheck-protocol`, `genre-researcher`, `genres/.template`, `genres/popular-science` (был уже на русском), `import-classification-protocol`, `import-synthesis-protocol`, `marketing-protocol`, `voice-builder`, `voice-profile`.
  - 9 агентов: `book-coordinator`, `book-doc-classifier`, `book-doc-synthesizer`, `book-editor`, `book-factchecker`, `book-marketer`, `book-observer`, `book-strategist`, `book-tuner`, `book-writer`. Двойные копии в `templates/claude-config/agents/` синхронизированы (соблюдение A-14.1-01).
- **Терминология глоссария зафиксирована.** Принят единый глоссарий перевода: chapter→глава, draft→драфт, voice profile→профиль голоса, factcheck→факт-чекинг, workflow→воркфлоу, registry→реестр, audit→аудит, tune→тюнинг, eval→eval-кейс, subagent→субагент. Имена агентов (`book-writer`, `book-strategist` и т.д.), пути файлов, параметры команд, имена скиллов — не переводятся, остаются машинно-читаемыми.

### Fixed

- **Поле `slash_prefix` перенесено в `.claude-plugin/plugin.json`** — оно уже было в `manifest.json`, но Claude Code 2.1.x его, по-видимому, оттуда не читал и формировал слаш-префикс из `name` (отсюда `/bookbench:*` вместо желаемого `/book:*`). Теперь дублируется в стандартный `.claude-plugin/plugin.json`. Эффект на автодополнение проверяется автором после обновления плагина.

### Known issues

- **35 редких команд остаются с английскими описаниями** — `archive`, `register`, `forget`, `evolve`, `tune`, `tune-guidelines`, `tune-workflow`, `workflow-add-block`, `workflow-check`, `workflow-edit`, `workflow-move-block`, `workflow-remove-block`, `research-external`, `research-genre`, `research-internal`, `voice-save-as`, `voice-import`, `extract-learnings`, `ship`, `resolve`, `resume`, `run`, `settings`, `update`, `debug`, `doctor`, `config`, `guidelines`, `contribute-genre`, `list`, `analyze-session`, `write-section:draft`, `write-section:edit`, `write-section:factcheck`, `write-section:market`. Перевод запланирован на 0.1.6 или 0.2.
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
- **5-фазный микро-цикл главы:** `spec.md → draft.md → factcheck.md → edited.md → marketing.md → summary.md`. Команда `/book:write-section <N>` запускает полный цикл; atomic-подкоманды `:draft`, `:factcheck`, `:edit`, `:market` — для повтора отдельной фазы.
- **Гейты автора и петли верификации.** Два обязательных гейта (после `spec.md` и после `marketing.md`); две автоматические петли (writer ↔ factchecker max 3 итерации; editor ↔ factchecker re-check при изменении фактов).
- **Анти-ИИ-клише hook.** 46 паттернов (34 английских + 12 русско-специфичных), три уровня реакции (block / warn / info). Срабатывает после каждого Write писателя и редактора. Bash 3.2-совместимый engine на perl-PCRE.
- **Voice management — голос автора:** шестипараметрическая модель (formality / paragraph length / sentence variety / emotional intensity / dash typography / anglicism tolerance). Voice gate в теле `book-writer` блокирует первый `draft.md` без заполненного `voice-profile.md`. Три пути формирования: B1 (быстрое интервью), B2 (отдельная сессия `/book:voice build`), B3 (агент сам предлагает на основе плана).
- **Личная библиотека голосов `~/.bookbench/voices/`** — per-машина, per-автор, вне плагина и вне книги. Пять команд: `/book:voice extract|save-as|import|list|build`. Голоса переносятся между книгами одной командой `/book:voice import <name>`.
- **Импорт существующих материалов.** Сценарий B: автор кладёт чаты `claude.ai`, заметки Obsidian, черновики `.docx` — `/book:start --from-existing` или `/book:import` запускает оркестратор: классификатор разбирает фрагменты по 11 типам, синтезатор собирает в структуру книги, реестры памяти стартуют пополненными.
- **Реестры уникальности через `memory: project` per role** для 5 ролей цикла. Двухуровневая компакция (live `MEMORY.md` + `archive/sections-N-M.md` с порогом 10 KB) — на 50-й главе live-реестр всё ещё ≤10 KB.
- **Трёхуровневая архитектура.** Код плагина (`${CLAUDE_PLUGIN_ROOT}`, стирается при `/plugin update`) + данные плагина (`${CLAUDE_PLUGIN_DATA}`, переживает обновления) + папка книги (`.book/`, собственность автора, не трогается обновлениями).
- **Каскад настроек.** `defaults.yaml` (плагин) → `settings.yaml` (пользователь) → `.book/config.yaml` (книга) → override per-section в `spec.md`.
- **Гайдлайны команды.** `.book/agent-guidelines/<role>/` — индивидуальность книги (запрещённые фразы, доверенные источники, маркетинговые голоса). Никогда не трогаются обновлениями плагина. Принцип Universal Body + Local Guidelines (`D-15`).
- **`book-tuner` (9-я роль).** Анализирует `TUNING-LOG.md` и `REJECTIONS-LOG.md`, находит систематические паттерны (≥3 повторений), предлагает правки гайдлайнов и конфига. Команды: `/book:tune`, `/book:tune apply <id>`, `/book:tune:guidelines`, `/book:tune:workflow`.
- **`bookbench-evolver`** — dev-команда для меж-книжного анализа. Видна только в local-dev режиме. Команды: `/book:evolve propose|apply|status`. Структурные гарантии приватности: не читает `sections/`, `inputs/`, `intel/`, `debug/`, `agent-memory/MEMORY.md`. Уважает флаги `private: true` и `include_in_evolver: false`.
- **40+ команд** в slash-namespace `/book:`:
  - **Жизненный цикл книги:** `/book:start`, `/book:status`, `/book:resume`, `/book:next`, `/book:run`, `/book:update`, `/book:help`.
  - **Планирование:** `/book:plan-book`, `/book:plan-section <N>`, `/book:discuss-chapter <N>`.
  - **Написание:** `/book:write-section <N>` + 4 atomic подкоманды.
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

- **Privacy guarantees evolver'а — структурные**, не «обещанные». Запретные пути (`sections/`, `inputs/`, `intel/`, `debug/`, `agent-memory/MEMORY.md`) — на уровне `disallowedTools` в системном промпте `bookbench-evolver`. 4 privacy-теста в `commands/evolve.eval/`.

---

## Известные ограничения 0.1.0

Эти ограничения известны нам и фиксы пойдут минорными релизами 0.1.x по мере боевого использования. Подробное описание и workaround — в [`docs/faq.md`](docs/faq.md), кластер 5 «Troubleshooting».

- **B-14-01:** микро-цикл главы не прогонялся на реальной главе автора до релиза (только simulation). Граничные случаи восстановления могут потребовать ручной правки `chapter-state.yaml`. Workaround: использовать `/book:resume`, при необходимости — `/book:debug <slug>` для persistent debug-сессии.
- **B-14-02:** 4 privacy-теста evolver'а прогонялись только на пустых запретных папках. На реальной книге с непустыми `sections/`, `inputs/`, `intel/`, `agent-memory/` теоретически возможны неучтённые случаи. Workaround: для конфиденциальных книг ставить `privacy.private: true` в `config.yaml`.
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

[Unreleased]: https://github.com/vefmvai/bookbench/compare/v0.3.3...HEAD
[0.3.3]: https://github.com/vefmvai/bookbench/releases/tag/v0.3.3
[0.3.2]: https://github.com/vefmvai/bookbench/releases/tag/v0.3.2
[0.3.1]: https://github.com/vefmvai/bookbench/releases/tag/v0.3.1
[0.3.0]: https://github.com/vefmvai/bookbench/releases/tag/v0.3.0
[0.2.0]: https://github.com/vefmvai/bookbench/releases/tag/v0.2.0
[0.1.5]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.5
[0.1.4]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.4
[0.1.3]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.3
[0.1.2]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.2
[0.1.1]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.1
[0.1.0]: https://github.com/vefmvai/bookbench/releases/tag/v0.1.0
