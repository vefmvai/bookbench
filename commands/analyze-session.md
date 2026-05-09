---
description: Activates the book-observer agent to analyse the latest Claude Code session. Reads .book/ops-observations/rawlog.jsonl plus the matching session transcript, classifies author replies as content vs process, writes abstracted notes to chapter-N-process-notes.md and chapter-N-content-notes.md, and promotes recurring patterns to upgrade-candidates.md. Optional --chapter N restricts the scope; otherwise the whole session is processed.
argument-hint: "[--chapter N]"
allowed-tools: [Read, Write, Glob, Bash, Task]
---

# /book:analyze-session

<purpose>
Run the book-observer agent over the latest session's rawlog and
transcript. Produces digested notes that feed back into the next
chapter's writing AND seed BookBench 0.2+ upgrade candidates.
</purpose>

<!-- Stage 14.1, Wave B, T8: full implementation. -->

## Step 1 — Parse arguments

```bash
RAW="${ARGUMENTS:-}"
CHAPTER_FILTER=""

set -- $RAW
while [ $# -gt 0 ]; do
  case "$1" in
    --chapter)
      shift
      CHAPTER_FILTER="${1:-}"
      ;;
    *)
      echo "analyze-session: unknown flag '$1'" 1>&2
      ;;
  esac
  shift 2>/dev/null || true
done

if [ -n "$CHAPTER_FILTER" ]; then
  echo "analyze-session: scope limited to chapter $CHAPTER_FILTER"
else
  echo "analyze-session: scope = whole session (no --chapter filter)"
fi
```

## Step 2 — Resolve book root and rawlog path

```bash
BOOK_ROOT=""
if [ -d ".book" ]; then
  BOOK_ROOT="$PWD/.book"
elif [ -d "$PWD/agent-memory" ] && [ -f "$PWD/STATE.md" ]; then
  BOOK_ROOT="$PWD"
else
  echo "analyze-session: cannot locate .book/ — run from inside a book directory."
  exit 0
fi

RAWLOG="$BOOK_ROOT/ops-observations/rawlog.jsonl"
CANDIDATES="$BOOK_ROOT/ops-observations/upgrade-candidates.md"

if [ ! -f "$RAWLOG" ]; then
  echo "analyze-session: $RAWLOG does not exist yet."
  echo "  No telemetry has been recorded. Run at least one /book:write-chapter first."
  exit 0
fi

LINES=$(wc -l < "$RAWLOG" | tr -d ' ')
if [ "$LINES" -lt 3 ]; then
  echo "analyze-session: rawlog has only $LINES line(s) — too thin for analysis."
  echo "  Continue working on a chapter; the observer needs more data."
  exit 0
fi

echo "analyze-session: rawlog has $LINES events"
```

## Step 3 — Resolve Claude Code session transcript path

The transcript is stored by Claude Code itself in
`~/.claude/projects/<project-hash>/<session-id>.jsonl`. The session id
is the most recent record in `rawlog.jsonl`.

```bash
LATEST_SESSION=$(grep -oE '"session_id":"[^"]+"' "$RAWLOG" | tail -1 | sed 's/"session_id":"//; s/"$//')

if [ -z "$LATEST_SESSION" ] || [ "$LATEST_SESSION" = "unknown" ]; then
  echo "analyze-session: cannot determine session_id from rawlog — proceeding without transcript"
  TRANSCRIPT_PATH=""
else
  # Best-effort lookup; the project hash is opaque, so we glob.
  TRANSCRIPT_PATH=$(find "$HOME/.claude/projects" -type f -name "${LATEST_SESSION}.jsonl" 2>/dev/null | head -1)
  if [ -z "$TRANSCRIPT_PATH" ]; then
    echo "analyze-session: transcript for session $LATEST_SESSION not found in ~/.claude/projects/"
    echo "  Observer will analyse rawlog only (without verbatim author replies)."
  else
    echo "analyze-session: transcript located at $TRANSCRIPT_PATH"
  fi
fi
```

## Step 4 — Pre-flight existing notes

```bash
EXISTING_NOTES=$(find "$BOOK_ROOT/ops-observations" -name "chapter-*-process-notes.md" -o -name "chapter-*-content-notes.md" 2>/dev/null | wc -l | tr -d ' ')
echo "analyze-session: existing chapter notes = $EXISTING_NOTES file(s)"
```

## Step 5 — Compose Task input for book-observer

The observer needs the rawlog path, the (optional) transcript path,
the existing candidates file, and the chapter filter.

The Task call below is the explicit invocation form. The observer
reads only the files declared in `files_to_read`; its `tools` set
forbids reading anything else outside `.book/ops-observations/` plus
the transcript path that the caller hands it.

## Step 6 — Activate the observer

```text
Task(
  subagent_type="book-observer",
  prompt="""
  Activate Procedure ANALYZE per your Constitution.

  Inputs:
    rawlog_path:           ${RAWLOG}
    transcript_path:       ${TRANSCRIPT_PATH:-<none — analyse rawlog metadata only>}
    existing_candidates:   ${CANDIDATES}
    chapter_filter:        ${CHAPTER_FILTER:-<all>}
    book_root:             ${BOOK_ROOT}

  Files you may Read (whitelist):
    - ${RAWLOG}
    - ${CANDIDATES}
    - ${BOOK_ROOT}/ops-observations/chapter-*-process-notes.md
    - ${BOOK_ROOT}/ops-observations/chapter-*-content-notes.md
    - ${TRANSCRIPT_PATH}      # only if non-empty

  Files you may Write (whitelist):
    - ${BOOK_ROOT}/ops-observations/chapter-${CHAPTER_FILTER:-N}-process-notes.md
    - ${BOOK_ROOT}/ops-observations/chapter-${CHAPTER_FILTER:-N}-content-notes.md
    - ${CANDIDATES}

  Apply your privacy Constitution literally:
    - NEVER read ${BOOK_ROOT}/chapters/, ${BOOK_ROOT}/inputs/, or ${BOOK_ROOT}/agent-memory/.
    - NEVER quote author replies verbatim; abstract every reply.
    - NEVER record proper nouns from the book.

  Return the four-block summary defined in Procedure ANALYZE Phase 4
  Step 12.
  """,
  description="Analyse session telemetry and produce abstracted notes."
)
```

## Step 7 — Verify outputs

After the Task call returns, the model should:

1. Confirm `chapter-<N>-process-notes.md` and `chapter-<N>-content-notes.md`
   exist (or `session-<session_id>-*` if no chapter filter).
2. Confirm `upgrade-candidates.md` was modified (compare mtime to start time).
3. If the observer returned `Privacy self-check: clean` — proceed to Step 8.
   If the observer returned any `dirty` flag — surface it loudly to the
   author (this should never happen given the Constitution; if it does,
   it's a bug to file).

## Step 8 — Atomic state mutation

Append a one-line entry to `.book/STATE.md` History section:

```text
- <ISO timestamp> | /book:analyze-session ${CHAPTER_FILTER:+--chapter $CHAPTER_FILTER}
  events_analysed=$LINES
  notes_written=2
  candidates_added=<N>
  status=ok
```

## Step 9 — Next-step message

```text
analyze-session: done.

Files updated:
  - .book/ops-observations/chapter-${CHAPTER_FILTER:-N}-process-notes.md
  - .book/ops-observations/chapter-${CHAPTER_FILTER:-N}-content-notes.md
  - .book/ops-observations/upgrade-candidates.md (if any new candidates promoted)

Suggested next steps:
  - Read the chapter notes to confirm the observer caught the right signals.
  - Inspect upgrade-candidates.md for new high-severity entries.
  - Continue writing the next chapter; telemetry recording is automatic.
```

## Notes

- This command is **the only** trigger for the observer in 0.1
  (PS-14.1-08). Auto-trigger on every `Stop` hook is deferred to 0.2+
  once we have data on false-positive rates.
- The observer never modifies anything outside `.book/ops-observations/`.
  Even if you ran this command from the wrong directory, it cannot
  damage existing chapters.
- Privacy is enforced by the observer's Constitution (its `tools` set
  excludes `Edit`, `Bash`, `WebSearch`, `WebFetch`, `Task`,
  `AskUserQuestion`). The narrow `tools: Read, Write, Glob, Grep` set
  is the structural guarantee.
