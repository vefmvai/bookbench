# Eval case 01 — content vs process classification

> Verifies that `book-observer` correctly distinguishes content signals
> (about meanings, facts, voice, structure) from process signals (about
> workflow, model speed, repeated passes).

## Setup

`.book/ops-observations/rawlog.jsonl` (mock) contains 5 author replies
recorded as `UserPromptSubmit` events plus matching tool events:

```jsonl
{"schema_version":"1","timestamp":"2026-05-07T10:00:00Z","event_type":"UserPromptSubmit","session_id":"sess-eval-01","agent":"main","model":"opus","tool_name":null,"tool_status":null,"duration_ms":null,"input_tokens":null,"output_tokens":null,"file_path_hash":null,"prompt_hash":"a1b2c3d4e5f60718","prompt_length":62}
{"schema_version":"1","timestamp":"2026-05-07T10:05:00Z","event_type":"UserPromptSubmit","session_id":"sess-eval-01","agent":"main","model":"opus","tool_name":null,"tool_status":null,"duration_ms":null,"input_tokens":null,"output_tokens":null,"file_path_hash":null,"prompt_hash":"b2c3d4e5f6071829","prompt_length":71}
{"schema_version":"1","timestamp":"2026-05-07T10:12:00Z","event_type":"UserPromptSubmit","session_id":"sess-eval-01","agent":"main","model":"opus","tool_name":null,"tool_status":null,"duration_ms":null,"input_tokens":null,"output_tokens":null,"file_path_hash":null,"prompt_hash":"c3d4e5f607182930","prompt_length":54}
{"schema_version":"1","timestamp":"2026-05-07T10:18:00Z","event_type":"UserPromptSubmit","session_id":"sess-eval-01","agent":"main","model":"opus","tool_name":null,"tool_status":null,"duration_ms":null,"input_tokens":null,"output_tokens":null,"file_path_hash":null,"prompt_hash":"d4e5f60718293041","prompt_length":68}
{"schema_version":"1","timestamp":"2026-05-07T10:25:00Z","event_type":"UserPromptSubmit","session_id":"sess-eval-01","agent":"main","model":"opus","tool_name":null,"tool_status":null,"duration_ms":null,"input_tokens":null,"output_tokens":null,"file_path_hash":null,"prompt_hash":"e5f6071829304152","prompt_length":59}
```

Mock transcript (`~/.claude/projects/<hash>/sess-eval-01.jsonl`) contains
matching user replies (paraphrased here for the eval design — no
verbatim author text):

| Reply | Content (paraphrased) | Expected classification |
|---|---|---|
| 1 | "the metaphor about gears in this paragraph feels forced; rewrite it" | content (metaphor → voice/figurative) |
| 2 | "the year 1812 is wrong; the correct date is 1815" | content (fact → year mismatch) |
| 3 | "why did the factchecker run twice on the same statement again?" | process (repeated pass + token waste) |
| 4 | "this paragraph has too many adjectives; trim them" | content (voice → style/register) |
| 5 | "the team is taking too long on chapter 3; total 40 minutes feels excessive" | process (slow / token / context) |

## Expected observer output

The observer must produce:

### `chapter-3-content-notes.md`

Three entries under different sub-categories:

- **Metaphors / examples:** "metaphor for a structural concept rejected as forced; role: book-writer; local fix: agent-guidelines/writer/voice-samples.md or forbidden-phrases.md"
- **Facts:** "year mismatch in introductory paragraph; corrected to authoritative source; role: book-factchecker; local fix: agent-guidelines/factchecker/trusted-sources.md"
- **Voice:** "excessive adjectival density rejected; role: book-writer; local fix: agent-guidelines/editor/cohesion-rules.md or writer/voice-samples.md"

### `chapter-3-process-notes.md`

Two entries:

- **Friction event A:** "factchecker invoked twice on same set; pattern: repeated-verification; impact: token waste"
- **Friction event B:** "session duration exceeded normal envelope (~40 min vs typical ≤25 min); pattern: long-session"

### `upgrade-candidates.md`

No new candidates yet — single occurrences only. Counters incremented
locally; promotion happens after ≥3 cross-chapter recurrences.

## Acceptance criteria

- All 5 replies classified.
- 3 in content, 2 in process. (PS-14.1-06 heuristic test.)
- Privacy self-check: clean.
- No verbatim quotes in either notes file.
- No book-specific proper nouns (the eval intentionally uses generic
  domain words: "gears", "1812/1815", "factchecker", "chapter 3").

## Pass / fail

- **PASS** if classification matches the expected table exactly AND
  privacy self-check returns clean.
- **FAIL** if any reply is misclassified OR if any note contains a
  verbatim quote OR a proper noun from the book.

## Privacy gate

The eval explicitly contains NO author-specific terminology. Even the
"gears" metaphor is generic (mechanical engineering metaphor common in
many books). No character names, no place names, no thematic
spoilers.
