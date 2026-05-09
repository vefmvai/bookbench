---
name: workflow:check
description: Static validator for .book/workflow.md. Parses the YAML inside, verifies block names against bookbench/blocks-catalog.md, checks gate references, validates cross-section dependencies, and reports problems with severity tags. Read-only. Run automatically by /book:workflow:edit after every edit.
argument-hint: ""
allowed-tools: [Read, Write, Bash, Glob]
---

# /book:workflow:check

<purpose>
Static validation of the workflow file. Catches typos, missing blocks, unresolved references, broken gates before they break runtime navigation. Run after every author edit; safe to run any time.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный дизайн — `workflow-management-design.md` § 6 этапа 7.2 -->

## Inputs

- `.book/workflow.md` — the file to validate.
- `${CLAUDE_PLUGIN_ROOT}/blocks-catalog.md` — block registry (source of truth for valid block names).

## Outputs

- A structured report on stdout with severity tags.
- `.book/.workflow-check-report.md` — only if there are issues; cleared on success.
- Exit non-zero if there are CRITICAL issues; exit zero on warnings.

<execution>

Read-only validator. Five-step pattern: pre-flight → parse workflow → cross-reference catalog → render report → next-step.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory."; exit 0; }
[ -f .book/workflow.md ] || {
  echo "No .book/workflow.md."
  echo "Either run /book:start to create one or /book:research-genre to generate."
  exit 0
}
```

### Step 2 — Parse workflow.md

Extract the YAML block between the markers `<!-- workflow:start -->` and `<!-- workflow:end -->` (per WF-01). If markers are missing — assume the entire file is YAML. Tolerate both forms.

Required top-level keys:

- `bookbench_version` (string)
- `genre` (string)
- `book_level` (list)
- `section_loop` (list)
- `cross_cutting` (list, may be empty)
- `post_book` (list)

Optional:

- `inherits_skill` (string)
- `section_overrides` (map)
- `section_loop_skip_sections` (list of ints)
- `section_loop_resume_at` (int)

```bash
# Best-effort YAML key extraction
HAS_BOOK_LEVEL=$(awk '/^book_level:/ {print 1; exit}' .book/workflow.md || echo 0)
HAS_SECTION_LOOP=$(awk '/^section_loop:/ {print 1; exit}' .book/workflow.md || echo 0)
HAS_POST_BOOK=$(awk '/^post_book:/ {print 1; exit}' .book/workflow.md || echo 0)
```

### Step 3 — Cross-reference against catalog

Read `${CLAUDE_PLUGIN_ROOT}/blocks-catalog.md` and build a list of valid block names. Walk every `- block: <name>` line in workflow.md and confirm the name is registered.

For each unknown block, emit:

```
[CRITICAL] line <L>: block '<name>' not in catalog.
           Did you mean: <suggestion-1>, <suggestion-2>?
```

Walk every `- gate: <name>` line. Confirm `on_approve` and `on_revise` keys are present (per WF-01). For each missing branch:

```
[HIGH] line <L>: gate '<name>' has no on_revise; this means revise will halt the workflow.
```

### Step 4 — Validate dependencies

For each `requires:` field, confirm referenced blocks exist either above in the same section or are global. For each broken reference:

```
[HIGH] line <L>: block '<X>' requires '<Y>' but '<Y>' is not defined in the workflow.
```

For `section_overrides` keys, confirm they are valid section numbers (positive integers, ≤ ROADMAP section count).

### Step 5 — Render report

```
== /book:workflow:check ==
File:    .book/workflow.md
Catalog: ${CLAUDE_PLUGIN_ROOT}/blocks-catalog.md

Blocks referenced: N
  • valid:   M
  • unknown: K
Gates:     P
Sections:  ☑️ book_level  ☑️ section_loop  ☑️ post_book  ☑️ cross_cutting

Issues:
  [CRITICAL] ...
  [HIGH]     ...
  [MEDIUM]   ...
```

If issues exist — write the same content to `.book/.workflow-check-report.md`. If clean — remove the report file (if it exists) and print:

```
== /book:workflow:check ==
✓ workflow.md is valid. No issues.
```

### Step 6 — Next-step message

If clean:

```
Recommended next:
  /book:next                 — use the workflow now.
  /book:workflow:edit        — make further changes.
```

If issues:

```
Recommended next:
  /book:workflow:edit        — fix the issues above.
  See .book/.workflow-check-report.md for the full report.
```

### Constitutional rules

- **MUST** be read-only — never edit `workflow.md`.
- **MUST** be deterministic — same input gives same output.
- **MUST** exit non-zero only on CRITICAL issues; warnings exit zero.
- **NEVER** invoke any subagent.
- **NEVER** require network access.

</execution>
