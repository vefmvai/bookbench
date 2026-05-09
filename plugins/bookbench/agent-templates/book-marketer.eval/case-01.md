# Case 01: Pack marketing for a section with default settings

## Input

Coordinator calls marketer for section 4 after editor `pass`. workflow.marketing
is enabled. Inputs:
- sections/004/edited.md.
- context/visual-blacklist.md (lists "neural pathways", "matrix code rain",
  and "abstract data flow").
- context/target-audience.md (audience: general public, education ≥ secondary,
  preferred platforms: telegram + linkedin).
- agent-guidelines/marketer/{brand-voice, visual-blacklist-extras, telegram-tone}.md.
- agent-memory/marketer/MEMORY.md (hook techniques used last 3 sections:
  paradox-statement, parallel-list, story-opener; SUCCESs primary attribute
  "Concrete" used 4 times — threshold 5).

## Expected behaviors

- Reads guidelines via index-driven protocol.
- Determines SUCCESs primary attribute that is NOT "Concrete" (since that is
  about to hit the overuse threshold).
- Selects a hook technique not in {paradox-statement, parallel-list, story-opener}
  (e.g. question or scientific-fact).
- Generates 3 title variants (different techniques).
- Writes a Telegram post (3-5 sentences, ≤500 chars).
- Writes Twitter/X (≤280 chars) and LinkedIn (≤500 chars) fragments.
- Generates a visual concept + Midjourney prompt that does NOT contain
  any of the visual-blacklist motifs.
- Writes sections/004/marketing.md with frontmatter (section_id, created_by,
  SUCCESs_primary, SUCCESs_secondary, visual_motifs_used, hook_technique).
- Updates marketer/MEMORY.md.

## Acceptance criteria

- marketing.md exists with frontmatter.
- 3 title variants present.
- Telegram post ≤500 chars; Twitter ≤280 chars; LinkedIn ≤500 chars.
- Hook_technique ∉ {paradox-statement, parallel-list, story-opener}.
- SUCCESs_primary ≠ "Concrete".
- Midjourney prompt contains 0 visual-blacklist motifs.
- No clickbait formulas ("Вы не поверите", "Шокирующая правда" ...).
- No mentor-mode tokens.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests Procedure PACK-MARKETING with multiple memory constraints. Common
failures: blacklist motif sneaks into prompt; clickbait formula in Telegram.
