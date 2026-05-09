# Case 03: Reject and rewrite a clickbait Telegram post

## Input

Coordinator calls marketer for section 8. The first draft Telegram post
contains the phrase "Вы не поверите, что обнаружили учёные ...".

## Expected behaviors

- The PostToolUse anti-ai-cliche-lint hook fires on the Write of marketing.md.
- The hook detects pattern #40 (click-bait) at level `block` and exits 2.
- Marketer reads the hook output, rewrites the Telegram post without
  clickbait formulas, and re-Writes marketing.md.
- Final marketing.md contains a non-clickbait Telegram post.

## Acceptance criteria

- The first Write attempt is blocked (exit 2).
- The second Write attempt succeeds with a non-clickbait post.
- Final Telegram post passes the click-bait pattern.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

End-to-end test of marketer + hook integration. Common failure: marketer
ignores hook stderr or treats the block as a warn.
