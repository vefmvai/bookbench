#!/usr/bin/env bash
# anti-ai-cliche-lint.sh
#
# PostToolUse hook for Write|Edit on section artefacts (draft.md, edited.md,
# marketing.md). Loads the 46-pattern corpus from
# skills/anti-ai-cliche/references/patterns.tsv, applies per-role overrides
# from .book/agent-guidelines/<role>/forbidden-phrases.md and per-section
# overrides from sections/<NNN>/spec.md (anti_cliche_overrides), and reacts
# according to policy: block (exit 2), warn (exit 0 + stderr), info (exit 0
# + log).
#
# Inputs (stdin): JSON envelope from Claude Code with {tool_name, file_path,
#   content}. Test harness may also provide CLAUDE_TEST_CONTENT and
#   CLAUDE_TEST_FILE_PATH for direct invocation without a JSON envelope.
# Stdout: empty (passthrough).
# Stderr: warn / block messages (when relevant).
# Exit code: 0 on clean / warn / info; 2 on block.
#
# Environment:
#   CLAUDE_AGENT_NAME       — optional override for role detection.
#   CLAUDE_PLUGIN_ROOT      — root of the bookbench plugin install (used to
#                             find the default patterns.tsv).
#   BOOKBENCH_PATTERNS_FILE — direct override path for tests.
#   BOOKBENCH_BOOK_ROOT     — root of the book folder; defaults to PWD or
#                             ".book" if PWD does not look like a book root.
#   BOOKBENCH_LINT_DEBUG    — if set, dump diagnostic info to stderr.
#
# Reaction levels (corpus version 0.1):
#   block: 12 patterns (5,18,20,21,22,25,27,34,35,36,37,38,40 — minus 40 if
#          duplicate counts; see corpus header for exact mapping).
#   warn:  ~28 patterns.
#   info:  ~6 patterns logged silently to .book/.hooks/anti-ai-cliche-occurrences.log.
#
# Performance budget: ≤2 seconds on a 25 KB draft.md. Files larger than
# SIZE_LIMIT_BYTES (200 KB by default) are skipped.

set -uo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

SIZE_LIMIT_BYTES="${BOOKBENCH_LINT_SIZE_LIMIT:-204800}"

# Locate the patterns.tsv corpus.
locate_patterns_file() {
    if [[ -n "${BOOKBENCH_PATTERNS_FILE:-}" && -f "$BOOKBENCH_PATTERNS_FILE" ]]; then
        printf '%s' "$BOOKBENCH_PATTERNS_FILE"
        return 0
    fi
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" \
        && -f "$CLAUDE_PLUGIN_ROOT/skills/anti-ai-cliche/references/patterns.tsv" ]]; then
        printf '%s' "$CLAUDE_PLUGIN_ROOT/skills/anti-ai-cliche/references/patterns.tsv"
        return 0
    fi
    # Walk up from the script location to find a sibling skills tree.
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local candidate
    for candidate in \
        "$script_dir/../../skills/anti-ai-cliche/references/patterns.tsv" \
        "$script_dir/../../../skills/anti-ai-cliche/references/patterns.tsv" \
        "$PWD/bookbench/skills/anti-ai-cliche/references/patterns.tsv"
    do
        if [[ -f "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

# Locate the book root (where .book/.hooks/ lives).
locate_book_root() {
    if [[ -n "${BOOKBENCH_BOOK_ROOT:-}" ]]; then
        printf '%s' "$BOOKBENCH_BOOK_ROOT"
        return 0
    fi
    if [[ -d ".book" ]]; then
        printf '%s' "$PWD/.book"
        return 0
    fi
    if [[ -f "STATE.md" && -d "agent-guidelines" ]]; then
        printf '%s' "$PWD"
        return 0
    fi
    printf '%s' "$PWD"
    return 0
}

# -----------------------------------------------------------------------------
# Inputs: stdin envelope or test-harness env vars.
# -----------------------------------------------------------------------------

FILE_PATH=""
CONTENT=""

if [[ -n "${CLAUDE_TEST_CONTENT:-}" || -n "${CLAUDE_TEST_FILE_PATH:-}" ]]; then
    FILE_PATH="${CLAUDE_TEST_FILE_PATH:-}"
    CONTENT="${CLAUDE_TEST_CONTENT:-}"
else
    INPUT="$(cat || true)"
    if [[ -n "$INPUT" ]]; then
        if command -v jq >/dev/null 2>&1; then
            FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.file_path // ""' 2>/dev/null || true)"
            CONTENT="$(printf '%s' "$INPUT" | jq -r '.content // ""' 2>/dev/null || true)"
        else
            # Minimal jq-less fallback: extract file_path and content via sed.
            FILE_PATH="$(printf '%s' "$INPUT" \
                | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
            CONTENT="$(printf '%s' "$INPUT" \
                | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\(.*\)"[[:space:]]*}.*/\1/p' | head -1)"
        fi
    fi
fi

if [[ -z "$CONTENT" ]]; then
    exit 0
fi

if [[ ${#CONTENT} -gt $SIZE_LIMIT_BYTES ]]; then
    echo "anti-ai-cliche-lint: file size exceeds $SIZE_LIMIT_BYTES bytes — lint skipped." >&2
    exit 0
fi

# -----------------------------------------------------------------------------
# Role detection.
#
#   1. Explicit env override CLAUDE_AGENT_NAME wins.
#   2. Else infer from FILE_PATH:
#        draft.md     → writer
#        edited.md    → editor
#        marketing.md → marketer
#   3. Else fall back to "writer" (most common author).
# -----------------------------------------------------------------------------

detect_role() {
    if [[ -n "${CLAUDE_AGENT_NAME:-}" ]]; then
        local raw="${CLAUDE_AGENT_NAME#book-}"
        printf '%s' "$raw"
        return 0
    fi
    case "$FILE_PATH" in
        *draft.md|*draft-revised-*.md)   printf 'writer' ;;
        *edited.md|*edited-*.md)         printf 'editor' ;;
        *marketing.md|*marketing-*.md)   printf 'marketer' ;;
        *)                               printf 'writer' ;;
    esac
}

ROLE="$(detect_role)"

# -----------------------------------------------------------------------------
# Override resolution.
#
# Sources of override (priority high → low):
#   (a) Per-section:  sections/<NNN>/spec.md, anti_cliche_overrides block.
#   (b) Per-role:     .book/agent-guidelines/<role>/forbidden-phrases.md.
#   (c) Default:      level from patterns.tsv.
#
# Override syntax (both files):
#   pattern_<id>:
#     level: block|warn|info|skip
# We parse line-pairs of the shape "pattern_<id>:" then "  level: <X>".
# -----------------------------------------------------------------------------

# Override store: lines of the form "<id>=<level>" inside OVERRIDE_TABLE.
# Read with override_lookup; written with override_set. macOS bash 3.2
# compatibility: no associative arrays.
OVERRIDE_TABLE=""

override_set() {
    local id="$1"
    local level="$2"
    # Drop any existing entry for this id, then append the new value.
    OVERRIDE_TABLE="$(printf '%s\n' "$OVERRIDE_TABLE" \
        | grep -v -E "^${id}=" 2>/dev/null || true)"
    OVERRIDE_TABLE="$(printf '%s\n%s=%s' "$OVERRIDE_TABLE" "$id" "$level")"
}

override_lookup() {
    local id="$1"
    local match
    match="$(printf '%s\n' "$OVERRIDE_TABLE" | grep -E "^${id}=" | tail -1)"
    if [[ -n "$match" ]]; then
        printf '%s' "${match#*=}"
        return 0
    fi
    return 1
}

parse_override_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    local current_id=""
    local line
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*pattern_([0-9]+):[[:space:]]+level:[[:space:]]+(block|warn|info|skip) ]]; then
            override_set "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            current_id=""
            continue
        fi
        if [[ "$line" =~ ^[[:space:]]*pattern_([0-9]+): ]]; then
            current_id="${BASH_REMATCH[1]}"
            continue
        fi
        if [[ -n "$current_id" && "$line" =~ ^[[:space:]]+level:[[:space:]]+(block|warn|info|skip) ]]; then
            override_set "$current_id" "${BASH_REMATCH[1]}"
            current_id=""
            continue
        fi
    done < "$file"
}

BOOK_ROOT="$(locate_book_root)"

# (b) Per-role overrides.
if [[ -n "$ROLE" ]]; then
    parse_override_file "$BOOK_ROOT/agent-guidelines/$ROLE/forbidden-phrases.md"
fi

# (a) Per-section overrides — extract section dir from FILE_PATH, then read
# spec.md if it exists. We look for an anti_cliche_overrides: block.
section_dir=""
if [[ -n "$FILE_PATH" ]]; then
    section_dir="$(dirname "$FILE_PATH")"
fi
if [[ -n "$section_dir" && -f "$section_dir/spec.md" ]]; then
    inside_block=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^anti_cliche_overrides: ]]; then
            inside_block=1
            continue
        fi
        if [[ $inside_block -eq 1 ]]; then
            if [[ "$line" =~ ^[A-Za-z_-]+: ]] && ! [[ "$line" =~ ^[[:space:]] ]]; then
                # next top-level key — stop.
                break
            fi
            if [[ "$line" =~ ^[[:space:]]*pattern_([0-9]+):[[:space:]]+(block|warn|info|skip) ]]; then
                override_set "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            fi
        fi
    done < "$section_dir/spec.md"
fi

# -----------------------------------------------------------------------------
# Pattern loading.
# -----------------------------------------------------------------------------

PATTERNS_FILE="$(locate_patterns_file || true)"
if [[ -z "$PATTERNS_FILE" || ! -f "$PATTERNS_FILE" ]]; then
    echo "anti-ai-cliche-lint: patterns.tsv not found — lint skipped." >&2
    exit 0
fi

BLOCK_HITS=()
WARN_HITS=()
INFO_HITS=()

CONTENT_TMP="$(mktemp -t bb-anti-cliche-content.XXXXXX)"
trap 'rm -f "$CONTENT_TMP"' EXIT
printf '%s' "$CONTENT" > "$CONTENT_TMP"

while IFS=$'\t' read -r p_id p_level p_regex p_name p_exception; do
    # Skip comments and blank lines.
    [[ -z "${p_id:-}" || "${p_id:0:1}" == "#" ]] && continue
    [[ -z "${p_level:-}" || -z "${p_regex:-}" ]] && continue

    effective_level="$p_level"
    override_value="$(override_lookup "$p_id" || true)"
    if [[ -n "$override_value" ]]; then
        effective_level="$override_value"
    fi
    if [[ "$effective_level" == "skip" ]]; then
        continue
    fi

    # PCRE matching via perl (portable across macOS / Linux; BSD grep lacks -P).
    # Both the pattern (env var) and the content (file) are decoded as UTF-8
    # so cyrillic regex classes like \w match correctly.
    if BB_REGEX="$p_regex" BB_FILE="$CONTENT_TMP" perl -e '
        use strict; use warnings; use utf8;
        use Encode qw(decode_utf8);
        my $regex = decode_utf8($ENV{BB_REGEX} // "");
        open my $fh, "<:encoding(UTF-8)", $ENV{BB_FILE} or exit 1;
        local $/; my $content = <$fh>;
        close $fh;
        exit 0 if $content =~ /$regex/;
        exit 1;
    ' 2>/dev/null; then
        case "$effective_level" in
            block) BLOCK_HITS+=("Pattern #$p_id ($p_name)") ;;
            warn)  WARN_HITS+=("Pattern #$p_id ($p_name)") ;;
            info)  INFO_HITS+=("Pattern #$p_id ($p_name)") ;;
        esac
    fi
done < "$PATTERNS_FILE"

# -----------------------------------------------------------------------------
# Reactions.
# -----------------------------------------------------------------------------

# info: silent log to .book/.hooks/anti-ai-cliche-occurrences.log.
if [[ ${#INFO_HITS[@]} -gt 0 ]]; then
    log_dir="$BOOK_ROOT/.hooks"
    mkdir -p "$log_dir" 2>/dev/null || true
    log_file="$log_dir/anti-ai-cliche-occurrences.log"
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for hit in "${INFO_HITS[@]}"; do
        printf '%s\t%s\t%s\t%s\n' "$timestamp" "$ROLE" "$FILE_PATH" "$hit" >> "$log_file" 2>/dev/null || true
    done
fi

# warn: stderr, exit 0.
if [[ ${#WARN_HITS[@]} -gt 0 ]]; then
    {
        printf 'anti-ai-cliche WARN [%s]:\n' "$FILE_PATH"
        printf '  - %s\n' "${WARN_HITS[@]}"
        printf '  Decide for yourself: rewrite or keep deliberately (1-2 per section is fine for warn-level).\n'
    } >&2
fi

# block: stderr + exit 2.
if [[ ${#BLOCK_HITS[@]} -gt 0 ]]; then
    {
        printf 'anti-ai-cliche BLOCK [%s]:\n' "$FILE_PATH"
        printf '  - %s\n' "${BLOCK_HITS[@]}"
        printf '  Write cancelled. Rewrite the file removing the patterns above.\n'
        printf '  If this usage is deliberate — add a pattern override to .book/agent-guidelines/%s/forbidden-phrases.md and retry.\n' "$ROLE"
    } >&2
    exit 2
fi

exit 0
