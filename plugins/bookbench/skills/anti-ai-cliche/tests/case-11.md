# Anti-AI-cliche evaluation case 11: excessive hedging

## Pattern under test

Pattern #24 — Excessive hedging. Level: warn.

## Before (AI-generated snippet)

```
Это, возможно, потенциально может быть полезно в некоторых случаях, хотя,
вероятно, могло бы зависеть от контекста.
```

## After (human-rewritten snippet)

```
Полезно в трёх случаях. Бесполезно в одном. Попробуй.
```

## Expected hook reaction

`warn` (exit 0 with stderr).

## Why this is the right reaction

Pattern #24 catches stacks of hedging words. One "возможно" is fine; chains
("возможно, потенциально", "вероятно, наверное") are an LLM marker.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 11.
