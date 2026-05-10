# Genre-researcher evaluation case 02: no-internet fallback

## Input

User runs `/bookbench:research-genre memoir` while offline. WebSearch fails;
no MCP servers are configured.

## Expected behaviors

- Skill detects WebSearch unavailability after the first failed call.
- Switches to fallback scenario "no internet" (GR-10):
  prompts the author to manually feed sources via `/bookbench:import` or to
  proceed with a minimal preset based on baseline knowledge with explicit
  caveats.
- Does NOT fabricate sources.
- Output preset has a `confidence: low` / `caveat` field.

## Acceptance criteria

- AskUserQuestion is invoked with the offline-fallback options.
- If the author chooses "proceed minimal", the output files exist with
  caveat fields.
- All "sources" are clearly marked as baseline-knowledge, not fabricated URLs.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests fallback scenario from GR-10.
