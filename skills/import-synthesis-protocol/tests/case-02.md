# Import-synthesis-protocol evaluation case 02: skip duplicate

## Input

Classifier output contains a fragment that maps to writer/MEMORY.md
`Used metaphors`. The same metaphor (same family + same vehicle +
same literal_subject) is already present.

## Expected behaviors

- Skill computes fingerprint over normalised snippet + target_section +
  target_role.
- Detects duplicate.
- Sets `action: skip-duplicate` with `reason: already-in-MEMORY-as-<id>`.
- Does NOT propose appending.

## Acceptance criteria

- INGEST-DECISIONS entry has `action: skip-duplicate`.
- Existing entry id is referenced in `reason`.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests deduplication. Common failure: re-import inflates registries with
duplicates.
