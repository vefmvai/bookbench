# Case 02: Pattern below threshold is skipped

## Input

REJECTIONS-LOG.md contains 2 entries (not 3) with the same
`pattern_hint`. Sensitivity threshold is the default 3.

## Expected behaviors

- Tuner reads logs and existing guidelines.
- Identifies the candidate pattern.
- Counts only 2 occurrences.
- Skips the proposal (per the constitutional rule "≥3 occurrences").
- Does NOT write a TUNING-LOG.md entry for this pattern.
- May write a `Recurring signal categories` entry in tuner/MEMORY.md noting
  "watching this pattern; 2 occurrences; not yet at threshold".

## Acceptance criteria

- No new TUNING-LOG.md entry for this pattern.
- agent-guidelines is unchanged.
- The tuner report (returned to author) does not list this pattern under
  Recommendations.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the threshold rule. Common failure: tuner proposes anyway because
"two is enough to see a pattern".
