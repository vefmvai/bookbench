# Case 02: Write mode performs backup before editing other roles' MEMORY

## Input

Coordinator calls synthesizer in `mode=write` with an explicit list of
approved INGEST entry ids: [ingest-002, ingest-003, ingest-005].
INGEST-DECISIONS.md exists with these entries marked `action: append`.

## Expected behaviors

- Reads the approved entries.
- Creates `.book/.backup/import-<timestamp>/` directory.
- For each affected MEMORY.md (writer/, factchecker/, marketer/) creates a
  pre-write snapshot in `.book/.backup/import-<timestamp>/<role>/MEMORY.md.before`.
- Then Edits each target MEMORY.md, appending the candidate_diff with extra
  fields `source: import`, `imported_at: <ts>`, `fragment_source: <id>`.
- Updates frontmatter of each touched MEMORY.md (last_updated, total_entries +=1).
- Updates INGEST-DECISIONS.md statuses: each applied entry gets
  `status: applied; applied_at: <ts>`.
- Returns: "Synthesizer wrote 3 records to N files (M roles). Backup: ...".

## Acceptance criteria

- `.book/.backup/import-<timestamp>/` exists with snapshots for each affected role.
- Snapshot file count == number of distinct target roles.
- INGEST-DECISIONS.md has status entries for all three ids.
- Each target MEMORY.md has new entries with the import fields.
- No coordinator/MEMORY.md or tuner/MEMORY.md is touched (only the relevant ones).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests Procedure SYNTHESIZE-WRITE including backup discipline. Common
failure: skipping backup, or backing up after edit.
