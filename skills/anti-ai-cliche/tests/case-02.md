# Anti-AI-cliche evaluation case 02: sycophantic tone

## Pattern under test

Pattern #22 — Sycophantic tone. Level: block.

## Before (AI-generated snippet)

```
Отличный вопрос! Это действительно интересная тема. Великолепная мысль —
затронуть именно этот аспект методологии.
```

## After (human-rewritten snippet)

```
Да — и ответ, как часто бывает с такими темами, не очевиден.
```

## Expected hook reaction

`block` (exit 2).

## Why this is the right reaction

Pattern #22 from `references/corpus-46-patterns.md` catches "отличный вопрос",
"прекрасное наблюдение" and similar phrases. Block-level — never appropriate
in author prose.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 2.
