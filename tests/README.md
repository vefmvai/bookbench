# Tests — eval-driven development

This folder follows the eval-driven development pattern recommended by the Anthropic Skills best practices document. The structure:

```
tests/
├── agents/<role>/         — eval cases for each of the 9 subagent roles
├── skills/<skill>/        — eval cases for each of the 9 skills
└── workflows/             — end-to-end micro-cycle and import scenarios
```

## Minimum bar

- ≥3 eval cases per agent or skill (per Anthropic guidance).
- For `anti-ai-cliche`: 12 cases (one per pattern category from `anti-ai-cliche-module.md` § 8).
- Cases are run against Haiku, Sonnet and Opus model classes when applicable.

## Format

Each case is a markdown file:

```markdown
# Case <NN> — <name>

## Setup

(Inputs: file fixtures under `fixtures/`, parameter values, etc.)

## Execution

(Command to run, agent or skill to load.)

## Expected

(Outputs, assertions.)

## Notes

(Why this case matters; which decision or invariant it covers.)
```

## Stage 12 status

The skeletons are present (placeholder `.gitkeep` per folder). Full eval cases land in stage 14.

The 12 `anti-ai-cliche` test skeletons are already present in `skills/anti-ai-cliche/tests/`.

## audit-public-cleanliness

Pre-release gate (etap 17). Verifies that no personal data from the BookBench maintainer's own books has leaked into the public `bookbench/` repository.

**Usage:** `bash bookbench/tests/audit-public-cleanliness.sh`

**Optional flags:**

- `--quiet` — print only the final PASS/FAIL line (no details).
- `--list-markers` — print the loaded markers and exit (debug).
- `--target <path>` — scan a custom path instead of `bookbench/`.

**Marker source priority:**

1. `BOOKBENCH_AUDIT_MARKERS_FILE` env variable (if set).
2. `~/.bookbench/audit-private-markers.txt` (real audit; never committed).
3. `bookbench/tests/audit-public-cleanliness.example.txt` (fallback; with a warning, since example markers are intentionally generic).

**Exit codes:**

- `0` — PASS (no markers found).
- `1` — FAIL (≥1 marker found; list of `path:line:matched-text` printed).
- `2` — usage or configuration error (e.g. missing target path).

**Reference:** PS-08.1-05 (etap 08.1, `decisions-08.1.md`).
