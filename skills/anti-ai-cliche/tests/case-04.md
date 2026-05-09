# Anti-AI-cliche evaluation case 04: vague attribution without citation

## Pattern under test

Pattern #5 — Vague attributions and weasel words. Level: block.

## Before (AI-generated snippet)

```
Исследования показывают, что регулярные перерывы повышают продуктивность
на 40%, эксперты утверждают, что когнитивной системе нужно время на
консолидацию.
```

## After (human-rewritten snippet)

```
Boice (1990) tracked 27 academics for 10 weeks; daily writers produced
3.5–9× more than binge writers. DOI: 10.1016/0005-7967(89)90144-7.
```

## Expected hook reaction

`block` (exit 2).

## Why this is the right reaction

Pattern #5 catches "research shows ..." / "experts say ..." style claims
without an attached source. Block-level because it pretends to authority
without giving the reader anything verifiable.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Source: `anti-ai-cliche-module.md` § 8 case 4.
