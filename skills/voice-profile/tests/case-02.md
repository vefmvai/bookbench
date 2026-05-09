# Voice-profile evaluation case 02: writer's draft drifts from voice

## Input

`voice-profile.md` says the author prefers short, declarative sentences (≤15
words) and avoids semicolons. A draft has long compound sentences with
semicolons throughout.

## Expected behaviors

- Skill notices the drift.
- Recommends concrete edits (split sentences, replace semicolons with periods).
- Does NOT impose new style preferences not in voice-profile.md.

## Acceptance criteria

- Edits are concrete (line-level recommendations).
- No new preferences invented beyond voice-profile.md.
- The voice profile attributes referenced are quoted verbatim.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests adherence to documented voice rather than extrapolating.
