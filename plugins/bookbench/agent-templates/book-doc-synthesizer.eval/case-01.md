# Case 01: Propose mode generates INGEST-DECISIONS.md

## Input

Coordinator calls synthesizer in `mode=propose`. Inputs:
- intel/classifications/random-notes.md.json (six fragments classified by
  classifier in case-01).
- agent-memory/{coordinator,strategist,writer,factchecker,editor,marketer,tuner}/MEMORY.md
  (existing entries; one of them already contains the metaphor "leaf as solar panel").
- INGEST-DECISIONS.md does NOT yet exist.

## Expected behaviors

- Reads classifier output and all existing memory files.
- For each fragment determines target_role and target_section.
- Computes fingerprint for dedup.
- Detects the metaphor "leaf as solar panel" as a duplicate of an existing
  writer/MEMORY entry → `action: skip-duplicate`.
- Other fragments receive `action: append` with candidate_diff.
- Groups proposals by target_role; writes a Summary section.
- Writes INGEST-DECISIONS.md (creates the file).
- Does NOT modify any MEMORY.md (propose mode only).

## Acceptance criteria

- INGEST-DECISIONS.md created with Summary + per-fragment YAML blocks.
- At least one entry has `action: skip-duplicate` referencing the existing one.
- All other entries have valid `target_role`, `target_section`, `candidate_diff`.
- agent-memory/*/MEMORY.md files are byte-identical to before.
- No `.book/.backup/` directory created (propose mode does not back up).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests Procedure SYNTHESIZE-PROPOSE end-to-end.
