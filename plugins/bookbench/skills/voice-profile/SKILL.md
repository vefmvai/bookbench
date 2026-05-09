---
name: voice-profile
description: Помогает агентам book-writer и book-editor откалиброваться под голос автора — читать voice-samples.md и слайдеры параметров перед каждой главой. Задаёт шестипараметрическую модель голоса (формальность, предпочтительная длина абзаца, вариативность предложений, эмоциональная интенсивность, типографика тире, толерантность к англицизмам) и процедуру калибровки писателя в начале главы. Используется book-writer на фазе 2 и book-editor на фазе 4 (проверка связности). Не заменяет реальные voice-сэмплы — это протокол вокруг них.
---

# Voice profile skill

## When to use

Activated by `book-writer` at the start of every section (after spec.md, before drafting) and by `book-editor` during cohesion editing. Both roles read `.book/context/voice-profile.md` and `.book/agent-guidelines/writer/voice-samples.md`; this skill defines _how_ to read them.

## The six-parameter voice model

Every author voice projects onto six parameters that the writer must calibrate at section start:

| Parameter | Range | Default for popular-science |
|-----------|-------|------------------------------|
| Formality | informal — neutral — formal | neutral |
| Paragraph length preference | short (≤300) — medium (300–600) — long (600+) | medium |
| Sentence variety | uniform — mixed — strongly mixed | mixed |
| Emotional intensity | minimal — restrained — vivid | restrained |
| Dash typography | medium dash (–) — long dash (—) | medium |
| Anglicism tolerance | strict (Russian only) — moderate — loose | moderate |

Each value lives in `.book/voice-profile.yaml` (set during `/book:start`) and overrides the genre defaults from `defaults.yaml`.

## Calibration procedure for writer at section start

1. Read `.book/context/voice-profile.md` (prose description plus the six-parameter model).
2. Read `.book/agent-guidelines/writer/voice-samples.md` (≥3 author-written passages of 200–500 words each).
3. For each sample, note which of the six parameters dominate.
4. Read `sections/<N-1>/draft.md` last 2 paragraphs to feel the immediate-prior tone.
5. Mentally fix the calibration before writing the first sentence of `draft.md`.

## Calibration procedure for editor during cohesion edit

1. Read `.book/context/voice-profile.md`.
2. Read 3 random author-written passages from `voice-samples.md`.
3. Read the current `draft.md`.
4. Identify _drift_ — paragraphs that read like a different voice. Mark them in line edit.
5. The editor flags drift but does not rewrite voice unless the spec.md explicitly authorises voice-revise mode (import scenario).

## Voice drift markers

Six classic drift markers (each maps to a humanity-test failure):

1. Sudden shift to formal register in the middle of an informal section.
2. Rule-of-three overuse (every list, every clause, every sentence).
3. Disappearance of hesitation markers ("perhaps", "I am not sure", "this is debatable").
4. Drop in concrete anchors per 1000 chars compared to author samples.
5. Switch to "we" or "the reader will" addresses where the author uses "you" or no address.
6. Appearance of forbidden phrases from `forbidden-phrases.md`.

## Tests

- Test 1 — given samples in informal register and a spec.md for section 5, the writer produces a draft.md that scores within ±1 on the formality parameter against the samples.
- Test 2 — given samples with strong dash-medium discipline, the writer produces a draft.md with no `—` (long dash) characters.
- Test 3 — given samples with vivid emotional intensity, the writer produces a draft.md with at least 3 emotional markers per 5000 chars.

## Files

This skill has no extra reference files. The actual voice content lives in the book folder, not in the plugin.

## Notes

- This skill never carries time-sensitive information.
- Six-parameter model intentionally simple; future versions (0.2+) may extend.
- Tests reference generic placeholders (section 5, samples, etc.) — no time-sensitive author specifics.
