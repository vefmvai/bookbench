#!/usr/bin/env bash
# audit-public-cleanliness.sh — pre-release gate for stage 17.
#
# Verifies that no personal data from the BookBench maintainer's own books has
# leaked into the public bookbench/ repository.
#
# Marker source priority:
#   1. Explicit BOOKBENCH_AUDIT_MARKERS_FILE env variable (if set).
#   2. ~/.bookbench/audit-private-markers.txt (real audit; never committed).
#   3. bookbench/tests/audit-public-cleanliness.example.txt (fallback;
#      with a warning, since example markers are intentionally not real).
#
# Exit codes:
#   0 — PASS (no personal markers found in target tree).
#   1 — FAIL (one or more markers found; list of violations printed).
#   2 — Usage / configuration error.
#
# Reference: PS-08.1-05 (etap 08.1, decisions-08.1.md).

set -euo pipefail

QUIET=0
LIST_MARKERS=0
TARGET="plugins/bookbench/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)         QUIET=1; shift ;;
    --list-markers)  LIST_MARKERS=1; shift ;;
    --target)
      [[ $# -ge 2 ]] || { echo "ERROR: --target requires a path argument" >&2; exit 2; }
      TARGET="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: $0 [--quiet] [--list-markers] [--target <path>]" >&2
      exit 2 ;;
  esac
done

# Resolve the markers file.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_FILE="$SCRIPT_DIR/audit-public-cleanliness.example.txt"
DEFAULT_PRIVATE="${HOME}/.bookbench/audit-private-markers.txt"
MARKERS_FILE="${BOOKBENCH_AUDIT_MARKERS_FILE:-$DEFAULT_PRIVATE}"
USING_EXAMPLE=0

if [[ ! -f "$MARKERS_FILE" ]]; then
  if [[ -f "$EXAMPLE_FILE" ]]; then
    [[ "$QUIET" -eq 0 ]] && echo "WARNING: $MARKERS_FILE not found. Using example markers from $EXAMPLE_FILE."
    [[ "$QUIET" -eq 0 ]] && echo "         Create $DEFAULT_PRIVATE for a real audit."
    MARKERS_FILE="$EXAMPLE_FILE"
    USING_EXAMPLE=1
  else
    echo "ERROR: no markers file found (looked at $MARKERS_FILE and $EXAMPLE_FILE)" >&2
    exit 2
  fi
fi

# Read patterns: skip blank lines and lines starting with '#'.
PATTERNS=()
while IFS= read -r line || [[ -n "$line" ]]; do
  trimmed="${line#"${line%%[![:space:]]*}"}"      # ltrim
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}" # rtrim
  [[ -z "$trimmed" ]] && continue
  [[ "$trimmed" == \#* ]] && continue
  PATTERNS+=("$trimmed")
done < "$MARKERS_FILE"

if [[ "$LIST_MARKERS" -eq 1 ]]; then
  echo "Markers file: $MARKERS_FILE"
  echo "Loaded ${#PATTERNS[@]} pattern(s):"
  for p in "${PATTERNS[@]}"; do
    echo "  $p"
  done
  exit 0
fi

if [[ "${#PATTERNS[@]}" -eq 0 ]]; then
  [[ "$QUIET" -eq 0 ]] && echo "PASS: marker list is empty (no audit performed)."
  exit 0
fi

if [[ ! -d "$TARGET" && ! -f "$TARGET" ]]; then
  echo "ERROR: target path does not exist: $TARGET" >&2
  exit 2
fi

# Build the alternation pattern.
JOINED=""
for p in "${PATTERNS[@]}"; do
  if [[ -z "$JOINED" ]]; then
    JOINED="$p"
  else
    JOINED="$JOINED|$p"
  fi
done

# Run grep. Exclude the example file itself (so it does not match its own
# patterns) and standard noise (.git, node_modules).
set +e
RAW="$(grep -i -r -n -E "$JOINED" "$TARGET" \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude="audit-public-cleanliness.example.txt" \
    2>/dev/null)"
GREP_RC=$?
set -e

# Defensive post-filter: drop any line whose path ends with the example file
# (in case --exclude was not honored by some grep variants).
if [[ -n "$RAW" ]]; then
  RAW="$(printf '%s\n' "$RAW" | grep -v 'audit-public-cleanliness\.example\.txt:' || true)"
fi

if [[ -z "$RAW" ]]; then
  if [[ "$QUIET" -eq 0 ]]; then
    if [[ "$USING_EXAMPLE" -eq 1 ]]; then
      echo "PASS: no example markers found in $TARGET (note: example markers are not real personal data)."
    else
      echo "PASS: no personal markers found in $TARGET."
    fi
  fi
  exit 0
fi

# Count violations.
COUNT="$(printf '%s\n' "$RAW" | wc -l | tr -d ' ')"
if [[ "$QUIET" -eq 0 ]]; then
  echo "FAIL: $COUNT violation(s) found in $TARGET:"
  echo "------------------------------------------------------------"
  printf '%s\n' "$RAW"
  echo "------------------------------------------------------------"
  echo "Markers file: $MARKERS_FILE"
else
  echo "FAIL: $COUNT"
fi
exit 1
