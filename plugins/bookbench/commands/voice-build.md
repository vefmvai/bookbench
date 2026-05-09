---
description: Собирает профиль голоса (voice profile) для текущей книги через активацию скилла voice-builder в выделенной сессии. Поддерживает --mode=quick|serious (по умолчанию serious) и --rebuild для перезаписи уже существующего профиля. Пишет только внутрь .book/. По успеху сбрасывает флаг voice_pending в .book/STATE.md.
argument-hint: "[--mode=quick|serious] [--rebuild]"
allowed-tools: [Task, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
---

# /book:voice build

<purpose>
Run the voice-builder skill in a dedicated session, fill .book/context/voice-profile.md with reasoning, optionally fill .book/agent-guidelines/writer/voice-samples.md, and clear the voice_pending flag in .book/STATE.md.
</purpose>

<!-- Stage 08.1, Wave B, T4: full implementation. PS-08.1-04 voice_pending behaviour. PS-08.1-06 rebuild as a flag. PS-08.1-07 privacy enforcement. -->

<execution>

This command is a markdown prompt executed by Claude Code. It follows the eight-step orchestrator pattern from etap 13: validate → resolve plugin paths → resolve voices library path (via voices-helpers H1, optional here) → action (Task call to voice-builder) → verify outputs → next-step message. Privacy guards from voices-helpers H4 are applied to every write site.

### Step 1 — Parse arguments

```bash
RAW="${ARGUMENTS:-}"
MODE="serious"
REBUILD=0

set -- $RAW
while [ $# -gt 0 ]; do
  case "$1" in
    --mode=quick)    MODE="quick" ;;
    --mode=serious)  MODE="serious" ;;
    --mode)          shift; MODE="${1:-serious}" ;;
    --rebuild)       REBUILD=1 ;;
    *)               echo "voice build: unknown flag '$1'" 1>&2 ;;
  esac
  shift 2>/dev/null || true
done

case "$MODE" in
  quick|serious) : ;;
  *) echo "voice build: invalid --mode='$MODE' (allowed: quick, serious)" 1>&2; exit 1 ;;
esac

echo "voice build: mode=$MODE rebuild=$REBUILD"
```

### Step 2 — Resolve plugin paths and book root

Read `${CLAUDE_PLUGIN_ROOT}/lib/plugin-data-helpers.md` H2 once. Then via the Bash tool resolve `PLUGIN_ROOT`. Locate the book root.

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && {
  for c in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    [ -f "$c/manifest.json" ] && PLUGIN_ROOT="$c" && break
  done
}

BOOK_ROOT=""
if [ -d ".book" ]; then
  BOOK_ROOT="$PWD/.book"
elif [ -d "$PWD/agent-memory" ] && [ -f "$PWD/STATE.md" ]; then
  BOOK_ROOT="$PWD"
else
  echo "voice build: cannot locate .book/ — run from inside a book directory."
  exit 1
fi

echo "PLUGIN_ROOT=$PLUGIN_ROOT BOOK_ROOT=$BOOK_ROOT"
```

### Step 3 — Resolve voices library path (informational only)

Voice build does not write to the library. The path is resolved here only for the next-step message — to remind the author about `/book:voice save-as` after a successful build.

Read `${CLAUDE_PLUGIN_ROOT}/lib/voices-helpers.md` H1 once and apply the recipe to compute `VOICES_DIR`.

### Step 4 — Pre-flight: existing voice-profile + rebuild gate

```bash
PROFILE_PATH="$BOOK_ROOT/context/voice-profile.md"
SAMPLES_PATH="$BOOK_ROOT/agent-guidelines/writer/voice-samples.md"

PROFILE_FILLED=0
if [ -f "$PROFILE_PATH" ]; then
  MEANINGFUL_LINES=$(grep -vE '^\s*$|^\s*#|^>|TBD|\(Add entries here\.\)|<!-- ' "$PROFILE_PATH" | wc -l | tr -d ' ')
  if [ "${MEANINGFUL_LINES:-0}" -gt 3 ]; then
    PROFILE_FILLED=1
  fi
fi

if [ "$PROFILE_FILLED" = "1" ] && [ "$REBUILD" = "0" ]; then
  echo "voice build: voice-profile.md is already filled."
  echo "  Use --rebuild to overwrite, or run /book:tune to refine the existing profile."
  exit 0
fi

if [ "$PROFILE_FILLED" = "1" ] && [ "$REBUILD" = "1" ]; then
  TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
  BACKUP_DIR="$BOOK_ROOT/.backup/voice-profile"
  mkdir -p "$BACKUP_DIR"
  cp "$PROFILE_PATH" "$BACKUP_DIR/voice-profile.${TIMESTAMP}.md"
  if [ -f "$SAMPLES_PATH" ]; then
    cp "$SAMPLES_PATH" "$BACKUP_DIR/voice-samples.${TIMESTAMP}.md"
  fi
  echo "voice build: backed up existing profile to $BACKUP_DIR/voice-profile.${TIMESTAMP}.md"
fi
```

If `REBUILD=1` and a profile is filled — present an `AskUserQuestion`:

- Title: «Rebuild voice profile»
- Question: «An existing voice profile is filled. A backup has been saved to `.book/.backup/voice-profile/voice-profile.<timestamp>.md`. Continue with the rebuild?»
- Options: `Yes, rebuild` / `No, abort` / `Show current profile`.
- On `No, abort` — exit. On `Show current profile` — Read `$PROFILE_PATH`, then re-ask.

### Step 5 — Privacy guard before Task call

```bash
# voices-helpers H4: refuse to write inside plugin tree.
case "$PROFILE_PATH" in
  "$PLUGIN_ROOT"*)
    echo "voice build: refusing to write inside plugin tree: $PROFILE_PATH" 1>&2
    exit 1
    ;;
esac
case "$SAMPLES_PATH" in
  "$PLUGIN_ROOT"*)
    echo "voice build: refusing to write inside plugin tree: $SAMPLES_PATH" 1>&2
    exit 1
    ;;
esac
```

### Step 6 — Activate the voice-builder skill via Task

```text
Task(
  subagent_type="general-purpose",
  prompt="""
  Activate the voice-builder skill (see ${CLAUDE_PLUGIN_ROOT}/skills/voice-builder/SKILL.md).

  Inputs:
    book_root:    ${BOOK_ROOT}
    mode:         ${MODE}        # quick = path B1 only; serious = path B2 with iteration
    rebuild:      ${REBUILD}     # 1 = author has chosen to overwrite an existing profile

  Behaviour by mode:
    - quick   = run path B1 (5-min interview) only.
    - serious = run path B2 (15-20 min dedicated session, sample paragraph, cap=2 iterations).
    The third path B3 is reserved for the in-writer fallback; this command does not invoke B3 directly.

  Files you may Read (whitelist):
    - ${BOOK_ROOT}/PROJECT.md
    - ${BOOK_ROOT}/ROADMAP.md
    - ${BOOK_ROOT}/context/target-audience.md
    - ${BOOK_ROOT}/sections/*/spec.md (if any)
    - ${CLAUDE_PLUGIN_ROOT}/skills/voice-profile/SKILL.md (the 6-parameter contract)

  Files you may Write (whitelist):
    - ${BOOK_ROOT}/context/voice-profile.md
    - ${BOOK_ROOT}/voice-profile.yaml
    - ${BOOK_ROOT}/agent-guidelines/writer/voice-samples.md (only if the author provided samples)

  NEVER write inside ${CLAUDE_PLUGIN_ROOT}.
  NEVER write inside ${BOOK_ROOT}/sections/, ${BOOK_ROOT}/agent-memory/, or ${BOOK_ROOT}/inputs/.

  Apply the algorithm in § Algorithm of SKILL.md (5 steps). The voice-profile.md
  output MUST contain a `## Reasoning` section (TOV-12 transparency).

  Return a one-paragraph summary: which mode ran, which six-parameter values were
  chosen, and whether voice-samples.md was populated.
  """,
  description="Build voice profile via the voice-builder skill."
)
```

### Step 7 — Verify outputs and clear voice_pending flag

```bash
if [ ! -f "$PROFILE_PATH" ]; then
  echo "voice build: voice-profile.md was not created — voice-builder skill failed." 1>&2
  exit 1
fi

if ! grep -q '^## Reasoning' "$PROFILE_PATH"; then
  echo "voice build: voice-profile.md is missing the mandatory ## Reasoning section." 1>&2
  echo "  This violates the voice-builder output contract (TOV-12)." 1>&2
  exit 1
fi

# PS-08.1-04: clear voice_pending flag from STATE.md if present.
STATE_FILE="$BOOK_ROOT/STATE.md"
if [ -f "$STATE_FILE" ] && grep -q '^## voice_pending' "$STATE_FILE"; then
  # Remove the section starting at "## voice_pending" up to the next "## " heading or EOF.
  awk '
    /^## voice_pending/ { skip=1; next }
    skip && /^## /      { skip=0 }
    !skip
  ' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  echo "voice build: cleared voice_pending flag from STATE.md"
fi

# Append a History line to STATE.md.
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  echo ""
  echo "- ${NOW} — /book:voice build (mode=${MODE}, rebuild=${REBUILD}) — voice-profile.md filled."
} >> "$STATE_FILE"

echo "voice build: verify ok"
```

### Step 8 — Next-step message

```text
voice build: done.

Files written:
  - .book/context/voice-profile.md  (filled, with ## Reasoning section)
  - .book/voice-profile.yaml         (six values for the anti-cliche module)
  - .book/agent-guidelines/writer/voice-samples.md  (only if you provided samples)

Голос настроен. Возвращайтесь в исходную сессию и продолжите `/book:write-section <N>`
— writer-gate (TOV-08) больше не сработает, voice-pending flag снят.

Optional next steps:
  /book:voice save-as <name>   — save this profile to your personal library at
                                 ~/.bookbench/voices/<name>.md for reuse in future books.
  /book:tune                   — refine the profile after writing 1-2 sections
                                 if voice-drift signals appear in REJECTIONS.
```

### Constitutional rules for this command

- **MUST** never write inside the plugin code tree (`${CLAUDE_PLUGIN_ROOT}`). Privacy guard from voices-helpers H4 is applied before every Write site.
- **MUST** verify the output `voice-profile.md` contains a `## Reasoning` section before clearing voice_pending (TOV-12).
- **MUST** clear `## voice_pending` section from `.book/STATE.md` only after successful verification.
- **NEVER** overwrite an existing voice-profile.md without `--rebuild` — exit cleanly with a hint to use the flag or `/book:tune`.
- **NEVER** write to the personal voices library `~/.bookbench/voices/` — that is the job of `/book:voice save-as`.

</execution>
