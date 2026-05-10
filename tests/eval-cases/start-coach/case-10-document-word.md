# Case 10 — document_word: формат long-read, финальное сообщение «Лонгрид инициализирован»

> **Покрытие:** D-37 (этап 24) — `document_word` адаптивный для финального сообщения Step 11. Формат `long-read` имеет `document_word_capitalized = "Лонгрид"`, `document_word_gender_suffix = ""`, поэтому Step 11 печатает «Лонгрид инициализирован», не «Книга инициализирована».
>
> **Источник правды:** `defaults.yaml > formats.long-read.document_word*`; `commands/start.md` Step 11 (адаптивный шаблон).

## Setup

- Папка: `/tmp/test-book-longread/`.
- Запуск: `/book:start`.

## Author messages

**Сообщение 1:** «Пишу большую статью про когнитивную нагрузку, страниц на 25, для Substack.»

**На гипотезу формата `long-read`:** «Да, лонгрид.»
**На жанр `popular-science`:** «Да.»
**На audience:** «Substack-аудитория, любители long-form чтения.»
**На addressing_mode:** «вы.»
**Style:** B3 (ничего не приложено).

## Expected behaviour

1. Step 4 завершён: `BOOK_FORMAT=long-read`, `BOOK_GENRE=popular-science`, audience=«Substack-аудитория…», addressing_mode=«вы», style_marker=B3.
2. Step 4b сводка: «Format: long-read (единица работы — часть)». Автор: «Да».
3. Step 5 читает `defaults.yaml > formats.long-read`:
   - `document_word: "лонгрид"`
   - `document_word_capitalized: "Лонгрид"`
   - `document_word_gender_suffix: ""` (мужской род — «инициализирован»)
   - `section_word: "часть"`
4. Step 11 печатает:
   ```
   Лонгрид инициализирован: «Когнитивная нагрузка»
     Формат:      long-read (часть)
     Жанр:        popular-science
     Аудитория:   Substack-аудитория, любители long-form чтения
     Обращение:   вы
     ID в реестре: kognitivnaya-nagruzka-2026-05-10

   Рекомендуемый следующий шаг:
     /book:plan-book   — собрать план часть-ов (через book-strategist).
     /book:status      — посмотреть текущее состояние лонгрида в любой момент.
   ```

## Pass criteria

- ✅ Финальное сообщение Step 11 начинается с «Лонгрид инициализирован» (NOT «Книга инициализирована»).
- ✅ В сообщении используется «лонгрид» (не «книга») в фразе про статус.
- ✅ Section_word = «часть»; в сообщении встречается «план часть-ов» (адаптивный D-31).
- ✅ В STATE.md History строка `format=long-read`.

## Fail criteria

- ❌ Финальное сообщение начинается с «Книга инициализирована».
- ❌ В сообщении используется «глава» вместо «часть».
- ❌ Хардкод старого шаблона `Книга инициализирована: «${BOOK_TITLE}»` сохранился в `commands/start.md`.

## Variant case: format=monograph (gender_suffix="а")

При `BOOK_FORMAT=monograph`:
- `document_word_capitalized: "Монография"`, `gender_suffix: "а"`.
- Step 11: «Монография инициализирована: …».

При `BOOK_FORMAT=article`:
- `document_word_capitalized: "Статья"`, `gender_suffix: "а"`.
- Step 11: «Статья инициализирована: …».

---

*Создан: этап 24, T9.*
