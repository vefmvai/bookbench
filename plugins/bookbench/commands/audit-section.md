---
description: Независимо проводит аудит готового раздела, не трогая edited.md. Запускает агентов book-editor и book-factchecker в audit-mode и сверяет раздел по чек-листам жанровой методологии, корпусу из 46 анти-ИИ-клише, пороговому значению pass-rate факт-чекинга, соответствию профилю голоса и связности с соседними разделами.
argument-hint: "<section-number>"
allowed-tools: [Task, Read, Write, Edit, Bash, Glob, AskUserQuestion]
---

# /bookbench:audit-section

<purpose>
Read-only-style audit of a single section. Output is `sections/<id>/audit-report.md`. Does not touch the section text.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже; полный контракт — `audit-design.md` этапа 07 -->

## Inputs

- `.book/sections/<id>/edited.md`.
- `.book/agent-guidelines/{editor,factchecker}/`.
- `.book/context/`, neighbouring `sections/<id-1|+1>/summary.md`.
- `${CLAUDE_PLUGIN_ROOT}/skills/anti-ai-cliche/SKILL.md`.

## Outputs

- `.book/sections/<id>/audit-report.md`.
- Pass/fail summary on stdout with quality-gate violations.

<execution>

This command is read-only with respect to section content. It calls `book-editor` in audit mode (skill `consistency-check` + `anti-cliche-check`) and writes only `audit-report.md`. PS-13-04 sibling: it never modifies `edited.md`.

### Step 1 — Validate argument

```bash
ARG="$ARGUMENTS"
[ -z "$ARG" ] && { echo "Usage: /bookbench:audit-section <section-number>"; exit 0; }
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
[ -z "$N" ] && { echo "Section number must be an integer ≥ 1."; exit 0; }
PADDED=$(printf '%03d' "$N")
CHDIR=".book/sections/section-${PADDED}"
```

### Step 2 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/. Run /bookbench:start."; exit 0; }
[ -d "$SECDIR" ] || { echo "Section folder $SECDIR does not exist."; exit 0; }
[ -s "$SECDIR/edited.md" ] || { echo "$SECDIR/edited.md is missing. Run /bookbench:write-section $N first."; exit 0; }
COMPLETED=$(awk '/^completed:/{print $2; exit}' "$SECDIR/section-state.yaml" || echo false)
[ "$COMPLETED" = "true" ] || {
  echo "Section $N is not marked completed (completed: $COMPLETED)."
  echo "Audit is intended for finished sections; run /bookbench:write-section $N to finalise it first."
  exit 0
}

# Capture sha256 of edited.md before audit (to verify audit is read-only)
SHA_BEFORE=$(shasum -a 256 "$SECDIR/edited.md" 2>/dev/null | awk '{print $1}')
```

### Step 3 — Compose `<files_to_read>` for editor in audit-mode

Per `context-control.md` § 2.4 + the audit-specific files. Bundle:

```
${SECDIR}/edited.md
${SECDIR}/spec.md
${SECDIR}/summary.md
${SECDIR}/factcheck.md
.book/context/voice-profile.md
.book/context/cross-references.md
.book/context/red-thread-keywords.md
.book/agent-guidelines/editor/README.md       (if exists)
.book/agent-guidelines/factchecker/README.md  (if exists)
${PREV_CHDIR}/summary.md                      (if exists)
${NEXT_CHDIR}/summary.md                      (if exists)
```

Total budget: 30–60 KB. Do NOT include any other section's draft/edited files.

### Step 4 — Call `book-editor` in audit-mode

`Task`:

- `subagent_type`: `book-editor`
- `description`: `Audit section ${N} (read-only)`
- `prompt`:

  ```
  You are book-editor in AUDIT-MODE (read-only) for /bookbench:audit-section ${N}.

  Active skills (apply both): consistency-check, anti-cliche-check.

  Required output: ${SECDIR}/audit-report.md

  Mandatory frontmatter:
    section_id, audit_type: full
    skill_used: [consistency-check, anti-cliche-check]
    created_by: book-editor
    created: <ISO 8601>
    issues_found: <int>
    severity_distribution: {high: <int>, medium: <int>, low: <int>}
    quality_gate_pass: true | false

  Body sections (in this order):
    ## Summary
    ## Issues by severity
       ### High (h-NN): <one-line title>
          - location: <line range>
          - excerpt: <≤ 2 lines>
          - rule violated: <pattern id or rule name>
          - fix suggestion: <one line>
       ### Medium (m-NN): ...
       ### Low (l-NN): ...
    ## Anti-AI-cliche scan (specific to anti-cliche-check skill)
    ## Voice and cohesion check (consistency-check)
    ## Quality gates
       - factcheck pass rate: <%>
       - anti_cliche_violations: <int>
       - voice deviations: <int>
       - cohesion_callbacks: <int>

  CRITICAL: do NOT modify ${SECDIR}/edited.md or any other section file.
  Write only audit-report.md.

  Use the writer's voice as-is — flag deviations in the report; do NOT rewrite text.
  ```

- `files_to_read`: list above.

### Step 5 — Verify outputs and read-only invariant

```bash
[ -s "$SECDIR/audit-report.md" ] || { echo "Editor did not produce audit-report.md"; exit 1; }
SHA_AFTER=$(shasum -a 256 "$SECDIR/edited.md" 2>/dev/null | awk '{print $1}')
[ "$SHA_BEFORE" = "$SHA_AFTER" ] || {
  echo "AUDIT VIOLATION: edited.md was modified during audit. Restoring from backup if available."
  # Stage 13 reports and warns; stage 14 implements automatic restore from .book/.backup/
  exit 1
}
PASS=$(awk '/^quality_gate_pass:/{print $2; exit}' "$SECDIR/audit-report.md" || echo unknown)
ISSUES=$(awk '/^issues_found:/{print $2; exit}' "$SECDIR/audit-report.md" || echo "?")
```

### Step 6 — Print pass/fail summary

```
Audit of section ${N}: ${PASS}
  Issues found: ${ISSUES}
  Report:       ${SECDIR}/audit-report.md
  edited.md unchanged: yes (sha256 matches before/after)

Recommended next:
  ${PASS == "false" ? "Inspect issues in audit-report.md, then optionally /bookbench:re-edit-section ${N} (stage 14)." : "/bookbench:plan-section $((N+1)) — start the next section."}
  /bookbench:status                 — see overall progress.
```

Note: `/bookbench:re-edit-section` is implemented in stage 14. At stage 13 the audit produces the report; the author can manually act on it. Mention that explicitly to set expectations.

### Step 7 — STATE update

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: audit-section ${N} ($PASS)/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/bookbench:audit-section %s` — issues=%s pass=%s\n' "$NOW" "$N" "$ISSUES" "$PASS" >> .book/STATE.md
```

### Constitutional rules for this command

- **MUST** never modify `edited.md`. The sha256 invariant is enforced after the Task.
- **MUST** require `completed: true` for the section (no audits of works-in-progress).
- **MUST** call `book-editor` with explicit skill list `[consistency-check, anti-cliche-check]`.
- **NEVER** call `book-writer`, `book-factchecker`, `book-marketer`, or any non-editor subagent.
- **NEVER** loop the audit (one pass per command invocation).

</execution>
