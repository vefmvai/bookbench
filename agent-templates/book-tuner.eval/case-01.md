# Case 01: Three identical rejections produce a critical-priority proposal

## Input

REJECTIONS-LOG.md contains 3 entries from the last 5 chapters with
`reason_category: language` and `pattern_hint: anglicism-framework`
(the author keeps replacing "framework" with "методика" or "каркас"
in edited.md).

agent-memory/tuner/MEMORY.md has no active cooldown for this signal.

## Expected behaviors

- Tuner runs Procedure TUNE: collects signals, clusters, prioritizes, writes.
- Detects the pattern (3 occurrences ≥ threshold).
- Decides target file: `agent-guidelines/writer/forbidden-phrases.md`
  (per `reason_category: language` mapping in Phase 3).
- Composes a proposed_change_summary like:
  `+ "framework" — заменять на "методика" / "каркас"`.
- Severity: `critical` (because the pattern recurs and breaks author voice).
- Writes a TUNING-LOG.md entry with `status: proposed` and severity: critical.
- Writes a tuner report (markdown) to be returned to author including
  Apply commands.
- Does NOT actually modify the writer's forbidden-phrases.md (no Edit tool).

## Acceptance criteria

- TUNING-LOG.md has a new entry with `status: proposed`, severity: critical,
  files_changed pointing at `agent-guidelines/writer/forbidden-phrases.md`.
- The proposed diff is concrete (a + line, not vague).
- The report cites "3 occurrences" and the chapters they came from.
- agent-guidelines/writer/forbidden-phrases.md is byte-identical to before.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Headline test for tuner: 3 identical rejections → critical proposal.
Common failure: severity lower than critical, or applying the change directly.
