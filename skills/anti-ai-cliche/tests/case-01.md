# Anti-AI-cliche evaluation case 01: journey metaphor

## Pattern under test

Pattern #35 — Journey and immersion metaphors (Russian locale). Level: block.

## Before (AI-generated snippet)

```
В этой главе мы отправимся в увлекательное путешествие в мир методологии и
попробуем погрузиться в её глубины.
```

## After (human-rewritten snippet)

```
Методология начинается с одного решения: автор пишет, фреймворк не пишет за
него. Из этой формулировки складывается всё остальное — давайте посмотрим как.
```

## Expected hook reaction

`block` (exit 2).

## Why this is the right reaction

Pattern #35 from `references/corpus-46-patterns.md` (Russian-locale extension)
catches the journey/immersion metaphor as a strong AI-ism. Block-level because
it disqualifies the chapter opening for popular-science prose.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 1. Common failure: model-suggested
"rewrite" still uses "погрузимся".
