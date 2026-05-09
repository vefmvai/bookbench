# Case 02: Factcheck loop hits the third iteration

## Input

User runs `/book:write-chapter 5`. Coordinator orchestrates strategist →
writer → factchecker. Factchecker returns `factcheck.md` with
`status: revise-required` for the third time in a row (factcheck_iteration_count
becomes 3 after this iteration). Two `[UNVERIFIABLE]` claims remain.

## Expected behaviors

- Coordinator detects the 3-iteration ceiling per Procedure WRITE-CHAPTER step 5.
- Triggers ESCALATE-flow: appends an entry to REJECTIONS-LOG.md with
  `rejection_kind: agent-work` and `pattern_hint: factcheck-loop-exhausted`.
- Calls AskUserQuestion with four choices: (a) hedging, (b) remove the claim,
  (c) provide a source manually, (d) accept with [ASSUMED] tag.
- Does NOT spawn a fourth factchecker call.
- Updates chapter-state.yaml with the appropriate status.

## Acceptance criteria

- REJECTIONS-LOG.md is appended exactly once for this escalation.
- AskUserQuestion is invoked with four explicit choices (a/b/c/d).
- No fourth Task call to factchecker is observed.
- Chapter-state.yaml reflects the escalated status.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Verifies the loop-bounding constitutional rule and the escalation path. Common
failure modes: fourth-call attempt, missing REJECTIONS-LOG entry, choice list
shorter than four.
