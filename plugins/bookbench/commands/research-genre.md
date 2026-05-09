---
description: Researches a target literary genre on demand and produces a methodology plus a workflow preset under ${CLAUDE_PLUGIN_DATA}. Activates the genre-researcher skill in the main dialogue. Refresh regenerates an existing preset; offline forces the no-internet fallback. Output is two or three files saved to user-presets, user-methodologies, and optionally user-skills, after a five-level validation gate and an explicit author confirmation.
argument-hint: "<genre> [--refresh] [--offline] [--interactive]"
allowed-tools: [Read, Write, AskUserQuestion, WebSearch, WebFetch, Task, Bash, Glob]
---

# /book:research-genre

<purpose>
Run the genre-researcher skill to produce a methodology + workflow preset
package for the requested genre. This command is the explicit invocation
form (the implicit form is the unknown-genre branch of `/book:start`).
</purpose>

<!-- Stage 14, Wave B, T3: full implementation. -->

## Step 1 — Parse arguments

```bash
RAW="${ARGUMENTS:-}"
GENRE=""
REFRESH=0
OFFLINE=0
INTERACTIVE=0

set -- $RAW
GENRE="${1:-}"
shift 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --refresh)     REFRESH=1 ;;
    --offline)     OFFLINE=1 ;;
    --interactive) INTERACTIVE=1 ;;
    *) echo "research-genre: unknown flag '$1'" 1>&2 ;;
  esac
  shift
done

if [ -z "$GENRE" ]; then
  echo "Usage: /book:research-genre <genre> [--refresh] [--offline] [--interactive]"
  echo "Examples:"
  echo "  /book:research-genre detective"
  echo "  /book:research-genre memoir --refresh"
  echo "  /book:research-genre fantasy --offline"
  exit 0
fi
echo "research-genre: genre='$GENRE' refresh=$REFRESH offline=$OFFLINE interactive=$INTERACTIVE"
```

## Step 2 — Resolve plugin paths

```bash
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
[ -z "$PLUGIN_DATA" ] && {
  if [ -n "${LOCALAPPDATA:-}" ]; then PLUGIN_DATA="$LOCALAPPDATA/bookbench"
  else PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"; fi
}
mkdir -p \
  "$PLUGIN_DATA/user-methodologies" \
  "$PLUGIN_DATA/user-presets" \
  "$PLUGIN_DATA/user-skills" \
  "$PLUGIN_DATA/research-archives" \
  "$PLUGIN_DATA/deferred-generations"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && {
  for c in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    [ -f "$c/manifest.json" ] && PLUGIN_ROOT="$c" && break
  done
}
[ -z "$PLUGIN_ROOT" ] && {
  echo "research-genre: cannot resolve CLAUDE_PLUGIN_ROOT. Set the env var or reinstall the plugin."
  exit 0
}
echo "research-genre: plugin_root=$PLUGIN_ROOT plugin_data=$PLUGIN_DATA"
```

## Step 3 — Slugify and pre-flight on existing files

```bash
SLUG="$(printf '%s' "$GENRE" | LC_ALL=C tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
PRESET_FILE="$PLUGIN_DATA/user-presets/$SLUG.yaml"
METHOD_FILE="$PLUGIN_DATA/user-methodologies/$SLUG-methodology.md"
HAS_PRESET=0
[ -f "$PRESET_FILE" ] && HAS_PRESET=1

if [ "$HAS_PRESET" -eq 1 ] && [ "$REFRESH" -eq 0 ]; then
  echo "research-genre: a preset for '$SLUG' already exists at $PRESET_FILE."
  echo "Run with --refresh to regenerate it, or use /book:start --genre $SLUG to start a book on the cached preset."
  exit 0
fi

if [ "$HAS_PRESET" -eq 1 ] && [ "$REFRESH" -eq 1 ]; then
  TS_PREV="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
  mkdir -p "$PLUGIN_DATA/research-archives/$SLUG"
  cp "$PRESET_FILE" "$PLUGIN_DATA/research-archives/$SLUG/$TS_PREV-prev-preset.yaml" 2>/dev/null || true
  cp "$METHOD_FILE" "$PLUGIN_DATA/research-archives/$SLUG/$TS_PREV-prev-methodology.md" 2>/dev/null || true
  echo "research-genre: refresh mode — backed up previous package to research-archives/$SLUG/$TS_PREV-*"
fi
```

## Step 4 — Built-in genre check (skip the researcher)

If the requested genre is already shipped as a built-in (e.g.,
`popular-science` in 0.1), the researcher is **not** needed.

```bash
BUILTIN_DIR="$PLUGIN_ROOT/skills/genres/$SLUG"
if [ -d "$BUILTIN_DIR" ] && [ "$REFRESH" -eq 0 ]; then
  echo "research-genre: '$SLUG' is a built-in genre at $BUILTIN_DIR; no research needed."
  echo "Run /book:start --genre $SLUG to use the built-in preset directly."
  exit 0
fi
```

## Step 5 — Decide run environment

```bash
if [ "$OFFLINE" -eq 1 ]; then
  ENV="no-internet"
else
  ENV="normal"
fi
echo "research-genre: run_environment=$ENV"
```

## Step 6 — Phase 1: genre profiling (AskUserQuestion)

The model uses AskUserQuestion to ask 5–10 short questions covering:

- subgenre / variant;
- target audience (broad / specialist / age band);
- factuality (fictional / documentary / hybrid);
- whether external research / factcheck is needed;
- whether internal consistency / worldbuilding matters;
- sensitivity / ethical review needs;
- target section and book length.

The questions are skill-driven — the genre-researcher's body
(`${CLAUDE_PLUGIN_ROOT}/skills/genre-researcher/SKILL.md` § 4 Phase 1)
specifies them. The command pipes the answers into the Task call below.

If the author dismisses the questions or the answers are insufficient:

```text
research-genre: aborting — Phase 1 needs at least subgenre, audience, and factuality.
```

## Step 7 — Phase 2–5: invoke the researcher

The actual research, methodology generation, workflow generation, and
validation happen inside the genre-researcher skill. The skill is loaded
into the calling agent's context via the `skills:` mechanism; this command
delegates execution through Task with `subagent_type: book-strategist` —
the strategist owns the upstream creative reasoning and is the natural
container for the researcher skill (the researcher itself is a Skill, not
a Subagent — TR-06).

```text
Task(
  subagent_type="book-strategist",
  prompt="""
  Activate the genre-researcher skill (it is in your skills: list).
  Run all five phases for genre "${GENRE}" with:
    - run_environment: ${ENV}
    - mode: ${REFRESH:+refresh}${REFRESH:-fresh}
    - interactive: ${INTERACTIVE}
    - genre_profile_answers: <piped from Step 6 AskUserQuestion>

  After Phase 5 — Type-to-Confirm gate — return three named blocks:
    1. methodology_text — the contents of <genre>-methodology.md
    2. preset_yaml      — the contents of <genre>.yaml
    3. critical_skill_text (optional) — the contents of <critical-skill>.md
       OR an empty marker "no-new-skill"
    4. genre_profile    — the YAML structure (for the research-archive)
    5. sources_summary  — list of {title, url, category} (for the archive)
    6. validation_report — the result of the five-level pipeline

  Honour the skill's Constitution: never write to ${CLAUDE_PLUGIN_ROOT};
  never introduce a tenth role; never include time-sensitive content;
  never persist anything without the explicit APPLY <genre> author
  confirmation in Phase 5.

  If the author chose CANCEL — return the validation_report and the
  partial outputs labelled with status: cancelled (the command will
  move them to ${CLAUDE_PLUGIN_DATA}/pending/).
  """,
  description="Run the five-phase genre-researcher pipeline."
)
```

## Step 8 — Verify outputs and persist

The model parses the Task return-value and:

1. If `validation_report.cancelled == true`:

   ```bash
   PEND="$PLUGIN_DATA/pending/$SLUG-$TS_PREV"
   mkdir -p "$PEND"
   ```
   Write the partial methodology / preset / critical-skill to the pending
   tree and exit with:

   ```text
   research-genre: author cancelled. Partial outputs at $PEND. Nothing persisted to user-presets/.
   ```

2. Otherwise, write the artefacts via the Write tool:

   ```text
   ${CLAUDE_PLUGIN_DATA}/user-methodologies/<slug>-methodology.md  ← from methodology_text
   ${CLAUDE_PLUGIN_DATA}/user-presets/<slug>.yaml                  ← from preset_yaml
   ${CLAUDE_PLUGIN_DATA}/user-skills/<critical-skill>.md           ← only if critical_skill_text != "no-new-skill"
   ${CLAUDE_PLUGIN_DATA}/research-archives/<slug>/<timestamp>.yaml ← from genre_profile + sources_summary
   ```

3. Append a one-line entry to
   `${CLAUDE_PLUGIN_DATA}/research-attempts.log`:

   ```text
   <ISO timestamp> | genre=<slug> | env=<ENV> | sources=<N> | status=<applied|cancelled> | confidence=<high|medium|low>
   ```

## Step 9 — Atomic state mutation

If the author was running this command from inside a book directory (i.e.,
`.book/` exists at the cwd), append a one-line entry to `.book/STATE.md`
in the History section:

```text
- <ISO timestamp> | /book:research-genre <slug> | confidence=<high|medium|low> | status=applied
```

This is **not** required when the command is run outside a book context
(e.g., during onboarding before `/book:start` has scaffolded `.book/`).

## Step 10 — Next-step message

```text
research-genre: persisted package for "$SLUG":
  - $METHOD_FILE
  - $PRESET_FILE
  $(if optional skill written) - $PLUGIN_DATA/user-skills/$SLUG-...md

Next steps:
  - Start a new book with this preset:
      /book:start --genre $SLUG
  - Inspect the preset:
      /book:list (after starting a book)
  - Refine the package later:
      /book:research-genre $SLUG --refresh
```

## Notes

- This command is the explicit form. The implicit form is invoked from
  `/book:start` branch B (when the author picks an unknown genre); that
  flow re-uses the same Task delegation but skips the slug pre-flight and
  the next-step message (it is part of the larger `/book:start` UX).
- The skill writes only to `${CLAUDE_PLUGIN_DATA}` (cross-platform user
  data, survives `/plugin update`). It never writes to
  `${CLAUDE_PLUGIN_ROOT}` (read-only at runtime).
- `--refresh` archives the previous package before regenerating, so the
  author can roll back manually if the new package is worse.
- `--offline` triggers Fallback A (no-internet) inside the skill; the
  resulting package is marked `confidence: low` in the methodology
  frontmatter and the author is invited to refine it via
  `/book:tune:guidelines` later.
- Privacy guarantee: the researcher reads from the public web and from
  built-in plugin sources only. It does not read any book directory's
  `sections/`, `inputs/`, `intel/`, `debug/`, or `agent-memory/`.
