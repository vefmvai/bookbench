# Anti-AI-cliche evaluation case 07: math formulas in popular-science

## Pattern under test

Pattern #37 — Math formulas and code in popular-science. Level: block (when
genre parameter `forbid_math_formulas: true`); else `info`.

## Before (AI-generated snippet)

```
Внимание (attention) вычисляется по формуле:
$$\text{Attention}(Q, K, V) = \text{softmax}(QK^T / \sqrt{d_k}) V$$
На Python это:
    attn = softmax(Q @ K.T / sqrt(d)) @ V
```

## After (human-rewritten snippet)

```
Внимание — это голосование. Каждое слово в предложении смотрит на соседей и
решает: чей голос мне сейчас важнее. Эти голоса — числа от 0 до 1; они
складываются в новое значение слова.
```

## Expected hook reaction

`block` (exit 2) for popular-science genre. `info` for academic-monograph
genre (where formulas are expected).

## Why this is the right reaction

Pattern #37 is genre-parameter-driven. For popular-science the rule
`forbid_math_formulas: true` blocks LaTeX and code blocks; for
academic-monograph it relaxes.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 7. Tests genre-aware
parameterisation.
