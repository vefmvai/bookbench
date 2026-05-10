# Case 06 — Step 4b gate: автор отвечает «поправь Genre»

> **Покрытие:** Step 4b шлюз подтверждения (D-38, этап 24). Автор смотрит сводку перед развёртыванием `.book/`, не соглашается с одним измерением (genre), коуч возвращается в § 3, обновляет `.book.proposed.yaml`, показывает сводку заново.
>
> **Источник правды:** `commands/start.md` Step 4b; `lib/start-coach-prompt.md` § 0 узкое MAY (трёх условий).

## Setup

- Папка: `/tmp/test-book-step4b/`. Пустая.
- Запуск: `/book:start`.

## Author messages

**Сообщение 1:**

> «Пишу научпоп-книгу про мозг для широкой аудитории, в нейтральном тоне, обращаюсь на «вы». Никаких файлов нет.»

(Сводное описание <200 знаков, текстовое; теоретически узкое MAY § 0 могло бы сработать — НО автор обязан подтвердить отдельно по каждому измерению.)

## Expected behaviour

1. **Step 4** — коуч формирует одну сводную гипотезу: format=`book`, genre=`popular-science`, audience=«широкая аудитория», addressing_mode=«вы», voice_path=`B3`. Получает «да» по каждому из 5 измерений отдельно (узкое MAY условие (в)).

2. **Step 4b** — Write `.book.proposed.yaml`:
   ```yaml
   proposed_at: <ISO>
   book:
     title: "Мозг для всех"
     format: book
     genre: popular-science
     audience: "широкая аудитория"
     addressing_mode: "вы"
     voice_path: B3
     ...
   ```
   Показывает сводку. `AskUserQuestion` с опциями: `Да, создавай .book/` / `Поправь <X>` / `Отмена`.

3. **Автор отвечает: «Поправь Genre»** — потому что хочет «narrative-non-fiction», а не «popular-science».

4. Коуч **возвращается в § 3** (genre), показывает гипотезу: «narrative-non-fiction подходит, потому что…». Автор соглашается.

5. **Step 4b повторно** — обновлённый `.book.proposed.yaml` (genre заменён). Сводка показывается снова. Автор: «Да, создавай .book/».

6. **Step 5+** — `.book/` разворачивается. `.book.proposed.yaml` удаляется на Step 9a.

## Pass criteria

- ✅ `.book/` создан только после второго прохождения Step 4b.
- ✅ `.book/config.yaml > book.genre = "narrative-non-fiction"` (не «popular-science»).
- ✅ `.book.proposed.yaml` отсутствует после Step 9a.
- ✅ Финальное сообщение Step 11: «Книга инициализирована: «Мозг для всех»» (используется `formats.book.document_word_capitalized + document_word_gender_suffix`).
- ✅ STATE.md содержит ровно одну запись `/book:start — initialised` (не дублируется на retry в § 3).

## Fail criteria

- ❌ `.book/` создан на первом проходе Step 4b (без ожидания «Да, создавай»).
- ❌ `genre = "popular-science"` сохранён вопреки явной правке.
- ❌ `.book.proposed.yaml` остался на диске после Step 9a.

---

*Создан: этап 24, T9.*
