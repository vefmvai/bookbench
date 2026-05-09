# Factcheck-protocol evaluation case 01: claim with a verified source

## Input

Draft contains: "Photosynthesis converts about 1% of incoming sunlight into
chemical energy in most plants." Trusted-sources includes a science
encyclopedia entry that confirms this number.

## Expected behaviors

- Skill helps factchecker decide claim provenance.
- Verifies the claim against the trusted source (or via WebSearch fallback).
- Tags the claim `[VERIFIED]` with the source link.

## Acceptance criteria

- Claim labeled `[VERIFIED]`.
- Source link present and resolvable.
- Tag chosen exactly per `claim-tags-rules.md`.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the [VERIFIED] tagging path.
