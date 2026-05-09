# Case 03: Detect conflict with existing rejected source

## Input

Coordinator calls synthesizer in `mode=propose`. One of the classified
fragments is a science-magazine link that the existing
agent-memory/factchecker/MEMORY.md `Outdated/rejected sources` section already
flags as unreliable.

## Expected behaviors

- Synthesizer reads existing factchecker/MEMORY.md.
- Detects that the proposed source matches a rejected entry.
- Sets `action: conflict` with `conflict_with: <existing-rejected-id>`.
- Does NOT propose adding the source to `Verified sources` automatically.
- The INGEST-DECISIONS.md entry contains a clear rationale.

## Acceptance criteria

- The fragment appears in INGEST-DECISIONS.md with `action: conflict`.
- `conflict_with` field references the rejected entry id.
- Rationale ≤200 chars and describes the conflict.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the conflict-detection rule. Common failure: silently proposing the
source as new without checking the rejected list.
