# Eval case 02 — uncertain author, fallback from B1 to B3

> Verifies that `voice-builder` does **not** silently fill defaults when
> the author cannot answer most questions, but instead offers to switch to
> path B3 (agent proposes from book artefacts). The TOV-08 strictness rule
> is preserved: no chapter prose is generated until a real profile exists.

## Setup

- Trigger: `book-writer` invokes the skill via the coordinator; author
  picks path **B1**.
- Book artefacts (mock): genre = memoir; audience = broad readers
  interested in family stories; plan thread = chronological with
  reflective interludes.
- Author replies "I don't know" or "no idea" to 3 of the 5 mandatory B1
  questions.

## Input — author replies

| Q | Author reply |
|---|---|
| Q1 — favourite writers in this genre | "I don't really read memoir, honestly." |
| Q2 — disliked moves | "No idea. I haven't thought about it." |
| Q3 — desired reader impression | "Hmm. I want them to feel something? Not sure." |
| Q4 — formality | "neutral, I guess." |
| Q5 — paragraph length | "no idea." |

## Expected `voice-builder` behaviour

After Q3, the skill detects ≥ 3 "I don't know" answers (signal-quality
threshold). It does **not** fall back to defaults silently.

It surfaces an `AskUserQuestion` with three options:

```
You answered "I don't know" to several questions. Three options:

1. switch to B3 — I read your book artefacts (project, audience, plan)
   and propose a profile with reasoning + a trial paragraph; you confirm.
2. continue B1 — I keep asking and we accept "I don't know" defaults at
   the end, with a low-confidence note in Reasoning.
3. stop — I leave voice-profile.md empty; book-writer will block again
   on the next /book:write-chapter, and you can come back via
   /book:voice build in a fresh session.
```

The expected author choice for this eval is **option 1** (switch to B3).

After the switch, the skill executes B3 — reads book artefacts, maps
signals to six parameters, generates a trial paragraph on the chapter
spec, and shows everything to the author per the standard B3 flow.

## Expected output (after B3 completes)

`.book/context/voice-profile.md` is populated with six values traced to
**book artefacts** (not to author replies, since the author had no
content to give). Sample reasoning entries:

- "Formality = neutral: genre = memoir; audience = broad → neither academic
  formality nor chatty informality fit."
- "Emotional intensity = warm: memoir + reflective interludes → warmth is
  required for the form to land; restrained would feel detached."
- "Paragraph length = medium: chronological narrative with reflection
  benefits from medium paragraphs (short feels staccato in story, long
  buries the reflective beats)."

The path field in `## Source signals` reads `B1 → B3 (uncertainty
fallback)`.

## Acceptance criteria

- The skill does **not** silently fill defaults after 3 "I don't know"
  replies.
- The skill surfaces a 3-option `AskUserQuestion` (switch to B3 / continue
  B1 / stop).
- On `switch to B3`, the skill executes the full B3 procedure (PS-08.1-09
  steps 1-4) and produces a complete profile.
- The `## Source signals` section logs the path transition.
- TOV-08 strictness preserved: at no point does `book-writer` generate
  any draft.md content for any chapter; the skill either returns a
  populated profile, or returns control to the coordinator with the
  `voice_pending` flag still set.

## Pass / fail

- **PASS** if the `AskUserQuestion` was raised, AND the profile after B3
  was populated from book artefacts, AND no parameter was filled with a
  bare default without traceable reasoning, AND `voice_pending` was either
  cleared (B3 success) or left set (author chose `stop`).
- **FAIL** if any parameter is filled silently with a default after
  uncertainty, OR if `book-writer` proceeded to draft.md before voice was
  resolved, OR if the path transition is not logged in Source signals.

## Privacy gate

- Eval uses generic genre and topic placeholders only.
- No real author identifiers.
