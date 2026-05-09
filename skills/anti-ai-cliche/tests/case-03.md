# Anti-AI-cliche evaluation case 03: em-dash overuse with strict typography

## Pattern under test

Pattern #14 — Em dash overuse. Level: info by default; warn or block when
the book sets `dash_strict: true` and uses `dash_type: medium`.

## Before (AI-generated snippet)

```
Система — спроектированная для масштабирования — обрабатывает миллионы
запросов — без сбоев — даже под нагрузкой.
```

## After (human-rewritten snippet)

```
Система обрабатывает миллионы запросов на пике, без сбоев под нагрузкой.
```

## Expected hook reaction

- With `dash_strict: false` → `warn`.
- With `dash_strict: true` and `dash_type: medium` → `block`.

## Why this is the right reaction

Pattern #14 from `references/corpus-46-patterns.md` is parameter-driven via
the book's voice-profile. Default is info; the override mechanism allows
authors to escalate to warn or block.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 3. Tests the parameterised
override mechanism described in § 7.
