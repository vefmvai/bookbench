# Case 08 — Addressing mode: автор выбирает «вы»

> **Покрытие:** § 4a addressing_mode (D-36, этап 24). Коуч задаёт вопрос с derived_default из `defaults.yaml`, автор подтверждает, значение записывается в `.book/config.yaml > book.addressing_mode`. Шаблоны `addressing-rules.md` копируются в `.book/agent-guidelines/{writer,editor}/`.
>
> **Источник правды:** `lib/start-coach-prompt.md` § 4a; `defaults.yaml > genres.popular-science.addressing_default` = «вы»; `templates/agent-guidelines/{writer,editor}/addressing-rules.md`.

## Setup

- Папка: `/tmp/test-book-addressing/`.
- Запуск: `/bookbench:start`.

## Author messages

**Сообщение 1:** «Пишу научпоп-книгу про сознание для широкой аудитории.» (стандартный путь B1 везде до § 4a).

**На вопрос § 4a:**
> «Окей, обращаемся к читателю на:
>   • «ты» — личное, разговорное;
>   • «вы» — уважительное, нейтральное;
>   • безличное — без прямого обращения;
>   • смешанное — переключаемся.
>
> Значение по умолчанию для жанра «popular-science» и формата «book»: «вы».»

**Автор:** «Давай на «вы», как ты предложил.»

## Expected behaviour

1. Коуч резолвит derived_default:
   - `genres.popular-science.addressing_default` = «вы».
   - Приоритет жанра > формата → derived_default = «вы».
2. Задаёт вопрос со встроенным значением по умолчанию.
3. Автор отвечает «вы».
4. Записывает в `.book.proposed.yaml > book.addressing_mode: "вы"`.
5. Step 4b: сводка содержит «Addressing: вы». Автор: «Да, создавай .book/».
6. Step 6a:
   - Скопировать `templates/agent-guidelines/writer/addressing-rules.md` → `.book/agent-guidelines/writer/addressing-rules.md`. Заменить `${ADDRESSING_MODE}` на «вы».
   - То же для editor.
7. Step 7: `.book/config.yaml > book.addressing_mode: "вы"`.

## Pass criteria

- ✅ `.book/config.yaml > book.addressing_mode = "вы"`.
- ✅ `.book/agent-guidelines/writer/addressing-rules.md` существует и содержит «Текущий режим: addressing_mode: вы» (плейсхолдер заменён).
- ✅ `.book/agent-guidelines/editor/addressing-rules.md` аналогично.
- ✅ `.book/STATE.md` History содержит `addressing=вы`.

## Fail criteria

- ❌ Коуч пропустил вопрос § 4a (например, потому что «и так понятно»).
- ❌ `.book/config.yaml > book.addressing_mode = ""` (пустая строка).
- ❌ Коуч сам поставил «ты» без явного выбора автора (на основе сленга в первом сообщении).
- ❌ Файлы `addressing-rules.md` отсутствуют.

## Special case: derived_default fallback

Если автор изменил жанр на `fiction` (`fiction.addressing_default = ""`), а формат на `long-read` (`long-read.addressing_default = ""`), оба пусты:
- derived_default = «вы» (общий fallback по § 4a § 0 коуч-промпта).

Если автор изменил формат на `dissertation` (addressing_default = «безличное»), а жанр на `monograph` (addressing_default = «безличное»):
- derived_default = «безличное» (приоритет жанра).

---

*Создан: этап 24, T9.*
