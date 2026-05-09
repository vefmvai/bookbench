---
name: voice-builder
description: Строит профиль голоса (voice profile) книги с нуля, когда нет исходных текстов для импорта. Активируется из агента book-writer перед первым draft.md, из команды /book:voice build в выделенной сессии или из /book:voice rebuild. Предлагает три пути — B1 быстрое интервью ~5 минут, B2 серьёзная выделенная сессия ~15-20 минут с тестовым абзацем и итерацией, B3 агент сам предлагает профиль из артефактов книги. Проецирует абстрактные ответы автора (любимые писатели, желаемое впечатление у читателя) на шестипараметрическую модель голоса из скилла voice-profile. На выходе — заполненный .book/context/voice-profile.md с обязательной секцией Reasoning. Не активируется на /book:start, /book:plan-book, /book:plan-chapter и /book:discuss-chapter — на стадиях планирования голос ещё не применяется.
model: sonnet
---

# Voice builder skill

## When to use

Activated in three triggers, never otherwise:

1. From the body of `book-writer` — when the writer prepares to generate the
   first `chapters/<N>/draft.md` of the book and finds `.book/context/voice-profile.md`
   empty or containing only TBD placeholders. The writer stops, returns a
   `voice_pending` diagnostic to the coordinator, and the coordinator invokes
   this skill via `AskUserQuestion` over the three paths B1/B2/B3.
2. From the explicit command `/book:voice build` (a dedicated session with
   `--mode=quick|serious` and an optional `--rebuild` flag).
3. From the explicit command `/book:voice rebuild` (alias of
   `/book:voice build --rebuild`) — when the author wants to redo voice from
   scratch, e.g., after writing the first three chapters and realising the
   voice is wrong.

**Never activated on** `/book:start`, `/book:plan-book`, `/book:plan-chapter`,
or `/book:discuss-chapter`. Reason: at those stages no chapter prose is being
generated, so a voice profile is not yet needed; deferring the work until the
first chapter avoids forcing the author into a 5-15 min decision while they
are still shaping the book idea. Gate enforcement happens in the body of
`book-writer` (constitution NEVER rule) — see related skill `voice-profile`.

## Three paths

The author chooses one of three paths via `AskUserQuestion` with three buttons.
The default is not preset — the author must choose.

| Path | Time | Where it runs | Who leads | Pick when |
|------|------|---------------|-----------|-----------|
| B1 — quick interview | ~5 min | inline in current session | author answers, builder maps | author has clear references and wants to keep momentum |
| B2 — dedicated session | ~15-20 min | new tab, `/book:voice build` | author + builder, with a sample paragraph and one optional iteration | author wants to give voice serious attention |
| B3 — agent proposes | ~2-3 min to confirm | inline, builder reads book artefacts | builder leads, author confirms | author cannot articulate references or wants to start fast |

All three paths converge on the same output contract — a filled
`.book/context/voice-profile.md` with a mandatory `## Reasoning` section.

## Path B1 — quick interview here (~5 min)

Use `AskUserQuestion` per question; never proceed silently if the author
dismisses one. Five questions are mandatory; two are optional (Q6 and Q7).

### Q1. Favorite writers or bloggers in this genre, and what you like in their writing

Examples to seed the answer:

- "Sapolsky writes complex science as a long conversation with a witty
  friend — informal register, generous emotional range, paragraphs that
  breathe."
- "Annie Dillard threads concrete observation through abstract reflection;
  short sentences against long ones; rare adjectives, exact nouns."
- "If you cannot name a writer, name a podcast or a long-form blogger you
  re-read."

### Q2. Disliked moves or forbidden constructions

The author must give an explicit list, not a feeling. Examples:

- "No `journey through the world of X`."
- "No `surprisingly`, no `it turns out`."
- "No exclamation marks except in dialogue."
- "No `in conclusion`, no `in summary`."

### Q3. Desired reader impression in one sentence

Examples:

- "Like a conversation with a knowledgeable friend over coffee."
- "Like a quiet, careful lecture that respects my time."
- "Like a private letter from someone who has thought a lot about this."

### Q4. Register formality (informal / neutral / formal)

With three short examples — pick the one closest to your taste.

### Q5. Paragraph length preference (short / medium / long)

"Which length is more pleasant to read in the books you love?"

### Q6 (optional). Emotional or restrained tone

Pick one; this maps directly to the `emotional intensity` parameter.

### Q7 (optional). 1-2 short passages from your own writing

If the author can paste 200-400 words of their own non-book prose, store it
in `.book/agent-guidelines/writer/voice-samples.md` (do not invent samples).

### Pseudo-dialogue B1

```
[builder]
Path B1 — quick interview, about five minutes.
Question 1 of 5: Name two or three writers or bloggers in your genre whose
prose you love. One sentence per author about what you like in their writing.

[author]
Sapolsky for the conversational tone. The "Slate Star Codex" blog for
the careful structure of long arguments.

[builder]
Question 2 of 5: List the moves or phrases you do not want to see in your
book. Be concrete (no `journey through`, no `surprisingly`, etc.).

[author]
No `journey`, no `surprisingly`, no exclamation marks outside dialogue.

[... Q3..Q5, optionally Q6..Q7 ...]

[builder]
Got it. Drafting the profile now (see § Algorithm). I will write it to
.book/context/voice-profile.md and show you a Reasoning section that explains
each parameter choice.
```

## Path B2 — serious dedicated session (~15-20 min)

This path is invoked from `/book:voice build` in a fresh Claude Code tab.

1. Run all five mandatory questions of B1, plus Q6 and Q7 (both upgraded to
   mandatory in B2).
2. Paraphrase the answers back to the author in one paragraph: "I read your
   voice as informal-to-neutral, medium paragraphs, restrained-to-warm
   emotional intensity, dash medium, anglicism moderate."
3. Hand off to `book-writer` to generate one trial paragraph of 200-300 words
   on a neutral topic (default: a short scene about a coffee shop morning;
   author may override the topic).
4. Show the trial paragraph plus the draft profile.
5. `AskUserQuestion` with three buttons: `mine` / `not mine` / `partly — let's
   edit specific parameters`.
6. On `partly`, walk the six parameters one by one; collect deltas; rewrite
   the profile; generate one more trial paragraph (this is iteration 2).
7. **Cap = 2 iterations.** After two iterations, stop and tell the author:
   "Two iterations did not converge. This usually means the interview did
   not capture the right signal; try `/book:voice rebuild` after writing
   one short experimental section, or import an external voice sample via
   `/book:import voice-sample`."
8. On final `mine`, persist the profile and, if the author provided a passage
   in Q7, write it to `voice-samples.md`.

Cap rationale: more than two iterations almost always indicates a missing
input (e.g., the author has a writer in mind but did not name them) rather
than a model failure. Forcing a re-entry through `rebuild` after some real
draft text gives the next pass a much stronger signal than a third synthetic
trial paragraph.

## Path B3 — agent proposes from book artefacts (~2-3 min)

Numbered Procedure (PS-08.1-09).

### Step 1 — Read book artefacts

Read all of:

- `.book/PROJECT.md` (or the equivalent topic file produced at `/book:start`)
  for the genre, topic, and author intent;
- `.book/context/target-audience.md` for the audience profile;
- `.book/chapters/<N>/spec.md` for the current chapter (the one the writer
  is about to draft);
- `.book/ROADMAP.md` for the overall plan flavour (e.g., "personal stories
  thread", "case-study heavy", "technical-deep-dive").

### Step 2 — Map signals to the 6 parameters

For each of the six voice-profile parameters, derive a value with explicit
reasoning. Examples:

- "Genre = popular-science → formality = neutral (not formal: audience is not
  academic; not informal: factual claims need register support)."
- "Audience = broad, non-specialist → emotional intensity = restrained (not
  minimal: warmth helps a lay reader stay; not vivid: would feel theatrical
  for science writing)."
- "Plan thread = personal stories → paragraph length = medium (anchors
  experiential prose; short feels staccato, long buries the story beats)."

### Step 3 — Generate trial paragraph

Hand off to `book-writer` to generate 200-300 words on the topic of the
**current chapter spec**, not on a neutral coffee-shop topic — this lets the
author judge the voice on the real subject matter.

### Step 4 — Show profile + reasoning + trial paragraph; gate

Show the author all three artefacts at once (TOV-12 transparency). Then
`AskUserQuestion` with three buttons:

```
fits — apply
partly — let's edit specific parameters
not fitting — switch to B1 interview
```

On `partly`, walk only the affected parameter(s); rewrite only their entries
in the Reasoning section; do not regenerate from scratch. On `not fitting`,
discard the proposal and start B1 from Q1.

### Pseudo-dialogue B3

```
[builder]
Path B3 — I propose a voice profile from the artefacts of your book.
Reading PROJECT.md, context/target-audience.md, chapters/01/spec.md and
ROADMAP.md … done.

Proposal: formality=neutral, paragraph length=medium, sentence variety=mixed,
emotional intensity=restrained, dash typography=medium dash, anglicism
tolerance=moderate.

Reasoning (short): popular-science genre + broad audience + personal-story
plan thread → neutral register + medium paragraphs + restrained warmth.

Trial paragraph on the topic of chapter 1 (200-300 words):
"<paragraph here>"

[builder asks]
Does this fit?
- fits — apply
- partly — let's edit specific parameters
- not fitting — switch to B1 interview
```

## Algorithm — projecting abstract answers to 6 parameters

This is the heart of the skill. Used by both B1 (signals from the author)
and B3 (signals from book artefacts). Numbered Procedure of five steps
(PS-08.1-08).

### Step 1 — Collect signals

Build three signal sets:

- **Reference signals** — favourite writers and bloggers (B1 Q1) or genre
  conventions (B3). Each reference projects onto the 6 parameters; treat
  each as a soft vote.
- **Negative constraints** — disliked moves and forbidden constructions
  (B1 Q2) or genre-incompatible patterns (B3). Each negative excludes a
  region of the parameter space.
- **Impression target** — desired reader impression in one sentence (B1 Q3)
  or audience profile + plan thread (B3). This sets the emotional intensity
  baseline and informs paragraph length.

### Step 2 — Map signals to 6 heuristic values

For each of the six parameters (formality, paragraph length, sentence
variety, emotional intensity, dash typography, anglicism tolerance), pick
a value via the rules below. **Always state the reasoning out loud** — the
text becomes the parameter's entry in the `## Reasoning` section.

Heuristic examples (illustrative, not exhaustive):

- "Author named a conversational science writer + said `like a conversation
  with a friend` → formality=informal-to-neutral; emotional intensity=warm."
- "Author named a careful long-form blogger + said `respects my time` →
  paragraph length=medium; sentence variety=mixed; emotional intensity=
  restrained."
- "Author dislikes `journey through` and `surprisingly` → exclude clickbait
  register; lock formality at neutral or higher."

### Step 3 — Consistency check

Walk every pair of parameter values. If two values create a known clash,
flag it and ask one clarifying question.

Examples of clashes:

- formality=informal **and** named author = academic-leaning (e.g., Kahneman
  for popular-science): "You said informal, but you also named an academic
  writer. Which do you want closer — the conversational tone, or the
  precise register? Pick one and we move on."
- emotional intensity=minimal **and** desired impression = "warm letter":
  contradictory; ask which wins.
- dash typography=long dash **and** anglicism tolerance=strict: rare but
  not impossible; only flag if author also said `traditional Russian
  publishing register`.

If the author cannot resolve the clash in one question, default to the
**weaker** of the two values (closer to the centre of the slider) and note
it in `## Reasoning`.

### Step 4 — Compose the prose-style description

Write a short prose paragraph (3-5 sentences) describing how the voice
sounds when read aloud — not the parameter list, but the lived feeling.
This paragraph belongs at the top of `voice-profile.md` and reads to a
human, not to a parameter-checker.

Example prose for `informal-to-neutral, medium, mixed, warm, medium dash,
moderate`:

> Conversational but precise. Sentences vary in length — short for
> emphasis, long when the idea has parts. Emotional warmth shows up as
> direct address and the occasional aside, never as exclamation. Dashes
> are medium; anglicisms appear when no Russian word fits.

### Step 5 — Write to file with Reasoning section

Compose `.book/context/voice-profile.md` with this structure:

```markdown
# Voice profile

## Prose description
<the paragraph from Step 4>

## Six-parameter values
- Formality: <value>
- Paragraph length: <value>
- Sentence variety: <value>
- Emotional intensity: <value>
- Dash typography: <value>
- Anglicism tolerance: <value>

## Reasoning
- Formality = <value>: <one or two sentences from Step 2>.
- Paragraph length = <value>: <one or two sentences from Step 2>.
- Sentence variety = <value>: <reasoning>.
- Emotional intensity = <value>: <reasoning>.
- Dash typography = <value>: <reasoning>.
- Anglicism tolerance = <value>: <reasoning>.

## Source signals
- Reference signals: <list of writers and what was taken from each>.
- Negative constraints: <list>.
- Impression target: <one sentence>.
- Path used: B1 / B2 / B3.
```

Also write the same six values to `.book/voice-profile.yaml` (consumed by
the anti-cliche module — see related skill `voice-profile` for the contract).

## Output contract

Two artefacts after a successful run:

1. `.book/context/voice-profile.md` — populated per the structure above.
   The `## Reasoning` section is **mandatory** (TOV-12 transparency).
2. `.book/voice-profile.yaml` — the same six values for machine consumers.

One optional artefact:

3. `.book/agent-guidelines/writer/voice-samples.md` — populated only if the
   author provided 1-2 short passages of their own writing during B1 Q7 or
   B2 Q7.

The skill never writes anywhere else. In particular, it never writes inside
the plugin code tree (no writes to `bookbench/` or `${CLAUDE_PLUGIN_ROOT}`).

The actual voice content lives in the book folder, not in the plugin.

## Tests

- Test 1 — given B1 with five clear answers (Sapolsky, no `journey`, "warm
  conversation", informal, medium, warm) the skill produces a profile with
  `formality=informal`, `paragraph length=medium`, `emotional intensity=
  warm`, and a Reasoning section that names the source for each value.
- Test 2 — given B2 with one iteration (author says trial paragraph is
  "too dry") the skill rewrites the emotional intensity entry only,
  regenerates one trial paragraph, and stops if the author says "still dry"
  on the second iteration (cap=2 reached).
- Test 3 — given B3 with `genre=popular-science`, `audience=broad`,
  `plan thread=personal stories`, the skill produces a profile with
  `formality=neutral`, `emotional intensity=restrained`, `paragraph length=
  medium`, and a Reasoning section that traces each value back to the
  artefact it came from.

## Files

This skill ships only `SKILL.md`, `quality-gate.md`, and the four eval
cases in `tests/eval-cases/skills/voice-builder/`. It has no extra reference files.
The actual voice content lives in the book folder, not in the plugin.

## Notes

- This skill never carries time-sensitive information. No specific years,
  no specific model versions, no "current best practice" claims.
- Model `sonnet` is chosen as the balance of analytical mapping and
  generation of short prose. `haiku` is too thin for the consistency check
  in Step 3; `opus` is overkill for a 200-300 word trial paragraph and
  doubles cost without quality gain at this scope.
- Cap = 2 iterations in B2 is intentional. More iterations indicate a
  signal-quality problem (interview missed the right reference), not a
  model problem; the right next move is `/book:voice rebuild` after some
  real draft text exists.
- Reference signal vocabulary stays generic in this skill body
  (`Sapolsky`, `Kahneman`, `Annie Dillard` — public, broadly recognised
  examples of voice flavours). Real author voice profiles live in the
  book folder and never in the plugin.
- This skill complements the `voice-profile` skill: this one *builds* the
  voice-profile.md; the other one explains *how the writer reads it* at
  chapter start.
