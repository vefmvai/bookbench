# Anti-AI-cliche evaluation case 09: symmetric section structure

## Pattern under test

Pattern #44 — Symmetric section structure. Level: info (semantic check, hook
logs only; full evaluation in editor's humanity test).

## Before (AI-generated snippet)

```
**Метод 1: backpropagation.** Суть: обратное распространение. Преимущество:
универсальность. Пример: GPT.

**Метод 2: reinforcement learning.** Суть: обучение с подкреплением.
Преимущество: автономия. Пример: AlphaGo.

**Метод 3: federated learning.** Суть: распределённое обучение.
Преимущество: приватность. Пример: Google Keyboard.
```

## After (human-rewritten snippet)

```
Backpropagation — это история про учителя с указкой: ошибся — получи по
рукам, исправляй веса. RL — это история про щенка: попробуй, упадёт, повтори,
на десятый раз сядет ровно. Federated learning — это про телефон, который
учится у тебя дома и не отправляет твои данные обратно.
```

## Expected hook reaction

`info` (exit 0; logged silently to .book/.hooks/anti-ai-cliche-occurrences.log).

## Why this is the right reaction

Pattern #44 catches mechanically-symmetric paragraph structures via heuristic
regex; semantic verdict is left to the editor's humanity test (question 7).
Info-level keeps the signal without disrupting the writer.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 9.
