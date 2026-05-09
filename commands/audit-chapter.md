---
description: Независимо проводит аудит готовой главы, не трогая edited.md. Запускает агентов book-editor и book-factchecker в audit-mode и сверяет главу по чек-листам жанровой методологии, корпусу из 46 анти-ИИ-клише, пороговому значению pass-rate факт-чекинга, соответствию профилю голоса и связности с соседними главами.
argument-hint: "<chapter-number>"
allowed-tools: [Task, Read, Write, Edit, Bash, Glob, AskUserQuestion]
---

# /book:audit-chapter

<purpose>
Read-only-style audit of a single chapter. Output is `chapters/<id>/audit-report.md`. Does not touch the chapter text.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже; полный контракт — `audit-design.md` этапа 07 -->

## Inputs

- `.book/chapters/<id>/edited.md`.
- `.book/agent-guidelines/{editor,factchecker}/`.
- `.book/context/`, neighbouring `chapters/<id-1|+1>/summary.md`.
- `${CLAUDE_PLUGIN_ROOT}/skills/anti-ai-cliche/SKILL.md`.

## Outputs

- `.book/chapters/<id>/audit-report.md`.
- Pass/fail summary on stdout with quality-gate violations.

<execution>

This command is read-only with respect to chapter content. It calls `book-editor` in audit mode (skill `consistency-check` + `anti-cliche-check`) and writes only `audit-report.md`. PS-13-04 sibling: it never modifies `edited.md`.

### Step 1 — Validate argument

```bash
ARG="$ARGUMENTS"
[ -z "$ARG" ] && { echo "Usage: /book:audit-chapter <chapter-number>"; exit 0; }
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
[ -z "$N" ] && { echo "Chapter number must be an integer ≥ 1."; exit 0; }
PADDED=$(printf '%03d' "$N")
CHDIR=".book/chapters/chapter-${PADDED}"
```

### Step 2 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/. Run /book:start."; exit 0; }
[ -d "$CHDIR" ] || { echo "Chapter folder $CHDIR does not exist."; exit 0; }
[ -s "$CHDIR/edited.md" ] || { echo "$CHDIR/edited.md is missing. Run /book:write-chapter $N first."; exit 0; }
COMPLETED=$(awk '/^completed:/{print $2; exit}' "$CHDIR/chapter-state.yaml" || echo false)
[ "$COMPLETED" = "true" ] || {
  echo "Chapter $N is not marked completed (completed: $COMPLETED)."
  echo "Audit is intended for finished chapters; run /book:write-chapter $N to finalise it first."
  exit 0
}

# Capture sha256 of edited.md before audit (to verify audit is read-only)
SHA_BEFORE=$(shasum -a 256 "$CHDIR/edited.md" 2>/dev/null | awk '{print $1}')
```

### Step 3 — Compose `<files_to_read>` for editor in audit-mode

Per `context-control.md` § 2.4 + the audit-specific files. Bundle:

```
${CHDIR}/edited.md
${CHDIR}/spec.md
${CHDIR}/summary.md
${CHDIR}/factcheck.md
.book/context/voice-profile.md
.book/context/cross-references.md
.book/context/red-thread-keywords.md
.book/agent-guidelines/editor/README.md       (if exists)
.book/agent-guidelines/factchecker/README.md  (if exists)
${PREV_CHDIR}/summary.md                      (if exists)
${NEXT_CHDIR}/summary.md                      (if exists)
```

Total budget: 30–60 KB. Do NOT include any other chapter's draft/edited files.

### Step 4 — Call `book-editor` in audit-mode

`Task`:

- `subagent_type`: `book-editor`
- `description`: `Audit chapter ${N} (read-only)`
- `prompt`:

  ```
  You are book-editor in AUDIT-MODE (read-only) for /book:audit-chapter ${N}.

  Active skills (apply both): consistency-check, anti-cliche-check.

  Required output: ${CHDIR}/audit-report.md

  Mandatory frontmatter:
    chapter_id, audit_type: full
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

  CRITICAL: do NOT modify ${CHDIR}/edited.md or any other chapter file.
  Write only audit-report.md.

  Use the writer's voice as-is — flag deviations in the report; do NOT rewrite text.
  ```

- `files_to_read`: list above.

### Step 5 — Verify outputs and read-only invariant

```bash
[ -s "$CHDIR/audit-report.md" ] || { echo "Editor did not produce audit-report.md"; exit 1; }
SHA_AFTER=$(shasum -a 256 "$CHDIR/edited.md" 2>/dev/null | awk '{print $1}')
[ "$SHA_BEFORE" = "$SHA_AFTER" ] || {
  echo "AUDIT VIOLATION: edited.md was modified during audit. Restoring from backup if available."
  # Stage 13 reports and warns; stage 14 implements automatic restore from .book/.backup/
  exit 1
}
PASS=$(awk '/^quality_gate_pass:/{print $2; exit}' "$CHDIR/audit-report.md" || echo unknown)
ISSUES=$(awk '/^issues_found:/{print $2; exit}' "$CHDIR/audit-report.md" || echo "?")
```

### Step 6 — Print pass/fail summary

```
Audit of chapter ${N}: ${PASS}
  Issues found: ${ISSUES}
  Report:       ${CHDIR}/audit-report.md
  edited.md unchanged: yes (sha256 matches before/after)

Recommended next:
  ${PASS == "false" ? "Inspect issues in audit-report.md, then optionally /book:re-edit-chapter ${N} (stage 14)." : "/book:plan-chapter $((N+1)) — start the next chapter."}
  /book:status                 — see overall progress.
```

Note: `/book:re-edit-chapter` is implemented in stage 14. At stage 13 the audit produces the report; the author can manually act on it. Mention that explicitly to set expectations.

### Step 7 — STATE update

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: audit-chapter ${N} ($PASS)/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/book:audit-chapter %s` — issues=%s pass=%s\n' "$NOW" "$N" "$ISSUES" "$PASS" >> .book/STATE.md
```

### Constitutional rules for this command

- **MUST** never modify `edited.md`. The sha256 invariant is enforced after the Task.
- **MUST** require `completed: true` for the chapter (no audits of works-in-progress).
- **MUST** call `book-editor` with explicit skill list `[consistency-check, anti-cliche-check]`.
- **NEVER** call `book-writer`, `book-factchecker`, `book-marketer`, or any non-editor subagent.
- **NEVER** loop the audit (one pass per command invocation).

</execution>
