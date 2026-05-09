# Genre-researcher evaluation case 04: no-internet fallback (Fallback A)

## Input

User runs `/book:research-genre fantasy --offline`. The `--offline` flag
forces `run_environment: no-internet` regardless of actual network state.
WebSearch and any MCP servers are not invoked.

## Expected behaviors

- Phase 1 (genre profiling) still runs — AskUserQuestion is local, no
  internet required. The author answers 5–10 questions about subgenre,
  audience, factuality, etc.
- Phase 2 (deep research) detects `run_environment: no-internet` and jumps
  to Fallback A.
- The skill offers three options via AskUserQuestion:
  (a) use the nearest built-in preset (popular-science in 0.1) with a
      `# FALLBACK: built-in <preset> applied due to no internet` comment;
  (b) import a genre handbook PDF/EPUB via `/book:import` and re-run;
  (c) defer generation; persist `genre_profile` to
      `${CLAUDE_PLUGIN_DATA}/deferred-generations/fantasy.yaml` and stop.
- For option (c), the file is written and the command exits cleanly.
- For options (a) and (b), the next steps are handed off to the
  appropriate command and the researcher does not persist a
  fantasy-methodology.md (because option (a) reuses the built-in, and
  option (b) needs a re-run after import).

## Acceptance criteria

- WebSearch and WebFetch are not called during the run trace.
- For option (c): `${CLAUDE_PLUGIN_DATA}/deferred-generations/fantasy.yaml`
  exists and contains a valid `genre_profile` YAML structure.
- The methodology and preset files are NOT created in user-methodologies/
  or user-presets/ (because the deferred-genre flow does not produce a
  full package).
- The next-step message names the command the author should run when
  internet is available (`/book:research-genre fantasy --refresh`).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the no-internet fallback. Common failure: the skill silently
proceeds with a hallucinated methodology based on prompt-internal
knowledge of fantasy as a genre. The Constitution forbids this — only
generic placeholder examples; nothing positing factual claims about the
genre that have no source.

## Why fantasy and not detective

We use `detective` in case-01 (happy path with internet), so case-04
deliberately picks a different generic genre to avoid test interaction
artefacts. `fantasy` is also a good no-internet test because the author's
prompt-internal knowledge of fantasy is rich enough that a careless skill
might be tempted to generate without flagging confidence — the test
catches that failure mode.
