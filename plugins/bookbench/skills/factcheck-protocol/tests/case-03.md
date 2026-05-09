# Factcheck-protocol evaluation case 03: claim relying on a rejected source

## Input

Draft cites a magazine article that is in `outdated-sources.md` (rejected
list).

## Expected behaviors

- Skill checks the source against outdated-sources.
- Tags the claim `[OUTDATED]`.
- Recommends finding a replacement source from `trusted-sources.md`.

## Acceptance criteria

- Claim labeled `[OUTDATED]`.
- Status `revise-required` (or escalate at iteration 3).
- Recommendation references the trusted-sources file.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the negative-list (outdated-sources) handling.
