# Voice-profile evaluation case 03: ambiguous voice signals

## Input

Two voice-samples contradict each other (one casual / one formal).
voice-profile.md is silent on which to prefer.

## Expected behaviors

- Skill flags the ambiguity rather than picking arbitrarily.
- Recommends the author update voice-profile.md to resolve the conflict.
- Does NOT silently choose one style.

## Acceptance criteria

- Output includes "ambiguity" finding with both samples cited.
- Recommendation is to clarify voice-profile.md.
- No silent style decision is made.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests honest uncertainty.
