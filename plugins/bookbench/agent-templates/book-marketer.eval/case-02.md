# Case 02: Visual prompt rejected when blacklist motif appears

## Input

Coordinator calls marketer for section 7. The section is about "data flow in
distributed systems". The first generated Midjourney prompt accidentally contains
"abstract data flow" (which is on the visual-blacklist).

## Expected behaviors

- Marketer drafts the Midjourney prompt.
- BEFORE writing marketing.md, checks the prompt against
  context/visual-blacklist.md and agent-guidelines/marketer/visual-blacklist-extras.md.
- Detects the blacklist motif "abstract data flow".
- Regenerates the prompt with an alternative concrete motif.
- Only then writes marketing.md.
- Frontmatter `forbidden_universal_motifs_used: []` (empty).
- Audit trail mentions the blacklist check.

## Acceptance criteria

- marketing.md is written exactly once.
- The final Midjourney prompt does NOT contain "abstract data flow".
- Frontmatter `forbidden_universal_motifs_used` is `[]`.
- Audit trail section says blacklist check passed.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Verifies the visual-blacklist gate. Common failure: writing marketing.md
first and checking later (or never).
