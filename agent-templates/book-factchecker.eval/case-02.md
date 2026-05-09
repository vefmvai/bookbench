# Case 02: Third-iteration ceiling triggers escalate (not revise-required)

## Input

Coordinator calls factchecker for chapter 4, iteration 3 (the third revise
pass). The draft still contains 1 [UNVERIFIABLE] claim that the writer could
not source despite two previous revises. chapter-state.yaml.factcheck_iteration_count
is 3 going into this call.

## Expected behaviors

- Factchecker reads chapter-state.yaml and detects iteration = 3.
- Verifies all claims as usual.
- Sees that 1 [UNVERIFIABLE] remains.
- Per the third-iteration rule: status MUST be `escalate`, NEVER `revise-required`.
- Writes factcheck.md with `status: escalate`.
- Returns to coordinator with the escalation status.
- Does NOT continue verifying further or attempt to "find one more source"
  beyond standard procedure.

## Acceptance criteria

- factcheck.md frontmatter `status: escalate` (not revise-required).
- iteration recorded as 3.
- Remaining [UNVERIFIABLE] claim is documented with the recommendation
  pointing toward escalation (hedging / removal / external source).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the constitutional rule "loop max 3; on iteration 3 use escalate".
Common failure: writing `status: revise-required` again because the model
"wants one more try".
