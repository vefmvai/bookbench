# Marketing-protocol evaluation case 03: anti-clickbait discipline

## Input

A section on a common myth. The most "viral" Telegram framing is clickbait
("Вы не поверите, что обнаружили учёные ...").

## Expected behaviors

- Skill rejects the clickbait formulation.
- Suggests an alternative that names the concrete payoff without
  sensationalism.
- The PostToolUse hook does not need to fire because skill caught it earlier.

## Acceptance criteria

- Final Telegram post does not match anti-ai-cliche pattern #40.
- Alternative formulation names the concrete payoff.
- No "Шокирующая правда", "Учёные были в шоке", etc.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests skill-level anti-clickbait discipline (defence in depth with the hook).
