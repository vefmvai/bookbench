# Section N — content notes (template)

> Template populated by `book-observer` on `/book:analyze-session
> --section N`. Replace `N` with the actual section number.
>
> Content notes capture meaning-related signals: author feedback about
> facts, metaphors, voice, structure, thesis. They feed back into the
> NEXT section's `intel/`, `agent-guidelines/`, and writer briefing.
>
> **Privacy contract.** The observer abstracts every author reply. It
> NEVER quotes verbatim. It NEVER paraphrases anything that contains
> unique character / place / brand names from the book. If the author
> wrote "the metaphor 'whirlwind of synapses' is forced", the observer
> records "metaphor for section's central concept rejected as forced".
> The original phrase NEVER appears here.

## Session metadata

- section: <N>
- session_id: <from rawlog>
- author_replies_observed: <int>
- author_replies_classified_as_content: <int>
- author_replies_classified_as_process: <int>

## Content signals by sub-category

> Each entry: short abstract description, the role that produced the
> rejected output, and the local fix (which `agent-guidelines/<role>/`
> file should be edited).

### Facts (factuality concerns)

- <abstract: "year mismatch in introductory paragraph; corrected to
  authoritative source"; role: book-factchecker; local fix:
  agent-guidelines/factchecker/trusted-sources.md>
- <…>

### Voice (tone / register concerns)

- <abstract; role: book-writer; local fix:
  agent-guidelines/writer/voice-samples.md or editor/author-deviations.md>

### Structure (red-thread / pacing concerns)

- <abstract; role: book-strategist or book-writer; local fix:
  agent-guidelines/strategist/structural-rules.md>

### Metaphors / examples (figurative-language concerns)

- <abstract; role: book-writer; local fix:
  agent-guidelines/writer/forbidden-phrases.md or voice-samples.md>

### Thesis / argument (semantic concerns)

- <abstract; role: book-strategist or book-writer; local fix: section
  spec.md or strategist guidelines>

## Aggregate summary for the next section writer

> 2-3 sentences a coordinator can paste into the next
> `sections/<N+1>/spec.md` briefing as a reminder of the author's
> latest stylistic / structural / factual preferences. Abstract,
> generic, no spoilers.

- <…>

## Patterns to escalate to `upgrade-candidates.md`

> Listed here only when 3+ recurrences across distinct sections indicate
> a BookBench-level issue (not a per-book guideline issue).

- <reference to candidate id uc-NNNN if promoted>
