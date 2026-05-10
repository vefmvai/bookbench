# Быстрый старт

> Первые 30 минут с BookBench — от установки до завершённой первой главы.
> Все примеры идут на синтетической книге **«История кофе: от Эфиопии до латте»** (научпоп, ~25 глав).

---

## Содержание

1. [Предусловия](#предусловия)
2. [Установка плагина](#установка-плагина)
3. [Сценарий A — с чистого листа](#сценарий-a--с-чистого-листа)
4. [Сценарий B — с существующих материалов](#сценарий-b--с-существующих-материалов)
5. [Что появилось в папке](#что-появилось-в-папке)
6. [Если что-то пошло не так](#если-что-то-пошло-не-так-в-первой-сессии)

---

## Предусловия

| Что | Минимум | Где проверить |
|-----|---------|---------------|
| Claude Code | 2.x | `claude --version` |
| Подписка Claude | Pro / Max / Team | [`models-and-subscriptions.md`](models-and-subscriptions.md) |
| Bash 3.2+ | Поставляется в macOS / Linux; в Windows — через WSL | `bash --version` |
| Git (опционально) | Любой | `git --version` |
| Свободное место | ~50 MB на плагин + размер книги | — |

Если стоит только Claude Code и подписка — можно начинать.

---

## Установка плагина

```bash
# Команда выполняется внутри Claude Code
> /plugin marketplace add vefmvai/bookbench
> /plugin install bookbench@bookbench
> /reload-plugins
```

Плагин разворачивает свой код в `${CLAUDE_PLUGIN_ROOT}` (с 0.2.0 — это подпапка `plugins/bookbench/` репозитория, отгружаемая через `git-subdir`) и инициализирует папку данных `${CLAUDE_PLUGIN_DATA}` при первом запуске любой `/bookbench:*` команды.

Подробности по режимам установки (local-dev / GitHub release / Marketplace) — в [`installation.md`](installation.md).

После установки в любой директории доступны команды `/bookbench:*`. Чтобы убедиться, что всё на месте:

```
> /bookbench:doctor
🤖 BookBench 0.2.0 — диагностика
   ├─ Claude Code: 2.4 ✅
   ├─ ${CLAUDE_PLUGIN_ROOT}: смонтирован ✅
   ├─ ${CLAUDE_PLUGIN_DATA}: создан ✅
   ├─ Bash hooks: исполняемые ✅
   └─ Известных книг: 0
```

---

## Сценарий A — с чистого листа

> У автора есть только идея. Папка пустая. Шагов 7. Время — около 30 минут до завершённой первой главы.

### Шаг A-1. Создать папку и запустить установочное интервью

```bash
$ mkdir history-of-coffee && cd history-of-coffee
$ claude
```

Внутри Claude Code:

```
> /bookbench:start
🤖 [book-coordinator] Привет. У вас уже есть наброски, заметки или чаты по этой книге? (y/n)
📝 n
🤖 Отлично — начинаем с чистого листа. Несколько вопросов:

   ✋ Жанр? (научпоп / нарративный нон-фикшн / монография / диссертация / своё)
📝 научпоп

   ✋ Рабочее название книги?
📝 «История кофе: от Эфиопии до латте»

   ✋ Кому адресована? (одна-две строки)
📝 широкая аудитория без специальной подготовки; интересуются культурой и историей повседневных вещей

   ✋ Ориентировочный объём (количество глав)?
📝 ~25 глав

   ✋ Язык книги — русский?
📝 да

   ✋ Заполнять профиль голоса прямо сейчас или отложить до первой главы?
📝 отложить

🤖 Развёртываю структуру книги...
   ├─ .book/PROJECT.md      (видение книги)
   ├─ .book/ROADMAP.md      (план глав — пока пустой)
   ├─ .book/STATE.md        (журнал)
   ├─ .book/config.yaml     (количественные параметры)
   ├─ .book/workflow.md     (пресет popular-science)
   ├─ .book/context/        (parameters, voice-profile, glossary, ...)
   ├─ .book/agent-guidelines/  (9 ролей × дефолтные гайдлайны жанра)
   ├─ .book/.claude/agents/    (9 локальных тел субагентов)
   ├─ .book/.hooks/         (anti-ai-cliche-lint.sh)
   ├─ .book/sections/       (пусто, заполнится по мере глав)
   └─ .book/agent-memory/   (пустые MEMORY.md по 5 ролям цикла)

✅ Книга «История кофе» развёрнута. Записан в реестр книг (registry.yaml).
   Следующий шаг: /bookbench:plan-book — стратег предложит план книги.
```

> **Что произошло.** Координатор скопировал шаблон папки книги из плагина, развернул workflow для жанра «научпоп» (он уже встроен), приготовил 9 локальных тел субагентов в `.book/.claude/agents/` и записал книгу в глобальный реестр. Теперь эта папка автономна: обновления плагина её не тронут (см. `WF-04` в [`upgrade-guide.md`](upgrade-guide.md)).

### Шаг A-2. План книги через стратега

```
> /bookbench:plan-book
🤖 [book-coordinator] вызываю book-strategist...
   <files_to_read>: PROJECT.md, ROADMAP.md, agent-guidelines/strategist/, popular-science-methodology
   skills: base-methodology, popular-science-methodology

🤖 [book-strategist] возвращаю предложение (draft-roadmap.md):

   Часть I. Происхождение (главы 1-5)
   ├─ Гл. 1. Легенда о Калди и эфиопских пастухах
   ├─ Гл. 2. От жевания зёрен к напитку: первые рецепты
   ├─ Гл. 3. Кофе в Йемене: суфийские монастыри как первые «кофейни»
   ├─ Гл. 4. Запреты и легализация: спор богословов
   └─ Гл. 5. Распространение по Османской империи

   Часть II. Кофе и Европа (главы 6-12)
   ...

   Часть V. Кофе сегодня: индустрия, культура, наука (главы 22-25)

✋ План из 25 глав в 5 частях. Утверждаешь? Можно править/добавлять/удалять.
📝 принимаю всё, кроме главы 4 — переименуй её в «Битва за легализацию: фетвы и кофейни»
🤖 ✅ ROADMAP.md записан.
   Также извлёк 7 red thread keywords для всей книги:
   [«ритуал», «социальное пространство», «глобальная торговля», «технология обжарки»,
    «культурная адаптация», «производственная цепь», «кофеин как стимулятор»]
✋ Подтверждаешь red thread keywords?
📝 y
🤖 ✅ red-thread-keywords.md создан.
```

> **Что произошло.** Стратег прочитал, что вы заявили в `PROJECT.md`, обратился к жанровому скиллу `popular-science-methodology` (он автоматически инжектируется через `skills:`-поле субагента) и сгенерировал план. Red thread keywords — это сквозные термины-нити; стратег будет следить, чтобы они проходили через все главы и не растворялись.

### Шаг A-3. ТЗ первой главы

```
> /bookbench:plan-section 1
🤖 [book-coordinator] вызываю book-strategist для ТЗ главы 1...
🤖 [book-strategist] записал sections/01/spec.md:

   ## Section 1: Легенда о Калди и эфиопских пастухах
   ## Цель главы
   Открыть книгу через сильную нарративную сцену; ввести читателя в географию
   и быт IX-X веков Эфиопии; зафиксировать «момент открытия» как символ.

   ## Red thread keywords для этой главы
   — «ритуал» (зародыш ритуала бодрствования)
   — «культурная адаптация» (эфиопы → жевали зёрна, не варили)

   ## Ключевые примеры (используем 3 из 5 предложенных)
   1. Сцена с Калди и козами (легенда; вводим как легенду, а не факт)
   2. Эфиопские плоскогорья — описание ландшафта
   3. Жевание зёрен с маслом — реальный ранний способ употребления

   ## Структура (Pyramid: governing thought + 3 supports)
   - Governing thought: «Кофе вошёл в человеческую культуру через тело, а не через идею»
   - Support 1: легенда как нарративный крючок
   - Support 2: археологические и этнографические данные
   - Support 3: переход от жевания к питью — мост к главе 2

   ## Что в этой главе НЕ должно быть
   — Богословских споров (это глава 4)
   — Описания современной кофейной индустрии (часть V)
   — Биохимии кофеина (упоминаем без деталей; разворачиваем в главе 23)

   ## Параметры
   - target_length: 5500-7500 знаков
   - voice: см. .book/context/voice-profile.md (пока пуст; gate сработает в writer)

✋ ТЗ главы 1 готово. Утверждаешь? (можно править)
📝 y
```

### Шаг A-4. Запуск 5-фазного цикла главы

```
> /bookbench:write-section 1
🤖 [book-coordinator] запускаю микро-цикл главы 1.

   Фаза 1/5: Стратег — уже выполнено (spec.md от A-3)

   Фаза 2/5: Писатель
   ├─ Task(book-writer, ...)
   │   <files_to_read>: spec.md, voice-profile.md, agent-guidelines/writer/,
   │                    agent-memory/writer/MEMORY.md
   │
   ⚠️  voice_pending: voice-profile.md пуст. Запускаю voice gate.
   
✋ Перед написанием первой главы нужен профиль голоса. Выбери путь:
   B1 — быстрое интервью прямо здесь (5 минут, 5 вопросов).
   B2 — отдельная сессия /bookbench:voice build (15-20 минут, с пробным абзацем).
   B3 — агент сам предложит профиль на основе плана книги (2-3 минуты на подтверждение).
📝 B3
🤖 [book-writer] передаю управление voice-builder, активирую путь B3.
🤖 [voice-builder] прочитал PROJECT.md, ROADMAP.md, spec.md, target-audience.
   Предлагаю профиль:
   - Formality: neutral (не слишком академично, не сленг)
   - Paragraph length: medium (4-5 предложений)
   - Sentence variety: mixed
   - Emotional intensity: warm
   - Dash typography: medium
   - Anglicism tolerance: moderate

   Пробный абзац на тему главы 1:
   > «Около IX века в эфиопских горах пастух по имени Калди заметил странное поведение
   > своих коз. Они не ложились спать. Скакали по камням, как будто кто-то засыпал
   > им в шерсть медные монеты. Это, конечно, легенда — но в любой легенде есть
   > деталь, за которую можно зацепиться: на этих плоскогорьях рос куст с тёмно-красными
   > ягодами, и кто-то из людей решил, что не зря козы у него такие живые.»

✋ Этот голос подходит? (y / поправить параметр / переключить на B1)
📝 y
🤖 ✅ voice-profile.md заполнен. Возвращаю писателю.

   Писатель пишет драфт по 5000-знаковым блокам с контрольными точками...
   Hook anti-ai-cliche-lint срабатывает на блоке 3: найдено «отправляемся в путешествие».
      ↳ возврат на правку → переписано → hook pass.
   Двойной audit-pass: писатель проходит черновик с явным вопросом «что выдаёт ИИ».
   ✅ sections/01/draft.md создан (6800 знаков).

   Фаза 3/5: Фактчекер
   ├─ Task(book-factchecker, ...)
   │   tools: Read, WebSearch, WebFetch, Write
   │   disallowedTools: Edit  (адверсариальная стойка — не правит)
   │
   ├─ Проверяет каждое утверждение, тэгирует:
   │   [VERIFIED: source.org/...] — 8 утверждений
   │   [CITED: Schapira «The World of Caffeine», 2001] — 3 утверждения
   │   [ASSUMED] — 2 утверждения, требуют проверки автором
   │   [SPECULATIVE: легенда] — 1 нарративный момент
   │
   ⚠️  Найдена 1 проблема:
   1. «Калди жил в IX веке» — точная датировка легенды отсутствует во всех
      доступных источниках (BLOCKER).
   ↳ Loop verification: writer revise-mode → правит формулировку на «около IX-X
     века» с явной пометкой «легенда; точная дата неизвестна».
   ↳ Re-check фактчекера: pass.
   ✅ sections/01/factcheck.md создан.

   Фаза 4/5: Редактор
   ├─ Task(book-editor, ...)
   │   tools: Read, Edit, Write
   │
   ├─ 4 уровня редактуры (developmental → line → copy → proof)
   ├─ Сокращает на ~10% (6800 → 6100 знаков; King's −10% rule)
   ├─ Двойной audit-pass анти-ИИ-клише после edit → pass
   ├─ Проверяет cohesion с другими главами (для гл. 1 — пусто)
   └─ ✅ sections/01/edited.md создан.

   Фаза 5/5: Маркетолог
   ├─ Task(book-marketer, ...)
   ├─ Telegram-пост (4-частная структура)
   ├─ Промпт обложки в Midjourney (1 крупный объект — кофейная ягода;
   │   не «карта мира с маршрутами»)
   ├─ 3 фрагмента-цитаты для соцсетей
   └─ ✅ sections/01/marketing.md создан.

   Финализация координатора:
   ├─ sections/01/summary.md (сводка ≤500 знаков для context budget будущих глав)
   ├─ Обновлены реестры:
   │   ├─ agent-memory/strategist/MEMORY.md: ["легенда о Калди", "эфиопские плоскогорья"]
   │   ├─ agent-memory/writer/MEMORY.md: используемые примеры, метафоры, voice notes
   │   ├─ agent-memory/factchecker/MEMORY.md: source-IDs для гл. 1
   │   └─ agent-memory/marketer/MEMORY.md: визуальный образ — «красная ягода крупно»
   ├─ Обновлён STATE.md
   └─ ✋ Финальный обзор: посмотреть edited.md и marketing.md.
```

### Шаг A-5. Финальный обзор

```
📝 [читает edited.md, доволен; читает marketing.md, правит одну формулировку
   в Telegram-посте через обычный редактор]
> /bookbench:status
🤖 Книга «История кофе»: глава 1 завершена.
   Готово: 1 / 25 глав (4%).
   Следующее: /bookbench:plan-section 2 или /bookbench:next.
```

### Шаг A-6. Следующая глава

При работе над главой 2 контроль уникальности срабатывает автоматически: стратег видит в `agent-memory/strategist/MEMORY.md` использованные концепты главы 1 и не повторяет их. Если глава 2 случайно затрагивает то, что уже было — стратег предложит другой угол.

### Шаг A-7. Что дальше

После 5–10 глав имеет смысл запустить `/bookbench:tune` — tuner проанализирует `REJECTIONS-LOG.md` (где координатор фиксирует каждую вашу правку готовой главы) и предложит правки гайдлайнов. Если 3+ раз вы правили одно и то же — это будет предложено как critical-приоритет.

---

## Сценарий B — с существующих материалов

> У автора уже есть половина книги в чатах `claude.ai`, заметки в Obsidian, три черновика в `.docx`. Это типичный реальный кейс. Шагов 8. Время — около 45-60 минут до завершённой первой главы (импорт занимает ~15-20 минут на ~50 файлов).

### Шаг B-1. Создать папку, запустить установочное интервью с импортом

```bash
$ mkdir history-of-coffee && cd history-of-coffee
$ claude
> /bookbench:start --from-existing
🤖 [book-coordinator] Привет. У вас уже есть наброски/чаты/черновики.
   Где они хранятся?
   1) Локальная папка md/docx/txt
   2) Экспорты чатов claude.ai (json/md)
   3) Заметки Obsidian (.md в vault'е)
   4) Несколько источников
📝 4
✋ Дай пути:
📝 ~/Notes/coffee-book/, ~/Downloads/claude-export-2026-04.json, ~/Drafts/coffee-section-*.docx
🤖 Найдено: 47 файлов (38 md, 5 docx, 1 json с 12 чатов, 3 txt).
   Сначала зададим базовые параметры — как в сценарии A.
   ... (жанр, название, аудитория, объём, язык)
🤖 ✅ Базовые параметры сохранены. Готово к импорту.
```

### Шаг B-2. Запустить импорт

```
> /bookbench:import
🤖 [book-coordinator] запускаю оркестратор импорта.

   Фаза 1/2: Параллельная классификация
   ├─ Task(book-doc-classifier, file=~/Notes/coffee-book/note-01.md)
   ├─ Task(book-doc-classifier, file=~/Notes/coffee-book/note-02.md)
   ├─ ... (47 файлов)
   └─ Task(book-doc-classifier, file=~/Drafts/coffee-section-3.docx)

   Каждый classifier пишет .book/intel/classifications/<file>.json:
   {
     "file": "note-12.md",
     "fragments": [
       {"type": "idea", "text": "...", "confidence": 0.9},
       {"type": "metaphor", "text": "...", "confidence": 0.8},
       {"type": "fact", "text": "...", "claim": "[ASSUMED]"},
       {"type": "voice-sample", "text": "..."}
     ]
   }

   11 классов: idea / section-draft / fact / metaphor / visual-reference /
   voice-sample / question-to-self / glossary-entry / quote / structure-element / dialog

   Фаза 2/2: Synthesis
   └─ Task(book-doc-synthesizer, ...)
       <files_to_read>: все intel/classifications/*.json
       
   Synthesizer создаёт:
   ├─ Предлагаемый ROADMAP.md из набросков (18 глав явно прописаны, 7 — пробелы)
   ├─ Группировку фрагментов по будущим главам
   ├─ Стартовое наполнение реестров (12 концепций, 8 метафор, 23 утверждения [ASSUMED])
   ├─ Глоссарий из glossary-entry фрагментов (47 терминов)
   ├─ Voice profile (извлечён из voice-sample фрагментов как образец стиля)
   └─ INGEST-DECISIONS.md — список фрагментов и их назначения

✋ Импорт готов. Просмотри INGEST-DECISIONS.md:
   ├─ Что вошло: 387 фрагментов в 18 глав
   ├─ Что отложено: 12 BLOCKER'ов (фрагменты с conflicting типами)
   └─ Что отвергнуто: 23 дубликата

📝 пользователь смотрит INGEST-DECISIONS.md, правит 3 решения через /bookbench:resolve
> /bookbench:resolve fragment-127 section-15
> /bookbench:resolve fragment-204 reject
> /bookbench:resolve fragment-318 section-8
🤖 ✅ Решения применены.
```

### Шаг B-3. Подтверждение жанра и плана

```
🤖 [book-coordinator] Из импорта определил жанр: научпоп (confidence 0.91).
   Подтверждаешь?
📝 y
🤖 ✅ Подключаю popular-science-methodology.

> /bookbench:plan-book --from-imports
🤖 [book-strategist] финализирую ROADMAP с учётом импорта.
   ├─ Из набросков автора: 18 глав
   ├─ Из синтезатора: 5 глав, заполненных на 60%+ (section-3.docx → глава 8)
   ├─ Пробелы: 7 глав без материала
   └─ Конфликт: глава 12 в набросках и фрагмент чата claude.ai пересекаются
✋ Финализируй ROADMAP. Что делать с конфликтом?
📝 [сводит конфликт через /bookbench:resolve, утверждает план из 25 глав]
🤖 ✅ ROADMAP.md, red-thread-keywords.md созданы.
```

### Шаг B-4. Voice profile извлечён автоматически

```
🤖 [book-coordinator] Извлёк voice profile из 12 voice-sample фрагментов:
   - Formality: informal-neutral (выявлено по 47 пассажам)
   - Paragraph length: medium (4-5 предложений в среднем)
   - Sentence variety: mixed
   - Emotional intensity: warm
   - Dash typography: medium
   - Anglicism tolerance: moderate
✋ Подтверждаешь voice profile? (y / поправить / запустить /bookbench:voice build)
📝 [уточняет 1 параметр: anglicism tolerance → strict]
🤖 ✅ voice-profile.md обновлён.
```

> **Ключевое отличие от сценария A.** Голос здесь не строится с нуля — он вытаскивается из ваших же черновиков. Вы корректируете один-два параметра и продолжаете. Полные алгоритмы извлечения — в [`voice-management.md`](voice-management.md) и `skills/voice-builder/SKILL.md`.

### Шаг B-5. Старт главы, где есть импортированный черновик

```
> /bookbench:plan-section 5
🤖 [book-strategist] обнаружил: для главы 5 импортирован черновик из section-3.docx (60% готов).
🤖 sections/05/spec.md создан с пометкой:
   ├─ Режим: integrate-existing-draft
   ├─ Импортированный черновик: sections/05/imported-draft.md (1200 слов)
   └─ Что нужно дополнить: ~40% объёма + проверка против реестра USED EXAMPLES
✋ Утверждаешь?
📝 y
```

### Шаг B-6. Микро-цикл в режиме «дополнения»

```
> /bookbench:write-section 5
🤖 Фаза 2/5: Писатель в режиме from-existing
   ├─ Дополняет 40% объёма
   ├─ Переписывает AI-склонные куски (section-3.docx был частично из claude.ai)
   ├─ Проверяет против USED EXAMPLES — метафора «корабль с грузом» уже использована
   │   в импортированной главе 3, заменяет.
   └─ Hook anti-ai-cliche ловит «погружаемся в мир» в импортированном фрагменте → правит.
   ✅ draft.md создан.
   
   ... (фазы 3, 4, 5 как в сценарии A)
```

### Шаги B-7 и B-8. Финал главы и аудит после нескольких глав

После завершения главы 5 — финальный обзор как в `A-5`. После 5-10 глав — `/bookbench:audit-book` обнаружит специфичные для импорта проблемы (типичны 8-15 ИИ-клише в импортированных кусках чатов и 3-5 неверифицированных утверждений).

---

## Что появилось в папке

После `/bookbench:start` и завершения первой главы:

```
history-of-coffee/
├── CLAUDE.md                          ← инструкции для Claude в этой папке
└── .book/
    ├── PROJECT.md                     ← видение книги
    ├── ROADMAP.md                     ← план 25 глав
    ├── STATE.md                       ← журнал состояния
    ├── config.yaml                    ← количественные параметры
    ├── workflow.md                    ← пресет научпопа
    ├── TUNING-LOG.md                  ← (пусто; заполняется через /bookbench:tune apply)
    ├── REJECTIONS-LOG.md              ← (пусто; заполняется при ручных правках готовых глав)
    ├── UPDATE-LOG.md                  ← (пусто; заполняется при /bookbench:update)
    ├── context/
    │   ├── parameters.md              ← фиксированные решения (P-01, P-02, ...)
    │   ├── voice-profile.md           ← голос автора (заполняется в writer-gate)
    │   ├── glossary.md
    │   ├── red-thread-keywords.md
    │   ├── visual-blacklist.md
    │   └── cross-references.md
    ├── sections/
    │   └── 01/
    │       ├── spec.md
    │       ├── draft.md
    │       ├── factcheck.md
    │       ├── edited.md              ← готовая глава
    │       ├── marketing.md
    │       └── summary.md             ← сводка для context budget будущих глав
    ├── agent-guidelines/
    │   ├── coordinator/
    │   ├── strategist/
    │   ├── writer/
    │   ├── factchecker/
    │   ├── editor/
    │   ├── marketer/
    │   ├── doc-classifier/
    │   ├── doc-synthesizer/
    │   └── tuner/
    ├── agent-memory/
    │   ├── strategist/MEMORY.md
    │   ├── writer/MEMORY.md
    │   ├── editor/MEMORY.md
    │   ├── factchecker/MEMORY.md
    │   └── marketer/MEMORY.md
    ├── .claude/
    │   └── agents/                    ← 9 локальных тел субагентов
    └── .hooks/
        └── anti-ai-cliche-lint.sh
```

Полная схема — в [`architecture.md`](architecture.md).

---

## Если что-то пошло не так в первой сессии

| Симптом | Что делать |
|---------|------------|
| `/bookbench:start` не отвечает или зависает после первого вопроса | Проверить, что Claude Code 2.x; проверить `/bookbench:doctor`; перезапустить сессию (`/clear`) — `/bookbench:start` идемпотентна, продолжит откуда остановился |
| Voice gate сработал «не вовремя» (нет настроения настраивать голос) | Выбрать путь B3 — агент сам предложит за 2-3 минуты на основе уже имеющегося плана. Или путь B2 (`/bookbench:voice build`) — это отдельная сессия, она не сожжёт текущий контекст |
| Фактчекер не нашёл источник на простой факт | Проверить, есть ли у фактчекера WebSearch (`agent-templates/book-factchecker.md` → секция `tools:`). Если есть — возможно, это специфика темы (см. `factchecker/agent-guidelines/trusted-sources.md`). Можно подтвердить тэг `[ASSUMED]` вручную |
| Hook anti-ai-cliche блокирует правомерную фразу | Открыть `.book/agent-guidelines/writer/forbidden-phrases.md`, добавить исключение. Или `/bookbench:tune` — tuner предложит обобщённое правило, если такая ситуация повторилась 3+ раз |
| Стратег предложил странный план книги | Прервать, отредактировать `PROJECT.md` (точнее описать книгу и аудиторию), запустить `/bookbench:plan-book` ещё раз. Стратег идемпотентен — переписывает `ROADMAP.md` |
| Координатор не помнит, на какой главе остановились | `/bookbench:status` — читает `STATE.md`. `/bookbench:resume` — продолжает текущий этап. `/bookbench:next` — даёт умную подсказку |
| Не уверен, что workflow подходит твоему жанру | `/bookbench:workflow:check` — статическая валидация `workflow.md`. Если жанр специфичный — `/bookbench:research-genre <ваш-жанр>` запустит genre-researcher |
| После `/bookbench:write-section` не появилось `marketing.md` | Возможно, маркетолог отключён в `workflow.md > section_loop.params.enable_marketer: false`. Включить — отредактировать файл, перезапустить `/bookbench:write-section:market <N>` (атомарная подкоманда только маркетинговой фазы) |

Расширенный troubleshooting — в [`faq.md`](faq.md), кластер 5 «Troubleshooting» (включая B-14-01..05 как known issues 0.1.0 с workaround).

---

## Куда дальше

- [`section-cycle.md`](section-cycle.md) — что в каждой фазе цикла, как чинить, atomic subcommands
- [`customization.md`](customization.md) — как настроить под себя (config / guidelines / tuner)
- [`voice-management.md`](voice-management.md) — голос подробно: библиотека, перенос между книгами
- [`models-and-subscriptions.md`](models-and-subscriptions.md) — выбор профиля под подписку
- [`faq.md`](faq.md) — типовые вопросы
