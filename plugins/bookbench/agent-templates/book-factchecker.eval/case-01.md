# Case 01: Initial factcheck pass with mixed claim outcomes

## Input

Coordinator calls factchecker for section 4 (initial pass, iteration 0).
sections/004/draft.md contains:
- 4 numerical claims (e.g. "plants convert about 1% of incoming light").
- 2 historical attributions ("Calvin discovered the cycle in 1950").
- 1 vague attribution ("studies show that ...").
- 0 outdated-source citations.

Guidelines provide a trusted-sources list including major science encyclopedias.
agent-memory/factchecker/MEMORY.md has 3 prior verified sources, 0 cross-section
inconsistencies.

## Expected behaviors

- Reads guidelines (trusted-sources, outdated-sources, claim-tags-rules) via
  index-driven protocol.
- Reads draft.md, spec.md, common-misconceptions.md, own MEMORY.md.
- Determines iteration = 0 (initial pass).
- Extracts all factual claims with line numbers.
- Verifies each claim using memory first, then WebSearch as fallback.
- Tags claims: most VERIFIED/CITED, the vague-attribution gets [UNVERIFIABLE]
  and is logged in Vague-attributions.
- Decides status: revise-required (because at least 1 [UNVERIFIABLE] exists).
- Writes sections/004/factcheck.md with frontmatter, claims tagged, vague
  list, recommendation for the writer.
- Updates factchecker/MEMORY.md.

## Acceptance criteria

- sections/004/factcheck.md has frontmatter with status, iteration: 0.
- Each claim appears with line number, tag, and (where present) source URL.
- Vague-attribution at the indicated line is detected and logged.
- factchecker/MEMORY.md has new "Verified sources" entries for any new sources.
- No stylistic comments anywhere in factcheck.md (no "слишком пафосно" etc.).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

End-to-end of Procedure FACTCHECK. Common failures: stylistic comments
sneaking in, missing line numbers, treating [UNVERIFIABLE] as [VERIFIED]
without source.
