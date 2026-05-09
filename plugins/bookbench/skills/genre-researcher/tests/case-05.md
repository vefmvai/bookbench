# Genre-researcher evaluation case 05: exotic genre with insufficient sources (Fallback C)

## Input

User runs `/book:research-genre kishōtenketsu`. WebSearch is available but
the genre is niche enough that fewer than three sources can be collected
within the 15-minute time budget for the mandatory categories
(handbooks, writing guides, published authors' essays).

## Expected behaviors

- Phase 1 collects the genre profile normally.
- Phase 2 issues queries; after 10 minutes it has collected 1–2 sources
  total, with category 1 (handbooks) uncovered.
- The skill detects the under-coverage condition and jumps to Fallback C.
- The skill shows the author the source list (with titles and URLs) and
  category coverage, then offers via AskUserQuestion:
  (a) generate at low confidence — methodology gets
      `confidence: low` in YAML frontmatter; service-section advises
      manual tuning via `/book:tune:guidelines`;
  (b) import a genre handbook via `/book:import` and re-run;
  (c) refine the genre name (the author may have meant a closer
      standard genre — the skill lists 2–3 candidates).
- For option (a), the package is generated and persisted with the
  confidence marker. For options (b) and (c), no package is persisted yet.

## Acceptance criteria

- The source count visible to the author is the actual count from Phase 2
  (not inflated, not hallucinated).
- For option (a):
  - `${CLAUDE_PLUGIN_DATA}/user-methodologies/kishotenketsu-methodology.md`
    contains `confidence: low` in its YAML frontmatter.
  - The methodology's service-section names
    `/book:tune:guidelines` as the recommended next step for refinement.
  - The preset `${CLAUDE_PLUGIN_DATA}/user-presets/kishotenketsu.yaml` is
    persisted and parses as valid YAML.
- For option (c) with refinement:
  - The skill restarts Phase 1 with the refined genre name and re-runs
    the full pipeline (no shortcut from the partial Phase 2).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the exotic-genre / under-coverage fallback. Common failure modes:
- the skill silently lowers its category requirements (skips handbooks
  because none were found) and produces a methodology that pretends to
  be authoritative;
- the skill conflates 1–2 niche sources with five mandatory categories
  and reports `confidence: high`;
- the skill refuses to produce anything (overcorrects).

The correct behavior is option (a) with explicit `confidence: low`
marker, OR option (b)/(c) with no premature persistence.

## Why kishōtenketsu

A four-act narrative structure used in Japanese literature — niche enough
that English-language search results are sparse, generic enough to pose
the test cleanly without being culturally insensitive. Generic
placeholder topics in the methodology body remain (no real Japanese
authors as canonical examples).
