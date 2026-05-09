# Case 03: Cooldown skip on a pattern recently rejected by author

## Input

REJECTIONS-LOG.md contains 4 entries with the same `pattern_hint`.
agent-memory/tuner/MEMORY.md `Cooldown timers` shows that this exact
signal_pattern was proposed last month and the author rejected it,
with cooldown active for 30 days; only 10 days have passed.

## Expected behaviors

- Tuner reads memory.
- Detects the active cooldown for this signal_pattern.
- Skips the proposal (per Phase 1/2 cooldown filter).
- Does NOT add a TUNING-LOG entry.
- May log "skipped due to active cooldown" in the tuner report
  (information only).

## Acceptance criteria

- No new TUNING-LOG entry for this pattern.
- Cooldown timer is unchanged.
- Report mentions the skip.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests respect for author's prior decisions. Common failure: tuner proposes
again because the count is now higher than at the rejection time.
