# Case 01: Cold start in a freshly-initialized book folder

## Input

A new Claude Code session opens in `/path/to/My Book/`. The folder is freshly
initialized via `/book:start`. STATE.md exists with `last_action: book_initialized`.
PROJECT.md, workflow.md, config.yaml, agent-guidelines/coordinator/README.md,
agent-memory/coordinator/MEMORY.md all exist.

The user enters: `/book:next`.

## Expected behaviors

- Coordinator runs Procedure COLD-START before doing anything else.
- Reads STATE.md, PROJECT.md, workflow.md, config.yaml, coordinator/MEMORY.md,
  agent-guidelines/coordinator/README.md (and files referenced from it).
- Greets the author with a short summary (3-5 lines): book title, current
  status, last action.
- Then transitions into Procedure ANSWER-NEXT-STEP and proposes the next
  command (typically `/book:plan-book` for a freshly-initialized book).
- Response uses the three-level format from `next-design.md`: short advice,
  3-5 line explanation, optional `--execute` autorun mention.
- Tone: partner-orchestrator. No mentor-mode words ("просто", "легко",
  "не волнуйся", "обязательно сейчас", "это очевидно", "давайте быстренько").

## Acceptance criteria

- COLD-START runs first; greeting precedes any next-step recommendation.
- Recommendation cites a concrete command (`/book:plan-book`).
- Explanation references state in STATE.md or workflow.md (not hallucinated).
- No mentor-mode tokens appear in the answer.
- Answer is under 12 lines.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests integration of two procedures (COLD-START, ANSWER-NEXT-STEP) and the
mentor-mode constitutional rule. A common failure mode is to skip the greeting
and answer the user query directly.
