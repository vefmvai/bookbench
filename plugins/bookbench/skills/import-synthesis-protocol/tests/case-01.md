# Import-synthesis-protocol evaluation case 01: append a new metaphor

## Input

Classifier output contains one fragment with `class: used-metaphor`.
writer/MEMORY.md does NOT contain a similar metaphor.

## Expected behaviors

- Skill maps `class: used-metaphor` → `agent-memory/writer/MEMORY.md`,
  section `Used metaphors`.
- Computes fingerprint; no duplicate found.
- Sets `action: append` with a candidate_diff containing the metaphor entry.

## Acceptance criteria

- INGEST-DECISIONS entry has `action: append`.
- candidate_diff is a valid YAML block matching the writer/MEMORY schema.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Smoke test for the propose-mode happy path.
