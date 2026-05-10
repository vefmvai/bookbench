---
name: import-synthesis-protocol
description: Описывает протокол синтезатора, превращающий JSON-вывод классификатора в предложенные правки реестров и — после одобрения автора — в фактические записи в MEMORY.md других ролей. Включает дедупликацию через фингерпринты, трёхкорзинную структуру INGEST-DECISIONS.md (auto-resolved, competing-variants, rejected), разрешение конфликтов и двухрежимную работу propose-then-write.
---

# Import synthesis protocol skill

## When to use

Injected into `book-doc-synthesizer`. Activated only by `/bookbench:import` after `book-doc-classifier` produces `intel/classifications/*.json`.

## Two modes — propose and write

The synthesizer runs in one of two modes per coordinator invocation:

| Mode | What it does | What it writes |
|------|---------------|----------------|
| `propose` | Reads classifier output, proposes mappings, detects duplicates and conflicts. | Writes `INGEST-DECISIONS.md` only — the audit trail. Does not edit any registry. |
| `write` | After author approval (via `AskUserQuestion` batch confirm), applies approved mappings. | Edits other roles' `MEMORY.md` directly (MEM-01 exception). Appends to `INGEST-DECISIONS.md > Auto-resolved` and updates `STATE.md`. |

## Three-bucket INGEST-DECISIONS.md

```markdown
# Ingest decisions

## Auto-resolved (high-confidence, no conflict)

- F-0001 from inputs/notes.md → writer/MEMORY.md > used_metaphors. Confidence 0.91. No conflict.
- ...

## Competing-variants (conflict found, awaits /bookbench:resolve)

- V-01: F-0023 (inputs/draft-v1.md) and F-0098 (inputs/draft-v2.md) both propose to add the same concept to glossary; texts differ.
- V-02: F-0044 proposes a voice-sample that contradicts an existing voice-sample (different register).

## Rejected (low confidence or out-of-scope)

- F-0177 from inputs/random-notes.md — class `other`, confidence 0.32. Reason: meeting notes unrelated to the book.
```

## Deduplication via fingerprinting

For each proposed registry entry, compute a fingerprint:

- For text fragments: SHA-256 of the lower-cased, whitespace-normalised first 500 chars.
- For metaphors: tuple `(fingerprint, target_concept)` so the same metaphor for different concepts is allowed.

If the fingerprint already exists in the target registry, mark the proposal as `duplicate`; do not propose a new entry. If `confidence` of the new fragment is materially higher, propose `replace` with audit trail.

## Conflict handling

A conflict arises when:

- Two fragments propose different content for the same target slot (same `glossary-term`, same `parameter` ID).
- A fragment proposes content that contradicts an existing entry (e.g., outdated source vs new trusted source).

Conflicts go into `INGEST-DECISIONS.md > Competing-variants` with a `V-NN` ID. The author resolves them via `/bookbench:resolve <variant-id> <a|b|merge|reject>`.

## Procedure (propose mode)

1. Read all `intel/classifications/*.json`.
2. Read all `.book/.claude/agent-memory/<role>/MEMORY.md`.
3. Read `.book/context/`.
4. For each fragment with confidence ≥ 0.85: propose to auto-resolved bucket.
5. For each fragment with confidence 0.50–0.84: propose to competing-variants if any conflict; otherwise propose with `awaits-confirm` flag in auto-resolved.
6. For each fragment with confidence <0.50: rejected bucket.
7. For each conflict pair: merge into a `V-NN` entry; describe both options.
8. Write `INGEST-DECISIONS.md`.

## Procedure (write mode)

1. Read updated `INGEST-DECISIONS.md` (after author approval).
2. Take a snapshot of all `agent-memory/<role>/MEMORY.md` to `.book/.backup/import-<timestamp>/`.
3. For each `Auto-resolved` entry with `applied: false`: open the target MEMORY.md and Edit-append.
4. Mark the entry `applied: true` with timestamp.
5. Update `STATE.md`: `import: applied N1, deferred N2, rejected N3`.

## Tests

- Test 1 — given a high-confidence voice-sample fragment that does not conflict, propose mode places it in Auto-resolved.
- Test 2 — given two fragments proposing different glossary entries for the same term, propose mode creates a V-01 entry.
- Test 3 — given an approved Auto-resolved entry in INGEST-DECISIONS.md, write mode appends the entry to writer/MEMORY.md and updates `applied: true`.

## Files

No extra reference files.

## Notes

- The synthesizer is the only role permitted to Edit other roles' MEMORY.md (MEM-01 exception).
- Deduplication fingerprinting parameters (whitespace policy, first-N-chars) are fixed at 500 chars by default; per-book override possible via `.book/agent-guidelines/synthesizer/README.md`.
- The synthesizer has no project memory.
