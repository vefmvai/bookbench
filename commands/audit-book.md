---
description: Performs a final cross-chapter audit of the whole book — red-thread keyword presence, cohesion across chapters, glossary consistency, untouched imported fragments, and the full anti-AI-cliche corpus. Read-only with respect to chapter text. Produces context/audit-book-report.md without modifying any chapter.
argument-hint: "[--severity-threshold low|medium|high]"
allowed-tools: [Task, Read, Write, Glob, Grep, Bash, AskUserQuestion]
---

# /book:audit-book

<purpose>
Whole-book quality gate before `/book:ship`. Read-only with respect to chapter text; only writes the report and proposes follow-up commands. Cross-chapter checks complement per-chapter audits — e.g. red-thread keywords have to appear in 3+ chapters, glossary terms must agree across chapters.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже; полный контракт — `audit-design.md` этапа 07 -->

## Inputs

- All `.book/chapters/*/edited.md` (read-only).
- `.book/context/red-thread-keywords.md`, `glossary.md`, `cross-references.md`.
- `.book/INGEST-DECISIONS.md` (if exists) — for «untouched imports» check.
- `${CLAUDE_PLUGIN_ROOT}/skills/anti-ai-cliche/`.

## Outputs

- `.book/context/audit-book-report.md` (write).
- Suggestion list on stdout: which chapters need `/book:re-edit-chapter`.

<execution>

Read-only command (with respect to chapter text). Eight-step pattern with one Task delegation to `book-editor` in audit mode.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory."; exit 0; }
[ -d .book/chapters ] || { echo "No chapters directory."; exit 0; }

# Count finalised chapters (those with edited.md)
N_CHAPTERS=$(find .book/chapters -maxdepth 2 -name 'edited.md' -type f | wc -l | tr -d ' ')
if [ "$N_CHAPTERS" -lt 2 ]; then
  echo "Warning: only $N_CHAPTERS chapters have edited.md — book audit makes more sense at 3+ chapters."
  echo "Continue anyway? Use AskUserQuestion."
fi

SEVERITY="medium"
for arg in $ARGUMENTS; do
  case "$arg" in
    --severity-threshold=*)  SEVERITY="${arg#--severity-threshold=}" ;;
  esac
done
```

### Step 2 — Confirmation gate

Present an `AskUserQuestion`:

- Title: «Run book-wide audit?»
- Body:
  - `Chapters with edited.md: <N_CHAPTERS>`
  - `Severity threshold: <SEVERITY>`
  - `Output: .book/context/audit-book-report.md (overwrites existing if any)`
  - Note: «Read-only with respect to chapter text. Takes ~3-8 minutes.»
- Options:
  - `Run audit` — proceed.
  - `Cancel` — exit.

### Step 3 — Pre-compute red-thread coverage

```bash
# Read keyword list
KEYWORDS=$(awk '/^- /{print substr($0, 3)}' .book/context/red-thread-keywords.md 2>/dev/null)

# Per keyword: count chapters that mention it
echo "Red-thread coverage:" > /tmp/audit-rtk.txt
for kw in $KEYWORDS; do
  chapters_with=$(grep -lE "$kw" .book/chapters/*/edited.md 2>/dev/null | wc -l | tr -d ' ')
  printf '  %-30s — present in %s chapters\n' "$kw" "$chapters_with" >> /tmp/audit-rtk.txt
done
```

### Step 4 — Pre-compute glossary cross-chapter consistency

For each glossary term, find how it is described in each chapter; flag inconsistencies.

```bash
# Best-effort: extract glossary terms
GLOSSARY_TERMS=$(awk '/^### /{sub(/^### /, ""); print}' .book/context/glossary.md 2>/dev/null)
echo "Glossary cross-chapter check:" > /tmp/audit-glossary.txt
for term in $GLOSSARY_TERMS; do
  occurrences=$(grep -cE "$term" .book/chapters/*/edited.md 2>/dev/null | awk -F: '{s+=$2} END{print s}')
  printf '  %-40s — %s occurrences across all chapters\n' "$term" "$occurrences" >> /tmp/audit-glossary.txt
done
```

### Step 5 — Delegate to book-editor in audit-book mode

```
Task(
  subagent_type: book-editor,
  description: "Whole-book audit — cross-chapter consistency",
  prompt: """
    You are book-editor in AUDIT-BOOK mode (skills: consistency-check,
    anti-cliche-check, philosophical-review, sensitivity-review).

    Severity threshold: <SEVERITY> (low / medium / high)

    Required steps:
      1. Read all chapter edited.md files in ROADMAP order.
      2. Verify red-thread keywords appear in >= 3 chapters each (use the
         pre-computed table at /tmp/audit-rtk.txt as a starting point).
      3. Check glossary term usage is consistent across chapters
         (no contradictory definitions, no orphan terms).
      4. Verify every chapter ends in a way that prepares the next chapter
         (cohesion / pacing).
      5. Run anti-cliche-check across all chapters and aggregate counts.
      6. For each issue found, mark severity (low / medium / high / critical)
         and list which chapters need attention.
      7. Output: .book/context/audit-book-report.md with sections:
         • Executive summary (4-6 lines).
         • Red-thread coverage (per keyword, per chapter).
         • Glossary consistency.
         • Cross-chapter cohesion.
         • Anti-cliche aggregate.
         • Per-chapter issue counts (severity-filtered).
         • Recommended next actions (which chapters need /book:re-edit-chapter).

    Constraint — READ-ONLY:
      You may NOT modify any chapter file. You may only WRITE the audit report.
      Use captured sha256 of each edited.md before and after to verify.
  """,
  files_to_read: [
    .book/ROADMAP.md,
    .book/context/red-thread-keywords.md,
    .book/context/glossary.md,
    .book/context/cross-references.md (if exists),
    .book/INGEST-DECISIONS.md (if exists),
    /tmp/audit-rtk.txt,
    /tmp/audit-glossary.txt,
    .book/chapters/*/edited.md (all of them),
    ${CLAUDE_PLUGIN_ROOT}/skills/anti-ai-cliche/SKILL.md,
    ${CLAUDE_PLUGIN_ROOT}/skills/anti-ai-cliche/references/patterns.tsv
  ]
)
```

### Step 6 — Verify invariant: chapter texts unchanged

```bash
# Capture sha256 of every edited.md before and after the Task
# (Done conceptually; before-Task hashes were stored at Step 1.)
for f in .book/chapters/*/edited.md; do
  CURRENT_SHA=$(shasum -a 256 "$f" | awk '{print $1}')
  STORED_SHA=$(grep "$f" /tmp/audit-book-pre-sha.txt 2>/dev/null | awk '{print $1}')
  if [ -n "$STORED_SHA" ] && [ "$CURRENT_SHA" != "$STORED_SHA" ]; then
    echo "INVARIANT VIOLATION: $f was modified during audit. Inspect immediately."
  fi
done
```

### Step 7 — Verify report exists

```bash
[ -s .book/context/audit-book-report.md ] || {
  echo "Editor did not write audit-book-report.md."
  exit 1
}
```

Extract the recommendation list:

```bash
RECOMMENDATIONS=$(awk '/^## Recommended next actions/,/^## /{print}' .book/context/audit-book-report.md | head -20)
echo ""
echo "$RECOMMENDATIONS"
```

### Step 8 — Atomic state mutation + next-step

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ISSUE_COUNT=$(awk '/^- \[/{count++} END {print count+0}' .book/context/audit-book-report.md)
printf '\n%s — `/book:audit-book` — wrote audit-book-report.md (%d issues)\n' \
  "$NOW" "$ISSUE_COUNT" >> .book/STATE.md

echo ""
echo "Audit complete. Report: .book/context/audit-book-report.md"
echo "Total issues: $ISSUE_COUNT (severity threshold: $SEVERITY)"
echo ""
echo "Recommended next:"
echo "  /book:re-edit-chapter <N> --from-audit   — fix flagged chapters."
echo "  /book:audit-chapter <N>                  — drill into a single chapter."
echo "  /book:ship                                — finalise (only after issues resolved)."
```

### Constitutional rules

- **MUST** be read-only with respect to chapter text — verified via sha256 invariant.
- **MUST** confirm with the author before running (this is a heavy operation).
- **MUST** produce a recommendation list (not just findings) — actionable output.
- **MUST** delegate the analysis to `book-editor` via `Task`.
- **NEVER** modify any chapter's `edited.md`, `draft.md`, or `factcheck.md`.
- **NEVER** invoke writer / factchecker / marketer — pure editor in audit mode.

</execution>
