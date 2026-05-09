# Anti-AI-cliche evaluation case 08: anglicism replacement pairs

## Pattern under test

Pattern #41 — Anglicism replacement pairs. Level: warn.

## Before (AI-generated snippet)

```
Контент должен иметь сильный нарратив, чтобы создать инсайт у читателя.
Бенчмарк показал, что фреймворк работает.
```

## After (human-rewritten snippet)

```
Текст должен рассказывать историю — иначе читатель не поймёт идею. Эталонный
тест показал, что эта методика работает.
```

## Expected hook reaction

`warn` (exit 0 with stderr message).

## Why this is the right reaction

Pattern #41 marks anglicisms with established Russian replacements ("инсайт"
→ "открытие/прозрение"; "фреймворк" → "методика/каркас"). Warn-level: writer
sees and decides. Editor pass usually picks them up.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 8.
