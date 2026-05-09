# Eval case 04 — B3 partial parameter edit, no full restart

> Verifies that on path B3, when the author chooses `partly — let's edit
> specific parameters`, the skill rewrites only the named parameter(s)
> without regenerating the entire profile. The Reasoning section is
> updated only for the changed parameter.

## Setup

- Trigger: `book-writer` invokes the skill via the coordinator; author
  picks path **B3** (agent proposes from book artefacts).
- Book artefacts (mock):
  - genre = popular-science about computational biology;
  - audience = mix of biologists who know computing poorly and computer
    scientists who know biology poorly;
  - plan thread = case-study heavy; section 1 = a vignette about a single
    research lab.
- Skill executes B3 steps 1-4 and produces a proposal.

## Input — B3 proposal (skill-generated, mock)

```
formality = neutral
paragraph length = medium
sentence variety = mixed
emotional intensity = restrained
dash typography = medium dash
anglicism tolerance = moderate
```

Reasoning section (mock):

- "Formality = neutral: cross-audience genre — must respect both expert
  registers; informal would feel sloppy to the biologists, formal would
  feel stiff to the engineers."
- "Paragraph length = medium: case-study vignettes need room to breathe
  but not deep digressions."
- (etc.)

Trial paragraph on the topic of section 1 (a research-lab vignette) is
shown to the author together with the profile and reasoning.

## Author feedback

> "Mostly good. But change formality from `neutral` to `informal` —
> these are people working with code and pipettes, the book should feel
> hands-on, not academic."

## Expected `voice-builder` behaviour

1. Detects that **only** `formality` is being changed.
2. Updates `voice-profile.md`:
   - `formality` value: `neutral` → `informal`.
   - **Only** the `Formality = ...` entry in `## Reasoning` is rewritten,
     incorporating the author's hands-on rationale: "Formality = informal:
     author opted for hands-on register over academic; cross-audience is
     served by clarity and concreteness rather than register neutrality."
3. Other parameters and their reasoning entries are **unchanged**.
4. Updates `## Source signals` to record `Path used: B3 (1 partial edit)`.
5. Does **not** regenerate the trial paragraph by default; offers the
   author an `AskUserQuestion`:

   ```
   Apply the change to the profile only, or also regenerate the trial
   paragraph with the updated formality?
   - apply only
   - apply and regenerate
   ```

   If the author picks `apply only`, the skill writes the file and
   returns. If `apply and regenerate`, the skill hands off to writer for
   one fresh trial paragraph (this is **not** an iteration in the B2
   sense; it is a one-shot re-render of the same profile state).

## Acceptance criteria

- Exactly one parameter (`formality`) changes value.
- Exactly one Reasoning entry is rewritten.
- All other Reasoning entries are byte-identical to the proposal.
- The path log reads `B3 (1 partial edit)` (or equivalent format).
- The full B3 cycle is **not** restarted.

## Pass / fail

- **PASS** if only `formality` and its Reasoning entry are touched, AND
  the file is written without re-running B3 steps 1-4, AND the path log
  records the partial edit.
- **FAIL** if any other parameter or Reasoning entry was changed, OR if
  the entire profile was regenerated, OR if the path log is missing or
  inaccurate.

## Privacy gate

- Eval uses a generic genre placeholder (popular-science about
  computational biology).
- No real author identifiers; no specific book topic that could trace
  back to a private project.
