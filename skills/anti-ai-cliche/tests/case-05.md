# Anti-AI-cliche evaluation case 05: generic positive conclusion

## Pattern under test

Pattern #25 — Generic positive conclusion. Level: block.

## Before (AI-generated snippet)

```
В заключение, эта методика — мощный инструмент, который трансформирует то,
как авторы пишут книги, прокладывая путь к новой эре сотрудничества человека
и ИИ.
```

## After (human-rewritten snippet)

```
Через три месяца использования этой методики я заметил странное: скучная
файловая структура оказалась главной фичей. Не "субагенты", не "методология"
— а именно факт, что состояние лежит в markdown.
```

## Expected hook reaction

`block` (exit 2).

## Why this is the right reaction

Pattern #25 catches "в заключение, X — это мощный инструмент ...", a
recognisable LLM closing style. Never appropriate.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 5.
