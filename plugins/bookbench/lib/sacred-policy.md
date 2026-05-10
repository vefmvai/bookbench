# Sacred policy для авто-создаваемых файлов

> **Назначение.** Описывает три правила автогенерации файлов в папке книги. Гарантирует, что артефакты, влияющие на каждое предложение пишущего агента (`agent-guidelines/`) или автоматически читаемые всеми агентами (`context/<status:confirmed>`), создаются только с явного подтверждения автора.
>
> **Этап создания.** 24 (релиз 0.3.2 — patch после live-теста «Спираль»). Фиксирует решение **D-41**.
>
> **Триггер создания.** Класс ошибки #4 (критический) первого живого запуска `/book:start` 2026-05-10: коуч-агент создал `agent-guidelines/writer/voice-samples.md` и `context/voice-profile.md` без согласия автора, и эти файлы тут же стали авторитетными для всех агентов (subagent при чтении не отличает «созданное автором» от «созданного агентом»). Структурный фикс — sacred-метки на категориях файлов и обязательная проверка перед автозаписью.

---

## Три правила

### Правило 1. `.book/agent-guidelines/<role>/` — только с подтверждением автора

**Что защищено:** все файлы под `.book/agent-guidelines/<role>/` (например, `forbidden-phrases.md`, `voice-samples.md`, `cohesion-rules.md`, `author-deviations.md`, `trusted-sources.md`).

**Почему защищено:** содержимое этих файлов влияет на **каждое предложение** соответствующего субагента. `forbidden-phrases.md` writer — это hard rule, который применяется к каждому Write. `voice-samples.md` — образцы голоса, по которым writer калибруется. `trusted-sources.md` factchecker — определяет, чему верить при проверке фактов. Ошибка в этих файлах = систематическая ошибка по всей книге.

**Контракт:**
- Шаблоны в `templates/agent-guidelines/<role>/` копируются командой `/book:start` целиком — это **стартовый шаблон**, не агентом сгенерированный контент.
- Любая последующая запись в `.book/agent-guidelines/<role>/` (со стороны coach-агента, classifier'а, synthesizer'а, tuner'а) ОБЯЗАНА проходить через `AskUserQuestion` с явным предложением и согласием автора.
- Команды, которые имеют право писать в эти файлы без подтверждения: `/book:tune apply <id>` (после явного `apply` от автора в `tune` two-step), `/book:guidelines edit` (прямая ручная команда автора).

**Запрет на `/book:start`:**
- НЕ записывать в `.book/agent-guidelines/writer/voice-samples.md` импортированные тексты автоматически. Использовать `.book/inputs/staged-voice-samples/<slug>.md` как промежуточную staging-папку. Перенос — через `/book:voice-build --from-staged` после явного диалога.

### Правило 2. `.book/context/` со `status: confirmed` — только с подтверждением автора

**Что защищено:** файлы в `.book/context/` с frontmatter-полем `status: confirmed` (например, `voice-profile.md`, `audience.md`, `glossary.md`, `red-thread-keywords.md`).

**Почему защищено:** эти файлы автоматически читаются всеми субагентами как авторитетная конфигурация. Запись со `status: confirmed` без явного «да» от автора превращает гипотезу агента в факт книги.

**Контракт:**
- На этапе `/book:start` агент МОЖЕТ создать файл со `status: draft` в `.book/context/` (например, `voice-profile.md.draft`) — но НЕ со `status: confirmed`.
- Переход в `status: confirmed` возможен только через специализированную команду (`/book:voice-build`) или ручную правку автора.
- Альтернатива — указатель: `.book/context/voice-source-pointer.md` (B1-derived) хранит ссылку на источник без структуризации в формат BookBench.
- Другие файлы (`audience.md`, `glossary.md` и т. д.) на `/book:start` записываются только с явным подтверждением автора в Step 4b шлюзе.

См. также: `lib/voice-profile-lifecycle.md` — детализирует контракт для voice-profile.

### Правило 3. Frontmatter `created_by` + `requires_confirmation` — обязательны для авто-создаваемых артефактов

**Что обязательно:** любой файл, созданный командой плагина (а не автором руками), ДОЛЖЕН иметь во frontmatter:

```yaml
---
created_by: <command-name>          # например: book-coordinator-coach, voice-builder, book-classifier
created_at: <ISO 8601>
requires_confirmation: true | false # true = файл-черновик; всем читающим агентам — игнорировать
status: draft | confirmed           # для context/* и agent-guidelines/*
---
```

**Поведение читающего агента:**
- Если `requires_confirmation: true` или `status: draft` (или `calibrating`) — НЕ читать тело файла, обращаться как с «нет данных».
- Если `requires_confirmation: false` и (`status: confirmed` ИЛИ нет поля `status`) — читать как авторитетный.

---

## Применение в командах

### `/book:start` (Step 6a и далее)

- Перед каждой записью в `.book/agent-guidelines/` или `.book/context/` со `status: confirmed` — проверяется правило 1 / 2. Если нарушает — блок, сообщение автору, переход в Step 4b повторно.
- Все файлы, созданные коуч-агентом автоматически (например, `voice-profile.md.draft`, `audience.md`, `genre-pending.md`), несут frontmatter `created_by: book-coordinator-coach` + `requires_confirmation: true|false` + `status:`.

### `/book:import` (Step 4-6)

- Synthesizer пишет в `.book/inputs/` (свободно, это staging-папка) и в реестры памяти (`agent-memory/<role>/MEMORY.md`).
- Запись в `.book/agent-guidelines/<role>/` — только через `AskUserQuestion` диалог.
- Запись в `.book/context/<file>.md` со `status: confirmed` — запрещена; разрешён только `status: draft`.

### `/book:tune apply <id>`

- Эта команда — единственный механизм, через который правки tuner'а попадают в `.book/agent-guidelines/`. Apply — явное действие автора, после two-step diff.

### `/book:voice-build`

- Создаёт `voice-profile.md` со `status: confirmed` после прохождения диалога 6 параметров с автором (или ratify-existing).

---

## Проверка перед коммитом плагина

Авторы плагина перед коммитом в `commands/` обязаны проверить:
- Не записывает ли новая команда в `.book/agent-guidelines/` без подтверждения автора?
- Не создаёт ли новая команда файлы в `.book/context/` со `status: confirmed` без явного «да» от автора?
- Все ли авто-создаваемые артефакты несут `created_by` + `requires_confirmation`?

---

## Связь с другими документами

- `lib/voice-profile-lifecycle.md` — частный случай sacred-policy для voice-profile (этап 24, D-35).
- `lib/terminology-ru.md` — терминологическая политика (этап 24, D-40).
- `commands/start.md` — обновлён в этапе 24, явно ссылается на этот файл в шапке.
- `templates/agent-guidelines/<role>/README.md` — шаблон ссылается на этот файл в разделе «Sacred policy».
- `agent-templates/*.md` (зеркало `templates/.claude/agents/`) — раздел «Sacred policy» в каждом теле субагента (этап 24, T8).

---

*Создан: 2026-05-10 (этап 24, T8).*
*Связан с: D-41 (sacred policy для авто-создаваемых файлов).*
