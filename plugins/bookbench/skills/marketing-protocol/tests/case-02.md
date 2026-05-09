# Marketing-protocol evaluation case 02: visual-blacklist gate

## Input

A chapter on data flow. Default visual blacklist contains "abstract data
flow", "matrix code rain", "interconnected dots".

## Expected behaviors

- Skill checks every visual motif in the candidate Midjourney prompt.
- Detects the blacklisted motifs.
- Replaces with concrete, in-domain alternatives (e.g., "river splitting into
  irrigation channels", "switchyard at a small power station").
- Audit trail records the substitution.

## Acceptance criteria

- Final prompt does not contain any blacklist motif.
- Audit trail explicitly mentions the substitution.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the blacklist gate at protocol level.
