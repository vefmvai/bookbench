# Eval case 01 — clear author, path B1, full happy path

> Verifies that `voice-builder` projects clear, articulate B1 answers onto
> the six-parameter voice model with traceable reasoning, in under five
> minutes.

## Setup

- Trigger: `book-writer` finds `.book/context/voice-profile.md` empty for
  the first chapter; coordinator invokes `voice-builder` and the author
  picks path **B1**.
- Book artefacts (mock): genre = popular-science about photosynthesis;
  audience = broad / non-specialist; plan thread = personal stories +
  case studies.
- Author has clear references and a clean answer set.

## Input — author replies to the 5 mandatory B1 questions

| Q | Author reply |
|---|---|
| Q1 — favourite writers in this genre | "Sapolsky for the conversational tone over hard science. Annie Dillard for concrete observation against abstract reflection." |
| Q2 — disliked moves / forbidden constructions | "No `journey through the world of`. No `surprisingly`. No exclamation marks outside dialogue. No `it turns out`." |
| Q3 — desired reader impression in one sentence | "Like a long conversation with a friend who happens to be a serious scientist." |
| Q4 — formality (informal / neutral / formal) | "informal — but not chatty for the sake of it." |
| Q5 — paragraph length preference | "medium. Short paragraphs feel staccato; long ones bury the story beats." |

(Optional Q6 emotional, Q7 short passage — author skipped both.)

## Expected `voice-builder` output

### `.book/context/voice-profile.md`

The skill writes a file with all five sections (`## Prose description`,
`## Six-parameter values`, `## Reasoning`, `## Source signals`).

**Six-parameter values:**

- Formality: **neutral-to-informal** (lean informal). Author said "informal
  but not chatty"; named one writer who lives in informal-to-neutral.
- Paragraph length: **medium**. Author stated this directly with a clear
  rationale.
- Sentence variety: **mixed**. Annie Dillard signal — short against long.
- Emotional intensity: **warm**. "Long conversation with a friend" implies
  warmth; not minimal, not vivid.
- Dash typography: **medium dash**. Default; no signal pulling toward long
  dash.
- Anglicism tolerance: **moderate**. Default; no signal either way.

### `.book/voice-profile.yaml`

Contains the same six values in machine form.

### `## Reasoning` section content

Each parameter has at least one sentence tracing its value back to a
specific signal. For example:

- "Formality = neutral-to-informal: author named Sapolsky (conversational
  popular-science writer) and said `informal but not chatty`, so we lean
  informal but stop short of register that loses factual support."
- "Paragraph length = medium: stated directly with rationale (`short feels
  staccato, long buries story beats`)."

## Acceptance criteria

- All six parameters are filled with one of the values listed in the
  `voice-profile` skill's parameter ranges.
- Each parameter has a reasoning sentence in `## Reasoning` that names a
  specific source signal (writer, disliked move, or impression target).
- No fabricated source signals (the skill must not invent writers the
  author did not name).
- Time to complete ≤ 5 minutes from first question to file written.
- File `.book/agent-guidelines/writer/voice-samples.md` is **not** modified
  (author skipped Q7 → no passage to write).

## Pass / fail

- **PASS** if every parameter value above matches expected with at most one
  one-step deviation on the slider (e.g., `informal` instead of
  `neutral-to-informal` is acceptable; `formal` is not), AND every
  parameter has a non-empty reasoning entry, AND no writer is named in
  the reasoning that the author did not mention.
- **FAIL** if any parameter is missing, OR if the reasoning contains an
  invented writer, OR if `voice-samples.md` was written without author
  input.

## Privacy gate

- Eval uses generic public examples only (Sapolsky, Annie Dillard).
- No real author identifiers, no book topic specifics beyond the generic
  "photosynthesis" placeholder.
