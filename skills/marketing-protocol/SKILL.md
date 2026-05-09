---
name: marketing-protocol
description: Описывает протокол маркетинговой упаковки готовой главы для агента book-marketer — три варианта заголовка, hook-фраза, Telegram-пост, сниппеты для соцсетей, Midjourney-промпт, реестр уже использованных hook-фраз и визуальных референсов. Используется book-marketer на фазе 6 микро-цикла главы. Включает подмножество анти-ИИ-клише для маркетинговых текстов и механизм visual-blacklist, не дающий повторять метафоры между главами одной книги.
---

# Marketing protocol skill

## When to use

Injected into `book-marketer`. Activated in Phase 6 of the chapter micro-cycle (after editor) when `workflow.md > chapter_loop.enable_marketer: true`. Not active for fiction or academic-monograph genres by default.

## What the marketer produces

Output: `chapters/<N>/marketing.md`. Sections:

1. **Three title variants** — the chapter title that will be tested in social-media posts.
2. **Hook phrase** (≤120 chars) — the one-line emotional grabber.
3. **Annotation (TED-3-act)** — three-paragraph annotation: paradox → idea → memorable close.
4. **Social posts** — one per platform listed in `config.yaml > social_platforms`.
5. **Midjourney prompt** — a visual brief for cover or social card.
6. **Visual references registry update** — list of metaphors used in the post and prompt; appended to `marketer/MEMORY.md`.

## Quantitative parameters

All numerical bounds come from `config.yaml > social_platforms.<platform>` or from the genre skill. The marketing protocol enforces but does not encode them:

- Twitter snippet: 140–150 chars (Q16).
- Telegram post: 1000–2000 chars (Q17).
- Midjourney prompt: 50–100 words (Q18).
- Alternative concepts on creative block: ≥3 (Q19).

## Anti-AI-cliche subset for marketing copy

Marketing copy is held to a relaxed corpus subset — but four patterns remain hard `block` regardless:

- Pattern #18 — emojis-in-prose is `block` for the body of the chapter; for marketing posts emojis are allowed only in `agent-guidelines/marketer/telegram-tone.md` if explicitly enabled.
- Pattern #25 — generic-positive-conclusion (no "BookBench is a powerful framework that transforms…").
- Pattern #34 — AI-summary-sentence (no "X is a revolutionary framework that weaves a tapestry of…").
- Pattern #40 — click-bait (no "Shocking truth…").

The full corpus rules apply; see `skills/anti-ai-cliche/`.

## Visual blacklist mechanism

Every Midjourney prompt is checked against:

1. `.book/context/visual-blacklist.md` — book-wide forbidden metaphors.
2. `.book/agent-guidelines/marketer/visual-blacklist-extras.md` — marketer-specific extras.
3. `.book/.claude/agent-memory/marketer/MEMORY.md > visual_motifs_used` — already-used metaphors for this book.

If a metaphor matches any of the three lists, the marketer must propose a different visual. If three attempts in a row hit the blacklist, the marketer flags `[VISUAL_DEAD_END]` in `marketing.md` and asks the coordinator for human input.

## Procedure for Phase 6

1. Read `chapters/<N>/edited.md`.
2. Read `agent-guidelines/marketer/`, `context/visual-blacklist.md`, `context/target-audience.md`.
3. Read `agent-memory/marketer/MEMORY.md`.
4. Read `chapters/<N-1>/marketing.md` if present (avoid hook-phrase repetition).
5. Generate three title variants; pick the strongest.
6. Generate hook phrase; check against `MEMORY.md > hook_phrases_used` (no exact reuse).
7. Generate TED-3-act annotation.
8. Generate per-platform posts using `config.yaml > social_platforms`.
9. Generate Midjourney prompt; check visual blacklist (three layers).
10. Write `marketing.md`.
11. Update `marketer/MEMORY.md`: append used title variants, hook phrase, visual motifs.

## Tests

- Test 1 — given an edited.md and a `MEMORY.md > hook_phrases_used: ["X is a story about Y"]`, the marketer does not reuse that exact hook phrase.
- Test 2 — given a Midjourney prompt that includes a metaphor from `visual-blacklist.md`, the marketer rewrites the prompt.
- Test 3 — given `enable_marketer: false` (genre = academic-monograph), the marketer is not activated; this is enforced at coordinator level, not skill level.

## Files

This skill has no extra reference files; per-book marketing lives in the book folder.

## Notes

- No time-sensitive content.
- Visual blacklist defaults are per-genre (in `defaults.yaml`), per-book (in `context/visual-blacklist.md`), and per-role (in `agent-guidelines/marketer/visual-blacklist-extras.md`).
