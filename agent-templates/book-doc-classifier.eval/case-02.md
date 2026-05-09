# Case 02: Unsupported format produces an errors entry

## Input

`<files_to_read>` includes inputs/notes.docx (a binary format).
The classifier has no Bash and no parser for .docx.

## Expected behaviors

- Reads the file (or attempts to).
- Detects unsupported format.
- Skips the file but records an entry in `errors[]` of the JSON output:
  `{file: "notes.docx", reason: "unsupported format"}`.
- Continues with any other input files.
- Returns the JSON with empty fragments and the errors array populated.

## Acceptance criteria

- intel/classifications/notes.docx.json exists.
- `fragments` is empty.
- `errors` contains one entry referencing the unsupported format.
- No crash, no exception unhandled.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests graceful degradation on unsupported formats.
