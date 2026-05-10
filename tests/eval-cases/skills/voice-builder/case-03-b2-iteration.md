# Eval case 03 — B2 path with one trial-paragraph iteration

> Verifies that path B2 in `voice-builder` correctly handles author
> feedback on the trial paragraph: rewrites only the affected parameter,
> regenerates one new trial paragraph, and respects the cap = 2 iterations.

## Setup

- Trigger: author opens a fresh Claude Code tab and runs
  `/bookbench:voice build --mode=serious`. Path **B2** with a trial paragraph
  and at least one feedback iteration.
- Book artefacts (mock): genre = popular-science about migration of birds;
  audience = curious general readers; plan thread = field-observation
  vignettes.
- Author has clear references but the first trial paragraph misses on
  emotional intensity.

## Input — B2 questionnaire (B1 + Q6 + Q7 mandatory)

| Q | Author reply |
|---|---|
| Q1 — favourite writers | "Helen Macdonald in `H is for Hawk`. Also Robert MacFarlane on landscapes." |
| Q2 — disliked moves | "No `surprisingly`. No `it turns out`. No `this is fascinating`." |
| Q3 — impression | "Like a careful witness telling me what they saw." |
| Q4 — formality | "neutral, leaning literary." |
| Q5 — paragraph length | "long is fine when the observation has depth, otherwise medium." |
| Q6 — emotional or restrained | "restrained on the surface; warm underneath." |
| Q7 — short passage | (skipped) |

## Expected first trial paragraph (mock)

`book-writer` generates 200-300 words on a neutral topic (default: a
coffee-shop morning) calibrated to: formality=neutral, paragraph
length=medium-to-long, sentence variety=mixed, emotional intensity=
restrained, dash typography=medium dash, anglicism tolerance=moderate.

Author feedback after seeing the paragraph:

> "The observation is clean but the paragraph reads cold. I asked for
> restrained-on-the-surface, warm-underneath; this is just dry."

## Expected `voice-builder` behaviour after feedback

1. Identifies the failing parameter from the author's feedback as
   `emotional intensity`.
2. Rewrites **only** the `emotional intensity` entry in `## Reasoning`
   from `restrained` to `warm` (one step on the slider, retaining the
   "underneath" idea via Source signals).
3. Does **not** rewrite other parameters.
4. Regenerates **one** trial paragraph with the updated profile —
   iteration 2.
5. Shows the new paragraph and asks again: `mine` / `not mine` /
   `partly`.

## Cap = 2 enforcement

If the author responds again with negative feedback after iteration 2,
the skill **stops** and tells the author:

> "Two iterations did not converge. Two iterations not converging
> usually means the interview missed a reference rather than the model
> failed. Try `/bookbench:voice rebuild` after writing one short experimental
> section, or import a voice sample via `/bookbench:import voice-sample`."

The cap is honoured: the skill never generates a third trial paragraph
inside this skill invocation.

## Expected final state (assuming author approves iteration 2)

- `.book/context/voice-profile.md` is written with six values where only
  `emotional intensity` differs from the post-questionnaire state.
- `## Reasoning` section's emotional intensity entry references the
  iteration: "Adjusted from restrained to warm after the first trial
  paragraph read cold; matches `restrained on surface, warm underneath`
  from Q6."
- `## Source signals` records `Path used: B2 (1 iteration)`.

## Acceptance criteria

- After feedback, only the failing parameter is rewritten.
- The new trial paragraph is generated **once**.
- If a second negative feedback arrives, the skill stops with the
  rebuild-or-import message; it does not start a third iteration.
- `Path used` records the iteration count.

## Pass / fail

- **PASS** if exactly one parameter rewrite occurred per feedback round,
  AND the cap = 2 was enforced (no third iteration), AND the iteration
  count is recorded in Source signals.
- **FAIL** if multiple parameters were rewritten on a single feedback
  round, OR if a third trial paragraph was generated, OR if the
  iteration count was not recorded.

## Privacy gate

- Eval uses generic public examples (Helen Macdonald, Robert MacFarlane —
  both well-known authors broadly recognised in nature writing).
- No real author identifiers; no book-specific spoilers.
