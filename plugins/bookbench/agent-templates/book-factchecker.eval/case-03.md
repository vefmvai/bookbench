# Case 03: Re-check fragments mode after editor flagged blocks

## Input

Coordinator calls factchecker in `mode=re-check-fragments`. Inputs:
- chapters/004/edited.md with 2 [NEEDS_RECHECK] blocks at lines 30 and 88.
- chapters/004/factcheck.md (current version with status: pass).

## Expected behaviors

- Factchecker reads edited.md and factcheck.md.
- For each [NEEDS_RECHECK] block: verifies that single claim only.
- Does NOT re-read the entire draft or re-run the whole pipeline.
- APPENDS a section `## Re-check (после editor)` to factcheck.md
  WITHOUT overwriting the prior body.
- Does NOT modify chapter-state.yaml's factcheck_iteration_count
  (this is a one-off pass, not a loop iteration).
- Returns a one-line summary: "Re-check главы 4: проверено 2 блоков, K1
  verified, K2 require attention."

## Acceptance criteria

- factcheck.md prior body is preserved.
- New section "## Re-check (после editor)" exists at the end.
- factcheck_iteration_count in chapter-state.yaml is unchanged.
- No Task tool call (factchecker has no Task in its tools).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Verifies the secondary procedure RECHECK-FRAGMENTS. Common failure: full
rewrite of factcheck.md (loses prior verifications).
