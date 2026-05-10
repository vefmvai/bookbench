# Case 07 — B3 ветка: genre pending до ресёрча

> **Покрытие:** ветка B3 § 3 коуч-промпта (D-35, этап 24). Автор не соглашается ни на ресёрч сейчас, ни на ближайший пресет — выбирает «отложу ресёрч на следующую сессию», получает sentinel `genre: pending` в `.book/config.yaml`.
>
> **Источник правды:** `lib/start-coach-prompt.md` § 3 ветка B3-pending; `commands/{plan-book,plan-section,write-section}.md` Step 3 — guard на pending.

## Setup

- Папка: `/tmp/test-book-spiral-pending/`.
- Запуск: `/book:start`.

## Author messages

**Сообщение 1:**

> «Пишу что-то типа манифест-эссе про спиральную модель развития. Это не научпоп — там нет популярного объяснения чего-то известного. Это и не диссертация. Что-то своё.»

**На гипотезу формата** (например, `long-read`): «Да, лонгрид».

**На гипотезу жанра** (`popular-science` как ближайший — но автор отвергает):
> «Нет, это не научпоп. Тут нет научных исследований, это философское эссе.»

(Все остальные пресеты тоже не подходят.)

**На предложение трёх вариантов (research / pending / closest):**
> «Не сейчас, я хочу сначала развернуть скелет книги. Ресёрч жанра проведу в следующей сессии. Оставь pending.»

## Expected behaviour

1. § 3 ветка B2/B3 предложила три пути. Автор выбрал (б) — pending.

2. Step 4b сводка: «Genre: pending (отложен — потребует /book:research-genre)». Автор: «Да, создавай .book/».

3. Step 6:
   - `.book/` развёрнут.
   - **НЕ скопированы** жанровые гайдлайны из `defaults.yaml > genres.<X>` в `.book/agent-guidelines/<role>/`. Стартовые шаблоны без жанровой надстройки.
   - Создан `.book/context/genre-pending.md` со stub-frontmatter:
     ```yaml
     ---
     status: pending
     created_by: book-coordinator-coach
     pending_reason: "<reason>"
     ---
     ```

4. Step 7: `.book/config.yaml > book.genre: pending`, `book.genre_pending_reason: "..."`.

5. Step 8: `.book/STATE.md` содержит строку `genre: pending — required before /book:plan-book`.

6. Step 11: финальное сообщение содержит блок `${PENDING_BLOCK}` — «Жанр в статусе pending. Запусти `/book:research-genre <slug>` перед `/book:plan-book`.»

7. **Затем автор пробует `/book:plan-book` без research-genre:**
   - Команда читает `.book/config.yaml > book.genre`.
   - Видит `pending` → блокируется с exit 2.
   - Сообщение: «ERROR: жанр в .book/config.yaml — pending или не задан. Запусти `/book:research-genre <slug>` …».

## Pass criteria

- ✅ `.book/agent-guidelines/writer/forbidden-phrases.md` пустой (без жанрового списка).
- ✅ `.book/context/genre-pending.md` существует со `status: pending`.
- ✅ `.book/config.yaml > book.genre` равно `pending`.
- ✅ `.book/STATE.md` содержит строку `genre: pending — required before /book:plan-book`.
- ✅ `/book:plan-book` exit 2 с сообщением про research-genre.
- ✅ `/book:plan-section` и `/book:write-section` тоже exit 2.

## Fail criteria

- ❌ В `.book/agent-guidelines/writer/forbidden-phrases.md` появились запрещённые фразы научпопа (значит, агент скопировал жанровые гайдлайны).
- ❌ `book.genre = "popular-science"` или другой ненулевой slug.
- ❌ `/book:plan-book` запустился и попытался планировать книгу.

---

*Создан: этап 24, T9.*
