# Voice management

> How BookBench builds, edits, and reuses your author voice across books.
> See `skills/voice-profile/SKILL.md` for the underlying six-parameter model and
> `skills/voice-builder/SKILL.md` for the construction algorithm.

## What is the voice profile?

Every book in BookBench has a voice profile at `.book/context/voice-profile.md`.
It captures **how the prose sounds** as a short paragraph plus six parameters:

- **Formality** — informal / neutral / formal.
- **Paragraph length** — short / medium / long.
- **Sentence variety** — uniform / mixed / varied.
- **Emotional intensity** — restrained / warm / heated.
- **Dash typography** — none / medium / long-dash.
- **Anglicism tolerance** — strict / moderate / open.

The full model lives in `skills/voice-profile/SKILL.md` (68 lines). The writer
calibrates against it at the start of every chapter; the editor uses it as a
cohesion reference; the anti-cliche module reads its YAML twin
`.book/voice-profile.yaml` to pre-screen for register drift.

The voice profile is **author-owned content**. The framework writes it once
(via the voice-builder skill) and only re-writes it on explicit author request
through `/book:tune` or `/book:voice rebuild`.

## When does the voice gate fire?

The voice gate is enforced **inside the body of `book-writer`** (TOV-08), not
on `/book:start` and not at planning time. The trigger:

> Before generating any line of `chapters/<N>/draft.md`, the writer reads
> `.book/context/voice-profile.md` and stops if the file is empty or contains
> only TBD placeholders. It returns a `voice_pending` diagnostic to the
> coordinator, who then surfaces three paths to the author.

Why so late? A voice profile is irrelevant during planning — no prose is being
generated. Forcing the author into a 15-minute decision while the book idea is
still being shaped wastes attention. Deferring the gate to the first chapter
draft means the author already has a chapter spec, a target audience, and a
plan — the same artefacts the agent will draw on if the author chooses Path B3
(see below).

## Three paths to build a voice

When the gate fires, the author chooses one of three paths via
`AskUserQuestion`:

- **B1 — quick interview here, ~5 min.** Five questions answered inline in the
  current session; the voice-builder maps the answers onto the six parameters
  and writes the profile.
- **B2 — dedicated session, ~15-20 min.** Run `/book:voice build` in a fresh
  session. The skill conducts the same five questions, then generates a
  trial paragraph for the author to react to, with up to two iterations on
  the emotional intensity parameter.
- **B3 — agent proposes from book artefacts, ~2-3 min to confirm.** The
  voice-builder reads `PROJECT.md`, `target-audience.md`, the chapter spec,
  and `ROADMAP.md`, then proposes a profile with a sample paragraph on the
  current chapter topic. The author confirms, partially edits a parameter, or
  switches to B1.

The full algorithms (5-step projection from abstract answers to six
parameters; 4-step B3 proposal) are documented in
`skills/voice-builder/SKILL.md`. All three paths converge on the same output:
a filled `voice-profile.md` with a mandatory `## Reasoning` section that
explains why each parameter received its value (TOV-12 transparency).

## Five `/book:voice *` commands

| Command | What it does |
|---------|--------------|
| `/book:voice build [--mode=quick|serious] [--rebuild]` | Activates the voice-builder skill in a dedicated session. Default mode is `serious` (path B2). `--rebuild` overwrites an existing profile after a confirmation and a backup. |
| `/book:voice extract [--to-stdout|--to-file <path>]` | Packs the current book's profile and samples into a single self-contained markdown file. Read-only on `.book/`. By default streams to stdout. |
| `/book:voice save-as <name> [--overwrite]` | Saves the current voice as `<name>.md` in the personal library. Refuses to overwrite without `--overwrite`. |
| `/book:voice import <name>` | Copies `<name>.md` from the library into the current book; confirms before overwriting non-empty existing files; backs up replaced files into `.book/.backup/voice-profile/`. |
| `/book:voice list` | Lists every voice in the library with name, save date, and a short summary of the six parameters. Strictly read-only. |

`/book:voice rebuild` is an alias for `/book:voice build --rebuild` (PS-08.1-06).

## Personal voices library `~/.bookbench/voices/`

The library is a per-author, cross-book directory of saved voice packs
(TOV-02). It lives **outside the plugin tree and outside the book folder** so
the same voice is available to every book on the same machine.

Path resolution (PS-08.1-03), in order of precedence:

1. Environment variable `BOOKBENCH_VOICES_DIR`.
2. Key `voices_dir` in `~/.bookbench/config.yaml`.
3. Platform default:
   - macOS / Linux: `~/.bookbench/voices/`.
   - Windows (or WSL with `LOCALAPPDATA` exported): `%LOCALAPPDATA%/bookbench/voices/`,
     falling back to `%APPDATA%/bookbench/voices/`, falling back to
     `~/.bookbench/voices/`.

Each voice is a single markdown file with two pack sections (profile and
optional samples), separated by `<!-- VOICE-PACK: section=... -->` markers.
Authors can read and edit these files directly with any editor — the format
is human-friendly markdown, not an opaque binary.

Typical workflow for re-using a voice:

```bash
# In book A, after voice-builder has filled .book/context/voice-profile.md
/book:voice save-as my-warm-essay-voice

# Later, in book B
cd ../book-b
/book:voice list                          # see what is available
/book:voice import my-warm-essay-voice    # apply it to book B
```

## Editing the voice over time

Voices change as the book takes shape. BookBench supports two ways to evolve
a voice without losing the connection to past chapters:

- **`/book:tune`** — the tuner reviews recent `REJECTIONS.md` entries and
  voice-drift signals from the editor; it proposes targeted edits to one or
  two parameters with a sample paragraph for confirmation. Use this after
  writing 1-3 chapters when small adjustments are needed.
- **`/book:voice rebuild`** — full reset of the profile. The voice-builder
  runs again from scratch. The previous profile is backed up to
  `.book/.backup/voice-profile/voice-profile.<timestamp>.md`. Use this when
  the voice is structurally wrong, not just slightly off.

## 0.1 limitations

- **No `extends:` hierarchy.** Every voice file is self-contained; there is
  no way in 0.1 to declare «this voice extends `my-warm-essay-voice` and
  changes only `formality`». The TOV-04 decision deferred this to 0.2+ once
  there is real usage data showing whether authors actually want inheritance
  or whether copy-and-edit is sufficient. Trigger for revisiting: at least
  three authors report editing the same handful of parameters across many
  books.
- **No automatic voice transplant from imported books.** `/book:import`
  handles `voice-sample` files (Path A from etap 03) but does not currently
  back-fill the six-parameter profile from imported text. The voice-builder
  skill is invoked only via the gate, `/book:voice build`, or
  `/book:voice rebuild`.

## Privacy

Voice content is one of the most personal parts of a book project — it
contains the author's reading taste, writing identity, and sometimes short
passages of their own prose. BookBench treats it accordingly:

- **Public plugin repository contains no real voices** (TOV-01). The plugin
  ships only templates and methodology. The voice-builder examples reference
  publicly known authors as flavour signals; they are never the author's own
  voice.
- **Book template `.gitignore` excludes voice content by default** (TOV-05).
  When you scaffold a new book with `/book:start`, the resulting `.book/`
  folder includes a `.gitignore` that excludes `context/voice-profile.md` and
  `agent-guidelines/writer/voice-samples.md`. This is a **default safety net**
  — if you are running a public research project where voice transparency is
  the goal, comment out the relevant lines.
- **Personal library is outside the book folder.** `~/.bookbench/voices/` is
  not part of any git repository the author would publish. It is a
  per-machine, per-author space.
- **Privacy guards in commands.** Every `/book:voice *` command refuses to
  write inside the plugin tree (`${CLAUDE_PLUGIN_ROOT}`) and inside the
  current book when the destination is supposed to be the library
  (PS-08.1-07). The structural test `tests/voice-commands-privacy.test.sh`
  enforces this at every release.
