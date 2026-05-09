---
name: anti-ai-cliche
description: Распознаёт 46 типовых паттернов LLM-сгенерированного текста в русскоязычной нон-фикшн прозе и сигнализирует агентам book-writer и book-editor, когда артефакт выглядит ИИ-сгенерированным. Даёт три слоя защиты — встроенное знание паттернов в модели, post-write hook-скрипт и семантический тест человечности плюс «бабушкин тест». Используется агентом book-writer на фазе 2 микро-цикла и book-editor на фазе 4 (плюс skill-режимы). Включает корпус из 34 англоязычных паттернов, 12 специфичных для русского, двенадцать eval-кейсов для регрессионного тестирования и механизм переопределений через per-role forbidden-phrases.md.
---

# Anti-AI-cliche skill

## When to use

This skill is injected into `book-writer` and `book-editor` and consulted whenever they touch section prose (`draft.md`, `edited.md`, `marketing.md`). It is the semantic layer of the three-tier defence; the mechanical layer is the post-tool-use hook script and the override layer is in `.book/agent-guidelines/<role>/forbidden-phrases.md`.

Activate this skill at three moments in the section micro-cycle:

1. Phase 2 — writer self-check after each 5000 chars (humanity test questions 1–5).
2. Phase 4 — editor double-pass audit before producing `edited.md`.
3. Phase 5 — when running editor in skill-mode `anti-cliche-deep` for an extra audit.

## Architecture — three layers

| Layer | What it catches | What it does not catch |
|-------|-----------------|------------------------|
| Skill (this file) | Principles the model can remember when generating: do not lecture; do not promise; do not invent personal experience. | Patterns the model itself does not flag in its own output. |
| Hook (`templates/hooks/anti-ai-cliche-lint.sh`) | Mechanical regex hits: em-dash overuse, sycophantic tone, click-bait phrases, "as of my last training". | Semantic defects (no anchor for an abstract claim). |
| Checklist (humanity test, grandmother test) | Semantic defects: voice drift, lack of hesitation markers, signposting, mechanically-symmetric sections. | Mechanical regex hits. |

Each layer covers the blind spot of the previous one.

## The 46 patterns — compact reference

Full corpus with examples, before/after pairs and exception rules: `references/corpus-46-patterns.md` (English-source corpus) and `references/russian-specific-12.md` (the 12 Russian-language additions, patterns 35–46).

By reaction level:

- `block` (12 patterns): vague-attribution-without-citation, emojis-in-prose, collaborative-communication, knowledge-cutoff-disclaimer, sycophantic-tone, generic-positive-conclusion, persuasive-authority-trope, AI-summary-sentence, journey-metaphor, secret-revelation, math-formulas-in-pop-sci, fake-personal-experience, click-bait.
- `warn` (28 patterns): undue-emphasis, notability-coverage, superficial-ing-endings, promotional-language, challenges-and-prospects-outline, AI-vocabulary, copula-avoidance, negative-parallelism, rule-of-three-overuse, elegant-variation, false-ranges, passive-subjectless, boldface-overuse, inline-header-vertical-list, filler-phrases, excessive-hedging, hyphenated-pair-overuse, signposting, fragmented-headers, anglicism, redundant-structure, generic-titles, anglicism-pairs, marketing-positive-adjective, excessive-logicality, visual-blacklist-marketing.
- `info` (6 patterns): em-dash-overuse (parameter), title-case-headings, curly-quotation-marks, grandmother-test-failed, dash-type-mismatch, symmetric-section-structure.

## Tests before submission

### Humanity test (seven questions)

Apply after writing or editing the main artefact, before updating MEMORY.md.

1. Can this be said out loud? Read the first and last paragraphs mentally; if any sounds like Wikipedia, a press release, or a corporate document — rewrite.
2. Is there a concrete number, name, or date at least once per 2 KB? Generic paragraphs without anchors are an LLM marker.
3. Is there at least one unexpected thought or pivot? LLM-generated text trends toward predictable logic.
4. Does the author's voice sound, or "the assistant's voice"? Compare against `voice-profile.md`.
5. Is there at least one moment where the author hesitated or doubted? Constant certainty is an LLM marker.
6. Can the first or last sentence of the section be removed without loss of meaning? If yes, remove it (this is signposting, semantic version).
7. (Editor only) Is there at least one moment where the author bends the methodology? Mechanical adherence is an LLM marker.

If two or more answers are "no" or "uncertain" — rewrite the affected passages.

### Grandmother test

Take one paragraph that introduces a new term. Imagine an educated but non-specialist reader (literature teacher, accountant, doctor in a different field).

1. Will they understand the term without reaching for a search engine?
2. Is there an anchor to something familiar to them — a household analogy, a known event, a familiar object?
3. If a term was introduced, was it explained _before_ first technical use?

If "no" to any one — rewrite. Density rule: one term equals one anchor; two terms in one paragraph means two anchors.

## Override mechanism

Per-book and per-role overrides live in `.book/agent-guidelines/<role>/forbidden-phrases.md`. Format:

```
pattern_<id>:
  level: block|warn|info
```

Per-section overrides go into `sections/<N>/spec.md` frontmatter under `anti_cliche_overrides:`.

## Hook integration

The mechanical layer is the hook script `templates/hooks/anti-ai-cliche-lint.sh` (copied to `.book/.hooks/` at `/book:start`). It runs PostToolUse on `Write|Edit` for section artefacts. Reaction policy:

- `block` (exit 2) — Write is cancelled; the model rewrites.
- `warn` (exit 0 with stderr) — Write proceeds; the model sees a warning and decides.
- `info` (exit 0 silently) — logged to `.book/.hooks/anti-ai-cliche-occurrences.log` for tuner analysis.

## Files

- `references/corpus-46-patterns.md` — full English-source corpus (34 patterns).
- `references/russian-specific-12.md` — the 12 Russian-specific patterns (#35–46) with regex.
- `tests/case-01.md` … `tests/case-12.md` — twelve evaluation cases (skeletons; full content in stage 14).

## Evaluation cases (twelve)

Test cases live in `tests/case-NN.md`. Each case has a `before` snippet, an `after` snippet and an expected hook reaction. Stage 14 expands these into runnable evaluations.

## Notes

- Russian text uses ёлочки `«»` as default quotation marks (not curly quotes); the curly-quotes pattern is `info`-level only.
- Em-dash policy is parameter-driven (`voice-profile.md > typography.dash_type: medium|long`).
- Marketer artefacts (`marketing.md`) get a relaxed corpus subset — see `marketing-protocol`.
