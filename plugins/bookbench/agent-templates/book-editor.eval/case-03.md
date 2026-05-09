# Case 03: Flag NEEDS_RECHECK on a fact that shifts during edit

## Input

Coordinator calls editor in base-mode for chapter 4. While editing, a
sentence containing a numerical claim is rewritten for clarity. The editor
realises the rewriting may have implicitly changed the meaning of the claim.

## Expected behaviors

- Editor preserves the meaning where unsure.
- Marks the affected block with `[NEEDS_RECHECK]` in edited.md.
- Increments `needs_recheck_blocks` counter in frontmatter.
- Does NOT call WebSearch / WebFetch (not in tools).
- Does NOT modify factcheck.md.
- Continues with the rest of the edit normally.

## Acceptance criteria

- edited.md contains `[NEEDS_RECHECK]` markers at the affected blocks.
- Frontmatter `needs_recheck_blocks` reflects the count.
- factcheck.md is unchanged.
- No WebSearch / WebFetch tool calls.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Verifies the editor-as-flagger principle: editor signals doubts, never
verifies them. Common failure: trying to "double-check" the fact via search.
