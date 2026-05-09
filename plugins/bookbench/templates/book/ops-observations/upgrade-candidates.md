# Upgrade candidates — BookBench 0.2+ backlog seeded from this book

> Append-only file maintained by `book-observer`. Each candidate records
> a recurring signal (≥3 occurrences across distinct section sessions)
> that suggests an improvement to the BookBench plugin itself.
>
> **Privacy:** entries are anonymised. NO author names, NO direct quotes
> from sections, NO unique character/place names from the book. The
> observer enforces this rule before each `Write`.

## Format of one entry

```yaml
- id: uc-<NNNN>
  first_seen: <ISO 8601 UTC>
  last_seen:  <ISO 8601 UTC>
  category:   token-efficiency | memory-gaps | ux-friction | quality-regression
  severity:   low | medium | high
  occurrences: <int>            # number of distinct section sessions
  signal_pattern: |
    <one-paragraph abstract description of the recurring signal;
     no verbatim author quotes, no draft excerpts>
  affected_role:    <book-writer | book-editor | book-factchecker | book-coordinator | ...>
  affected_step:    <plan-section | write-section | factcheck | edit | ship | ...>
  suggested_fix:    |
    <abstract description of the proposed BookBench plugin change;
     example: "expand the writer's files_to_read with the
     character-registry summary from intel/">
  related_decisions: [PS-XX-YY, ...]   # if relevant
  status: candidate                     # candidate | promoted | dismissed
```

## Categories (reference)

### Token efficiency

Wasted budget. The most common sub-patterns:

- A subagent regenerated a long passage after a one-line feedback that
  could have been applied as a localised edit.
- A verification role (factchecker, editor) re-checked something that
  was already in a previous-section registry.
- Coordinator made multiple round-trips when one would suffice.

### Memory gaps

The registry layer (`intel/`, `agent-memory/`) missed information that
should have been there:

- Author manually asked "look at section X again" — meaning the
  cross-section registry didn't surface what was relevant from section X.
- A subagent issued extra `Read` calls beyond its declared
  `files_to_read` — meaning the declared input set was too narrow.
- Duplicate facts/examples slipped past the writer because the writer's
  input set didn't include the relevant registry.

### UX friction

Friction in the author's interaction with the system:

- Long author replies that mix content critique and process complaint
  ("the metaphor is weak AND why is the factchecker so slow").
- Missing commands (author tries `/book:something` and gets a
  not-found).
- Confusing or absent next-step messages.

### Quality regressions

The team caught a problem (good!), but the number of passes needed to
catch it suggests the upstream role had insufficient guidelines:

- Editor caught a duplicate metaphor that voice-samples in `intel/`
  could have prevented.
- Factchecker caught a date error that an outdated-sources entry could
  have flagged earlier.
- Marketer wrote a hook the author rejected because the marketing
  guidelines didn't include enough hook-template variety.

## Candidates

> *(Empty at book creation. The observer appends entries as it
> processes sessions. Maintainers reviewing this file should focus on
> entries with `severity: high` and `occurrences: ≥5`.)*

## How to triage candidates (for BookBench maintainers)

1. Filter by `severity: high` and `occurrences: ≥5`.
2. Group by `category` to identify upstream root causes.
3. For each high-severity cluster, decide:
   - `promoted` — write a BookBench issue against the candidate, with
     a link to the `signal_pattern` and `suggested_fix`.
   - `dismissed` — record a reason inline and the date; the observer
     respects this by adding a cooldown timer (90 days) before
     re-suggesting.

## Cross-references

- `section-N-process-notes.md` — drill-down on per-section friction.
- `section-N-content-notes.md` — drill-down on per-section meaning notes
  (rarely promoted to upgrade-candidates; usually feeds back into the
  next section's `intel/` and `agent-guidelines/`).
- `rawlog.jsonl` — raw event stream the observer consumes.
