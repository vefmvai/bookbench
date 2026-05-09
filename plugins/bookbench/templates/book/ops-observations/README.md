# `.book/ops-observations/` — operational telemetry for the book

> Local data folder for the `book-observer` agent. Populated by the
> `ops-telemetry-hook.sh` hook (raw signals) and by `/book:analyze-session`
> (digested notes). Used to feed BookBench upgrades for version 0.2+.

## Why this folder exists

The book-writing flow runs ten roles in sequence, each consuming tokens
and time. Without continuous lightweight tracking we cannot answer:

- Where does the team spend most tokens — writer or factchecker?
- Which steps trigger repeat passes (revise loops)?
- When the author types "actually, look at section 12 again" — is it a
  one-off or a recurring memory miss that signals a missing registry?
- Which roles produced false-positive blocks and which produced silent
  good work?

`book-observer` (a sibling 10th role, not part of the section micro-cycle)
turns those questions from anecdotes into evidence. This folder is the
storage layer for that evidence.

## Files in this folder

| File | Producer | Consumer | Sensitivity |
|---|---|---|---|
| `rawlog.jsonl` | `ops-telemetry-hook.sh` (auto, on every Claude Code event) | `book-observer` | Local-only, gitignored |
| `section-N-process-notes.md` | `book-observer` (on `/book:analyze-session`) | author + future `bookbench-evolver` | Local-only, gitignored |
| `section-N-content-notes.md` | `book-observer` | author + writer/editor (next section) | Local-only, gitignored |
| `upgrade-candidates.md` | `book-observer` (append-only) | author + maintainers of BookBench plugin | Anonymised, may be shared |
| `transcripts/` (optional) | author may symlink session transcripts here | `book-observer` | Local-only |

The exact JSON schema of `rawlog.jsonl` is documented in the dev docs of
the plugin (`bookbench/docs/`); see also the design note in
`.bpd/stages/14.1-stratifikaciya-modeley-i-telemetriya/telemetry-schema.md`.

## Privacy contract (CRITICAL)

The hook and the observer follow a strict no-content-leak policy:

- **The telemetry hook never writes prompt bodies, draft text, edited
  text, or any artefact body** to `rawlog.jsonl`. Only metadata is
  captured: timestamps, tool names, durations, token counts, plus
  truncated SHA-256 hashes of file paths and prompt prefixes.
- **The observer agent NEVER reads** `sections/<N>/draft.md` or
  `sections/<N>/edited.md`. It only consumes `rawlog.jsonl` and the
  Claude Code session transcript stored by Claude Code itself.
- **The observer NEVER quotes the author's replies verbatim** in the
  notes files. It abstracts: "author requested fact-correction, year
  mismatch", not "author wrote: '1812 not 1815'".
- **`upgrade-candidates.md`** is the one file that may eventually be
  shared with BookBench maintainers (e.g., as part of a bug report).
  It is therefore the most stringently anonymised.

The hook always exits 0 (non-blocking). If `.book/` is missing or the
log file is unwritable, the hook silently skips with a single stderr
line; it never blocks Claude Code.

## How to use

1. **Automatic.** Once the hook is installed (auto-installed by
   `/book:start`), every Claude Code action in this book directory is
   recorded in `rawlog.jsonl`. You don't need to do anything.

2. **On-demand digest.** Run `/book:analyze-session [--section N]` to
   activate the observer agent. It reads `rawlog.jsonl`, classifies
   author replies as `content` (about meanings, facts, voice, structure)
   vs `process` (about workflow, model speed, repeated passes), and
   writes:

   - `section-N-process-notes.md` — workflow signals scoped to that section.
   - `section-N-content-notes.md` — meaning-related signals scoped to that section.
   - Updates `upgrade-candidates.md` when the same signal recurs ≥3 times.

3. **Inspect.** Read the produced notes after each section to confirm
   the observer captured what you remember.

## Categories in `upgrade-candidates.md`

The observer promotes a recurring signal to a candidate if it appears in
≥3 distinct section sessions. Candidates are filed under one of four
categories:

- **Token efficiency** — wasted budget; e.g., factchecker ran twice on
  the same statement, writer regenerated a long passage after one-line
  feedback.
- **Memory gaps** — author asked "look at section X again" or a duplicate
  example slipped past the editor; signals the registry layer
  (`agent-memory/`, `intel/`) missed something. Sub-signal: extra `Read`
  calls beyond the minimal `files_to_read` of the role.
- **UX friction** — long author replies that mix content + process +
  meta; missing commands; confusing next-step messages.
- **Quality regressions** — duplicates that the editor or factchecker
  did catch (good!) but only after an unusual number of passes.

These categories are also documented inline in the
`upgrade-candidates.md` template so the observer can pick the right
bucket on the first try.

## Special signals to watch for (BookBench 0.2+ backlog seeding)

The observer pays extra attention to the following recurring patterns,
each of which is a clear input for the next BookBench iteration:

1. **Extra `Read` calls beyond `files_to_read`.** A subagent fetching
   files outside its declared input set is a sign that the input set was
   too narrow. Filed under **Memory gaps**.
2. **Author asking "look at section X again."** The registry layer
   should already give the writer/editor whatever from section X is
   relevant. A manual ask means the registry missed it. Filed under
   **Memory gaps**.
3. **Duplicates caught by editor/factchecker.** The editor catching a
   repeated metaphor or the factchecker catching a duplicate fact is
   good — but each occurrence is also a signal that the writer's
   inputs (registries, voice samples) didn't pre-empt the duplicate.
   Filed under **Quality regressions**.

## Boundary: this folder vs `intel/` vs `agent-memory/`

| Folder | What it is | Lifetime |
|---|---|---|
| `intel/` | Permanent registries (characters, places, voice samples, facts already verified) | Lives forever; cross-section |
| `agent-memory/<role>/` | Per-role private state (cooldowns, applied-tuning history, recent rejections) | Lives forever; per-role |
| `ops-observations/` | Operational telemetry; observation about HOW the team worked, not WHAT they wrote | Local-only; consumed by observer + maintainers; safe to delete and regenerate |

The observer never mixes these layers. It writes only to
`ops-observations/`.

## .gitignore

This folder ships a `.gitignore` that excludes:

- `rawlog.jsonl` (sensitive raw event stream)
- `section-*-notes.md` (may include role names / section numbers, which
  is fine, but content-notes may abstract sensitive author intent)

Only `upgrade-candidates.md` is committed by default — that is the
single file safe to share with BookBench maintainers.
