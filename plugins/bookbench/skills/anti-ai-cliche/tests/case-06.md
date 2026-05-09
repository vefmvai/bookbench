# Anti-AI-cliche evaluation case 06: knowledge-cutoff disclaimer

## Pattern under test

Pattern #21 — Knowledge-cutoff disclaimer. Level: block.

## Before (AI-generated snippet)

```
На момент моих данных, эта методика активно использовалась крупными
компаниями.
```

## After (human-rewritten snippet)

```
По состоянию на октябрь 2024, как минимум три Fortune 500 компании запускали
пилоты (источник: их публичные блоги).
```

## Expected hook reaction

`block` (exit 2).

## Why this is the right reaction

Pattern #21 catches LLM-style disclaimers ("На момент моего обучения",
"По состоянию на дату моих данных"). Never appropriate in authored prose.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 6.
