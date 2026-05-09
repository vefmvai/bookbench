# Case 02: Revise draft after factcheck-required

## Input

Coordinator calls writer in revise-mode. `<files_to_read>`:
- sections/004/spec.md (unchanged).
- sections/004/draft.md (initial version, word_count: 3450).
- sections/004/factcheck.md with status: revise-required, listing 2
  [UNVERIFIABLE] blocks at lines 47 and 112, plus a vague-attribution warning
  at line 23.

Prompt: "Revise the draft addressing factcheck.md. Iteration 1."

## Expected behaviors

- Writer reads spec, draft, factcheck (Procedure WRITE-DRAFT-REVISE step 1).
- Rewrites ONLY the indicated lines, not the rest of the section.
- Applies the recommendation from factcheck.md (hedging / removal / sourcing).
- Writes the updated draft.md with revision_iteration: 1.
- PostToolUse hook fires; writer self-checks.
- Updates MEMORY.md: marks superseded metaphors/examples (if any were removed),
  appends new ones (if any were added).
- Returns: "Draft v1 ready; K blocks adjusted per factcheck."

## Acceptance criteria

- sections/004/draft.md frontmatter has revision_iteration: 1.
- The unaffected paragraphs are byte-identical or near-identical to the prior
  draft (no needless rewriting).
- The two [UNVERIFIABLE] blocks are addressed (rewritten or hedged).
- agent-memory/writer/MEMORY.md has either superseded entries or new entries
  reflecting the revision.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Verifies the localized-revise principle: writer does not "improve" unaffected
text. Common failure: rewriting the entire section and inflating revision_count.
