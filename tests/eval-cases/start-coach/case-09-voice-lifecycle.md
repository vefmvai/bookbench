# Case 09 — Voice profile lifecycle: автор скидывает черновик книги

> **Покрытие:** voice-profile lifecycle (D-34, этап 24). Автор приложил черновик статьи (большой текст в авторском стиле, но НЕ отдельный voice-profile.md). Коуч НЕ создаёт `voice-profile.md` со `status: confirmed`. Тексты попадают в `.book/inputs/staged-voice-samples/`, не в `.book/agent-guidelines/writer/voice-samples.md`.
>
> **Источник правды:** `lib/voice-profile-lifecycle.md`; `lib/sacred-policy.md` правила 1 и 2; `lib/start-coach-prompt.md` § 5 ветка B2-pending; § 6 пункт 6 (без автозаписи).

## Setup

- Папка: `/tmp/test-book-spiral-voice/`.
- Файл `spiral-draft.md` приложен — большой текст ~3000 слов в авторском стиле (имитирует черновик статьи «Спираль» из live-теста).
- Запуск: `/bookbench:start`.

## Author messages

**Сообщение 1:** «Пишу статью-манифест про развитие циклами. Скинул черновик — это то, что у меня уже есть.» (Файл `spiral-draft.md` приложен.)

**Step 4 § 6 (auto-import) сработал** → classifier классифицирует `spiral-draft.md` как `voice-samples` (текст в авторском стиле + некоторая аудитория signals).

**Коуч должен задать вопрос (по § 5 ветка B2-pending):**
> «Я нашёл в импорте текст в твоём стиле (~3000 слов). Это черновик / готовое-образец / просто пример?»

**Автор отвечает:**
> «Это черновик! Это как раз то, что мы будем переделывать. Я НЕ хочу, чтобы ты брал это как образец голоса.»

## Expected behaviour

1. Step 4a: classifier сохранил текст в `${CLAUDE_PLUGIN_DATA}/staging/<session-id>/spiral-draft.md`.
2. Коуч **НЕ извлекает 6 параметров voice-profile** из текста.
3. Коуч **НЕ помечает style_marker как B1**, не записывает `voice-profile.md`.
4. Коуч задаёт вопрос про класс текста.
5. После ответа «черновик»:
   - `STYLE_MARKER = B2-pending`.
   - Step 6a: текст переносится в `.book/inputs/staged-voice-samples/spiral-draft.md` (NOT `.book/agent-guidelines/writer/voice-samples.md`!).
   - Frontmatter:
     ```yaml
     ---
     status: staged
     created_by: book-classifier
     requires_confirmation: true
     source_kind: imported_voice_samples
     ---
     ```
6. **НИГДЕ** не создаётся `.book/context/voice-profile.md` (без `.draft`!) — это запрет D-34.
7. Step 11 финальное сообщение содержит `${VOICE_BLOCK}`: «Образцы голоса в `.book/inputs/staged-voice-samples/`. Перед первой главой — `/bookbench:voice-build --from-staged`.»
8. Затем автор запускает `/bookbench:write-section 1` (после `/bookbench:plan-book + /bookbench:plan-section 1`):
   - book-writer Voice gate срабатывает: `voice-profile.md` отсутствует, есть только staged-voice-samples.
   - Возвращает `voice_pending` со ссылкой на `/bookbench:voice-build --from-staged`.

## Pass criteria

- ✅ `.book/context/voice-profile.md` (без суффикса `.draft`) НЕ существует ни на каком этапе.
- ✅ `.book/agent-guidelines/writer/voice-samples.md` пуст или отсутствует (стартовый шаблон без переноса staged).
- ✅ `.book/inputs/staged-voice-samples/spiral-draft.md` существует со `status: staged`, `requires_confirmation: true`.
- ✅ Финальное сообщение Step 11 предупреждает про `/bookbench:voice-build --from-staged`.
- ✅ book-writer на write-section 1 возвращает `voice_pending`.

## Fail criteria

- ❌ `.book/context/voice-profile.md` создан со `status: confirmed` или без поля status.
- ❌ Текст автоматически перенесён в `.book/agent-guidelines/writer/voice-samples.md` без явного «готовое / образец» от автора.
- ❌ `STYLE_MARKER = B1-confirmed` записан в реестр (это превращает черновик в авторитетный voice).
- ❌ Коуч извлёк 6 параметров voice-profile (formality / paragraph length / …) из текста.

---

*Создан: этап 24, T9. Соответствует контрольному сценарию «Спираль» (T10) пункт 6, 7.*
