# Anti-AI-cliche evaluation case 10: clickbait in marketing

## Pattern under test

Pattern #40 — Click-bait formulations. Level: block.

## Before (AI-generated snippet)

```
Шокирующая правда о методологии, которую от вас скрывают: разработчики в
панике!
```

## After (human-rewritten snippet)

```
Эта методика решает 12 проблем, с которыми любой автор сталкивается на
главе 5. Список и почему — внутри.
```

## Expected hook reaction

`block` (exit 2).

## Why this is the right reaction

Pattern #40 catches clickbait formulas ("Вы не поверите", "Шокирующая правда",
"То, что они скрывают"). Never appropriate, even in marketer artefacts.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 10.
