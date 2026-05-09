# Anti-AI-cliche evaluation case 12: grandmother test failed

## Pattern under test

Pattern #31 — Grandmother test failed. Level: info (semantic, semantic gate
in editor; hook logs heuristic warnings only).

## Before (AI-generated snippet)

```
Квантовая запутанность — это нелокальное состояние, при котором свойства
системы коррелированы независимо от расстояния между частицами.
```

## After (human-rewritten snippet)

```
Представь две монеты: одну ты подбрасываешь в Москве, другую — в Токио. Если
они "запутаны", то результат на одной монете мгновенно определяет результат
на другой. Расстояние не важно. Это и есть запутанность.
```

## Expected hook reaction

`info` (silent log). The semantic verdict comes from editor's grandmother
test in `humanity-test.md`.

## Why this is the right reaction

Pattern #31 is a semantic check; the regex heuristic flags blocks with many
unfamiliar terms and no anchor, but the actual judgement is the editor's.
Info-level keeps the signal without false positives.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 12. Demonstrates the
hook-vs-checklist division.
