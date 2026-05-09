---
name: import-classification-protocol
description: Defines the classification taxonomy of eleven fragment types for the import pipeline — parameter, voice-sample, glossary-term, characters, common-misconception, plot-connector, used-metaphor, source, hook-phrase, visual-reference, other — and the JSON output format for intel/classifications/. Used by book-doc-classifier when /book:import is run. Provides confidence-scoring rules and tagged-fragment shape used by the synthesizer downstream.
---

# Import classification protocol skill

## When to use

Injected into `book-doc-classifier`. Activated only by `/book:import` (Sub-DAG of the import flow). The classifier runs in parallel per file (one Task per imported source).

## Eleven fragment types

Every fragment of an imported source is classified into exactly one of:

| Class | Goes to |
|-------|---------|
| `parameter` | `.book/context/parameters.md` |
| `voice-sample` | `.book/agent-guidelines/writer/voice-samples.md` |
| `glossary-term` | `.book/context/glossary.md` |
| `characters` | `.book/context/characters.md` |
| `common-misconception` | `.book/context/common-misconceptions.md` |
| `plot-connector` | `.book/context/cross-references.md` |
| `used-metaphor` | `.book/.claude/agent-memory/writer/MEMORY.md` |
| `source` | `.book/agent-guidelines/factchecker/trusted-sources.md` |
| `hook-phrase` | `.book/.claude/agent-memory/marketer/MEMORY.md` |
| `visual-reference` | `.book/.claude/agent-memory/marketer/MEMORY.md` |
| `other` | flagged for synthesizer review; may become a fragment of a chapter draft |

## Output format

For each input file, the classifier writes `.book/intel/classifications/<input-filename>.json`:

```json
{
  "source_file": "inputs/notes-2025.md",
  "classified_at": "ISO-8601-timestamp",
  "fragments": [
    {
      "id": "F-0001",
      "class": "voice-sample",
      "snippet": "exact text from the source",
      "byte_offset": 1240,
      "byte_length": 583,
      "confidence": 0.92,
      "rationale": "First-person reflective passage with characteristic dash usage and informal register."
    }
  ]
}
```

## Confidence scoring rules

- `≥0.85` — high confidence; the synthesizer can apply automatically (auto-resolved bucket).
- `0.50–0.84` — medium; the synthesizer flags for author review (competing-variants if there is conflict, otherwise one-by-one).
- `<0.50` — low; not classified, marked as `other`, surfaced in the rejected bucket of `INGEST-DECISIONS.md`.

## Procedure

1. Read input file.
2. Read `agent-guidelines/classifier/README.md` (book-specific cues).
3. Walk the file in 500–1500-char windows.
4. For each window, propose a class and a confidence score; record `rationale` for traceability.
5. Write `intel/classifications/<filename>.json`.

## Tests

- Test 1 — given a file with three voice samples and one glossary entry, classifier produces four fragments with the correct classes and `confidence ≥0.85`.
- Test 2 — given an ambiguous fragment that could be either `plot-connector` or `glossary-term`, the classifier produces both candidates with `confidence` reflecting uncertainty (≤0.7 each).
- Test 3 — given a file with no clearly classifiable content (random meeting notes), all fragments are `other` with `confidence <0.50`.

## Files

No extra reference files. The taxonomy is encoded directly here.

## Notes

- This skill never carries time-sensitive information.
- Fragment IDs (`F-NNNN`) are sequential per input file; reset for each file.
- The classifier has no project memory (MEM-01); each invocation is independent.
