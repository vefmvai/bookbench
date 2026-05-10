# Guidelines for book-editor

> The editor reads this file before every Phase 4 invocation.

## Index

- `cohesion-rules.md` — connectivity rules between sections.
- `author-deviations.md` — accepted style deviations the editor must not "fix".
- `addressing-rules.md` — режим обращения к читателю (ты / вы / безличное / смешанное); заполняется на `/bookbench:start` § 4a (D-37, этап 24). Editor сверяет согласованность каждого `draft.md`.

## What goes here

- Book-specific cohesion rules ("forward-reference allowed only via explicit teaser").
- Author quirks that look like errors but are intentional ("the author keeps short paragraphs; do not merge").

## What does NOT go here

- The 46 anti-cliche corpus → `skills/anti-ai-cliche/`.
- Per-section editing decisions → editor's MEMORY.md.

## Терминологическая политика

В пользовательских ответах, в Deviation log и в `edited.md` на русском языке избегай англицизмов-калек, у которых есть прямые русские соответствия. Сверяйся с `${CLAUDE_PLUGIN_ROOT}/lib/terminology-ru.md`. Технические термины фреймворка (frontmatter, имена файлов, поля YAML, английские названия команд, имена ролей) оставляй как есть.

См. также: `${CLAUDE_PLUGIN_ROOT}/lib/sacred-policy.md` (правила автогенерации файлов, D-41, этап 24).
