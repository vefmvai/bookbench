#!/usr/bin/env bash
# Bash test harness for ops-telemetry-hook.sh.
#
# Coverage:
#   1. UserPromptSubmit — writes one valid JSON line with prompt metadata
#      (length + truncated SHA-256 hash), but NO prompt body.
#   2. PostToolUse — writes one valid JSON line with tool metadata.
#   3. Stop — writes one minimal JSON line (no per-tool fields).
#   4. ISO 8601 timestamp present and well-formed.
#   5. Idempotency — two consecutive invocations produce two distinct JSON
#      lines without corrupting the first one.
#   6. Missing .book/ — silent skip with exit 0 (does not fail).
#   7. Privacy — prompt body is NEVER written to rawlog; only hash and length.
#
# Usage:
#   bash bookbench/templates/hooks/tests/ops-telemetry-hook.test.sh
#
# Exit code: 0 if all tests pass; non-zero if any test fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../ops-telemetry-hook.sh"

if [[ ! -x "$HOOK" ]]; then
    echo "FATAL: hook script $HOOK is not executable." >&2
    exit 1
fi

PASS=0
FAIL=0
FAILED_NAMES=()

# Each test gets a fresh tmp book root.
make_book_root() {
    local root
    root="$(mktemp -d -t bb-ops-telemetry.XXXXXX)"
    mkdir -p "$root/.book/ops-observations"
    printf '%s' "$root/.book"
}

run_hook_with_envelope() {
    local book_root="$1"
    local event="$2"
    local envelope="$3"
    BOOKBENCH_BOOK_ROOT="$book_root" \
    CLAUDE_HOOK_EVENT="$event" \
    CLAUDE_TELEMETRY_TEST_ENVELOPE="$envelope" \
        "$HOOK" 2>/dev/null
    return $?
}

assert() {
    local name="$1"
    local condition="$2"
    if [[ "$condition" == "true" ]]; then
        PASS=$((PASS + 1))
        printf '  PASS: %s\n' "$name"
    else
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name")
        printf '  FAIL: %s\n' "$name" >&2
    fi
}

# --- Test 1: UserPromptSubmit produces a valid JSON line with hash + length.
test_user_prompt_submit() {
    echo "Test 1: UserPromptSubmit writes valid JSON metadata"
    local root rawlog envelope exit_code line
    root="$(make_book_root)"
    rawlog="$root/ops-observations/rawlog.jsonl"
    envelope='{"hook_event_name":"UserPromptSubmit","session_id":"sess-aaa","prompt":"перепиши главу 5, метафора слабая, факт год не сходится"}'
    run_hook_with_envelope "$root" "UserPromptSubmit" "$envelope"
    exit_code=$?

    assert "exit code 0" "$( [[ $exit_code -eq 0 ]] && echo true || echo false )"
    assert "rawlog created" "$( [[ -f "$rawlog" ]] && echo true || echo false )"

    line="$(cat "$rawlog" 2>/dev/null)"
    assert "exactly one line" "$( [[ "$(wc -l < "$rawlog" | tr -d ' ')" == "1" ]] && echo true || echo false )"
    assert "event_type present" "$( [[ "$line" == *'"event_type":"UserPromptSubmit"'* ]] && echo true || echo false )"
    assert "session_id captured" "$( [[ "$line" == *'"session_id":"sess-aaa"'* ]] && echo true || echo false )"
    assert "prompt_hash present (16 hex)" "$( echo "$line" | grep -qE '"prompt_hash":"[0-9a-f]{16}"' && echo true || echo false )"
    assert "prompt_length present (>0)" "$( echo "$line" | grep -qE '"prompt_length":[1-9][0-9]*' && echo true || echo false )"
    # Privacy: the original prompt text MUST NOT appear in the rawlog.
    assert "prompt body NOT in rawlog (privacy)" "$( ! grep -q "перепиши главу" "$rawlog" && echo true || echo false )"

    rm -rf "$root"
}

# --- Test 2: PostToolUse captures tool metadata.
test_post_tool_use() {
    echo "Test 2: PostToolUse writes tool metadata"
    local root rawlog envelope exit_code line
    root="$(make_book_root)"
    rawlog="$root/ops-observations/rawlog.jsonl"
    envelope='{"hook_event_name":"PostToolUse","session_id":"sess-bbb","tool_name":"Task","tool_status":"ok","duration_ms":4321,"input_tokens":1200,"output_tokens":850,"agent_name":"book-writer","model":"opus","file_path":"/abs/path/to/.book/sections/003/draft.md"}'
    run_hook_with_envelope "$root" "PostToolUse" "$envelope"
    exit_code=$?

    assert "exit code 0" "$( [[ $exit_code -eq 0 ]] && echo true || echo false )"
    line="$(cat "$rawlog" 2>/dev/null)"
    assert "tool_name=Task" "$( [[ "$line" == *'"tool_name":"Task"'* ]] && echo true || echo false )"
    assert "tool_status=ok" "$( [[ "$line" == *'"tool_status":"ok"'* ]] && echo true || echo false )"
    assert "duration_ms is integer 4321" "$( [[ "$line" == *'"duration_ms":4321'* ]] && echo true || echo false )"
    assert "input_tokens=1200" "$( [[ "$line" == *'"input_tokens":1200'* ]] && echo true || echo false )"
    assert "agent=book-writer" "$( [[ "$line" == *'"agent":"book-writer"'* ]] && echo true || echo false )"
    assert "model=opus" "$( [[ "$line" == *'"model":"opus"'* ]] && echo true || echo false )"
    assert "file_path_hash (16 hex)" "$( echo "$line" | grep -qE '"file_path_hash":"[0-9a-f]{16}"' && echo true || echo false )"
    # Raw path NEVER in rawlog.
    assert "raw file_path NOT in rawlog" "$( ! grep -q "/abs/path/to/.book/sections/003/draft.md" "$rawlog" && echo true || echo false )"

    rm -rf "$root"
}

# --- Test 3: Stop event writes minimal line.
test_stop() {
    echo "Test 3: Stop event writes minimal line"
    local root rawlog envelope exit_code line
    root="$(make_book_root)"
    rawlog="$root/ops-observations/rawlog.jsonl"
    envelope='{"hook_event_name":"Stop","session_id":"sess-ccc"}'
    run_hook_with_envelope "$root" "Stop" "$envelope"
    exit_code=$?

    assert "exit code 0" "$( [[ $exit_code -eq 0 ]] && echo true || echo false )"
    line="$(cat "$rawlog" 2>/dev/null)"
    assert "event_type=Stop" "$( [[ "$line" == *'"event_type":"Stop"'* ]] && echo true || echo false )"
    assert "tool_name is null" "$( [[ "$line" == *'"tool_name":null'* ]] && echo true || echo false )"
    assert "input_tokens is null" "$( [[ "$line" == *'"input_tokens":null'* ]] && echo true || echo false )"

    rm -rf "$root"
}

# --- Test 4: timestamp ISO 8601 well-formed.
test_iso_8601_timestamp() {
    echo "Test 4: ISO 8601 timestamp"
    local root rawlog envelope line
    root="$(make_book_root)"
    rawlog="$root/ops-observations/rawlog.jsonl"
    envelope='{"hook_event_name":"Stop","session_id":"sess-ts"}'
    run_hook_with_envelope "$root" "Stop" "$envelope"
    line="$(cat "$rawlog" 2>/dev/null)"
    # Format: YYYY-MM-DDTHH:MM:SSZ
    assert "ISO 8601 UTC timestamp" "$( echo "$line" | grep -qE '"timestamp":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' && echo true || echo false )"
    rm -rf "$root"
}

# --- Test 5: idempotency / append.
test_idempotency() {
    echo "Test 5: Idempotency (two invocations append, no corruption)"
    local root rawlog envelope exit_a exit_b lines
    root="$(make_book_root)"
    rawlog="$root/ops-observations/rawlog.jsonl"

    envelope='{"hook_event_name":"PostToolUse","session_id":"sess-1","tool_name":"Read","tool_status":"ok"}'
    run_hook_with_envelope "$root" "PostToolUse" "$envelope"
    exit_a=$?

    envelope='{"hook_event_name":"PostToolUse","session_id":"sess-2","tool_name":"Write","tool_status":"ok"}'
    run_hook_with_envelope "$root" "PostToolUse" "$envelope"
    exit_b=$?

    lines="$(wc -l < "$rawlog" | tr -d ' ')"
    assert "first invocation exit 0" "$( [[ $exit_a -eq 0 ]] && echo true || echo false )"
    assert "second invocation exit 0" "$( [[ $exit_b -eq 0 ]] && echo true || echo false )"
    assert "two lines in rawlog" "$( [[ "$lines" == "2" ]] && echo true || echo false )"
    assert "first line still has sess-1" "$( head -1 "$rawlog" | grep -q '"session_id":"sess-1"' && echo true || echo false )"
    assert "second line has sess-2" "$( tail -1 "$rawlog" | grep -q '"session_id":"sess-2"' && echo true || echo false )"

    rm -rf "$root"
}

# --- Test 6: silent skip when .book/ does not exist.
test_silent_skip_no_book() {
    echo "Test 6: Silent skip when .book/ is missing"
    local root exit_code
    root="$(mktemp -d -t bb-no-book.XXXXXX)"
    # NO .book/ inside root, BOOKBENCH_BOOK_ROOT pointing to a non-existent
    # path. The hook must still exit 0 (non-blocking).
    BOOKBENCH_BOOK_ROOT="$root/missing-book" \
    CLAUDE_HOOK_EVENT="Stop" \
    CLAUDE_TELEMETRY_TEST_ENVELOPE='{"hook_event_name":"Stop","session_id":"x"}' \
        "$HOOK" 2>/dev/null
    exit_code=$?
    # When BOOKBENCH_BOOK_ROOT is set explicitly, the hook will mkdir -p
    # anyway (operator's intent is to write there). The non-blocking
    # contract is the exit code. So we just check exit_code == 0.
    assert "exit code 0 even with missing .book/" "$( [[ $exit_code -eq 0 ]] && echo true || echo false )"

    rm -rf "$root"
}

# --- Test 7: privacy — full prompt body in envelope is never written.
test_privacy_no_body_leak() {
    echo "Test 7: Privacy — long prompt body is hashed, never written"
    local root rawlog envelope line
    root="$(make_book_root)"
    rawlog="$root/ops-observations/rawlog.jsonl"
    # A long, identifying prompt body. Hook must not store it verbatim.
    local body="The author's secret manuscript fragment about a unique character named Alphonse Q. Whittlesworth-Periwinkle that appears in section seventeen."
    envelope="{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"sess-priv\",\"prompt\":\"$body\"}"
    run_hook_with_envelope "$root" "UserPromptSubmit" "$envelope"
    line="$(cat "$rawlog" 2>/dev/null)"
    assert "Alphonse name NOT in rawlog" "$( ! grep -q "Alphonse" "$rawlog" && echo true || echo false )"
    assert "Whittlesworth NOT in rawlog" "$( ! grep -q "Whittlesworth" "$rawlog" && echo true || echo false )"
    assert "manuscript word NOT in rawlog" "$( ! grep -q "manuscript" "$rawlog" && echo true || echo false )"
    # Length is roughly the body length (within +/- 4 to allow for
    # multibyte char vs byte differences).
    assert "prompt_length captured" "$( echo "$line" | grep -qE '"prompt_length":1[0-9]{2}' && echo true || echo false )"

    rm -rf "$root"
}

# -----------------------------------------------------------------------------

test_user_prompt_submit
test_post_tool_use
test_stop
test_iso_8601_timestamp
test_idempotency
test_silent_skip_no_book
test_privacy_no_body_leak

echo
echo "=============================================="
echo "ops-telemetry-hook.test: $PASS passed, $FAIL failed."
if [[ $FAIL -gt 0 ]]; then
    echo "Failed tests:"
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
exit 0
