#!/usr/bin/env bash
# Bash test harness for anti-ai-cliche-lint.sh.
#
# Coverage (volume A baseline):
#   - 12 block-level patterns (one each).
#   - 5 warn-level cases.
#   - 3 info-level cases.
#   - 2 per-book overrides.
#   - 1 per-chapter override.
#
# Usage:
#   bash bookbench/templates/hooks/tests/anti-ai-cliche-lint.test.sh
#
# Exit code: 0 if all tests pass; non-zero if any test fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../anti-ai-cliche-lint.sh"
PATTERNS_FILE="$SCRIPT_DIR/../../../skills/anti-ai-cliche/references/patterns.tsv"

if [[ ! -x "$HOOK" ]]; then
    echo "FATAL: hook script $HOOK is not executable." >&2
    exit 1
fi
if [[ ! -f "$PATTERNS_FILE" ]]; then
    echo "FATAL: patterns file $PATTERNS_FILE does not exist." >&2
    exit 1
fi

PASS=0
FAIL=0
FAILED_NAMES=()

run_case() {
    local name="$1"
    local expected_exit="$2"
    local content="$3"
    local file_path="${4:-/tmp/test/draft.md}"
    local extra_book_root="${5:-}"
    local stderr_expected_substring="${6:-}"

    local actual_stderr actual_exit tmp_stderr
    tmp_stderr="$(mktemp -t bb-test-stderr.XXXXXX)"

    local cmd_env=(
        "BOOKBENCH_PATTERNS_FILE=$PATTERNS_FILE"
        "CLAUDE_TEST_CONTENT=$content"
        "CLAUDE_TEST_FILE_PATH=$file_path"
    )
    if [[ -n "$extra_book_root" ]]; then
        cmd_env+=("BOOKBENCH_BOOK_ROOT=$extra_book_root")
    fi

    env "${cmd_env[@]}" "$HOOK" 2> "$tmp_stderr"
    actual_exit=$?
    actual_stderr="$(cat "$tmp_stderr")"
    rm -f "$tmp_stderr"

    if [[ "$actual_exit" -ne "$expected_exit" ]]; then
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name (exit $actual_exit, expected $expected_exit)")
        printf '  FAIL: %s — exit %d, expected %d\n' "$name" "$actual_exit" "$expected_exit" >&2
        if [[ -n "$actual_stderr" ]]; then
            printf '    stderr: %s\n' "$actual_stderr" >&2
        fi
        return 1
    fi

    if [[ -n "$stderr_expected_substring" \
        && "$actual_stderr" != *"$stderr_expected_substring"* ]]; then
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name (stderr lacks '$stderr_expected_substring')")
        printf '  FAIL: %s — stderr lacks expected substring %s\n' \
            "$name" "$stderr_expected_substring" >&2
        printf '    actual stderr: %s\n' "$actual_stderr" >&2
        return 1
    fi

    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$name"
    return 0
}

# -----------------------------------------------------------------------------
# Block-level tests (one per block pattern).
# Expected exit: 2.
# -----------------------------------------------------------------------------

echo "== Block-level patterns =="

run_case "block #5 vague attribution" 2 \
    "Это нормальный абзац. Исследования показывают, что регулярные перерывы повышают продуктивность."

run_case "block #18 emoji in prose" 2 \
    "Внимание — это голосование 🚀. Каждое слово смотрит на соседей."

run_case "block #20 collaborative communication" 2 \
    "Этот абзац описывает методику. Дайте знать, если хотите узнать больше."

run_case "block #21 knowledge cutoff disclaimer" 2 \
    "На момент моего обучения этот фреймворк активно использовался крупными компаниями."

run_case "block #22 sycophantic tone" 2 \
    "Отличный вопрос! Это действительно интересная тема для разбора."

run_case "block #25 generic positive conclusion" 2 \
    "Текст про методологию. В заключение, BookBench — это мощный инструмент, который трансформирует рабочий процесс."

run_case "block #27 persuasive authority trope" 2 \
    "Не вызывает сомнений, что эта концепция изменит индустрию навсегда."

run_case "block #34 AI summary sentence" 2 \
    "Платформа — революционный фреймворк, который сплетает мозаику субагентов."

run_case "block #35 journey metaphor" 2 \
    "В этой главе мы отправимся в увлекательное путешествие в мир методологии."

run_case "block #36 secret revelation" 2 \
    "Сегодня мы раскрываем секреты, о которых вы не знали."

run_case "block #38 fake personal experience" 2 \
    "Я помню, как однажды столкнулся с похожей задачей в моей практике."

run_case "block #40 click-bait" 2 \
    "Вы не поверите, что произошло дальше с этим алгоритмом."

# -----------------------------------------------------------------------------
# Warn-level tests (5 cases).
# Expected exit: 0 (warn does not block), but stderr should mention WARN.
# -----------------------------------------------------------------------------

echo "== Warn-level patterns =="

run_case "warn #1 undue emphasis" 0 \
    "Это событие знаменует собой важный поворот в развитии области." \
    "/tmp/test/draft.md" "" "anti-ai-cliche WARN"

run_case "warn #4 promotional language" 0 \
    "Передовой инновационный прорывной бесшовный надёжный продукт нового поколения." \
    "/tmp/test/draft.md" "" "anti-ai-cliche WARN"

run_case "warn #7 AI vocabulary" 0 \
    "Давайте погрузимся в эту тему чуть глубже и осмотрим ландшафт сегодняшних решений." \
    "/tmp/test/draft.md" "" "anti-ai-cliche WARN"

run_case "warn #23 filler phrases" 0 \
    "Важно отметить, что этот компонент работает по сложной схеме." \
    "/tmp/test/draft.md" "" "anti-ai-cliche WARN"

run_case "warn #28 signposting" 0 \
    "В этом разделе мы обсудим основные принципы построения системы." \
    "/tmp/test/draft.md" "" "anti-ai-cliche WARN"

# -----------------------------------------------------------------------------
# Info-level tests (3 cases). Expected exit: 0; no warn/block on stderr (or
# stderr is empty / contains no WARN tag).
# -----------------------------------------------------------------------------

echo "== Info-level patterns =="

run_case "info #17 canned heading" 0 \
    "## Основные принципы построения системы X
Параграф первого уровня заголовка."

run_case "info #19 mixed quotation marks" 0 \
    'Автор говорит «привет, мир», а кто-то отвечает "hello".'

run_case "info #44 symmetric section structure" 0 \
    "**A:** суть. **B:** другое. **C:** третье. **D:** четвёртое. **E:** пятое."

# -----------------------------------------------------------------------------
# Override tests.
# -----------------------------------------------------------------------------

echo "== Override tests =="

# (1) Per-book override — downgrade a block pattern to skip.
TMP_BOOK_1="$(mktemp -d -t bb-override-book.XXXXXX)"
mkdir -p "$TMP_BOOK_1/agent-guidelines/writer"
cat > "$TMP_BOOK_1/agent-guidelines/writer/forbidden-phrases.md" <<'OVERRIDE'
# Per-role override file

pattern_38:
  level: skip

pattern_18:
  level: warn
OVERRIDE

# pattern 38 (fake personal experience) is normally block; with override "skip"
# the hook should pass with exit 0.
run_case "override #38 block→skip via per-book file" 0 \
    "Я помню, как однажды столкнулся с похожей задачей." \
    "/tmp/test/draft.md" "$TMP_BOOK_1"

# pattern 18 (emoji) is normally block; with override "warn" the hook should
# emit WARN on stderr and exit 0.
run_case "override #18 block→warn via per-book file" 0 \
    "Это абзац с эмодзи 🚀 внутри текста." \
    "/tmp/test/draft.md" "$TMP_BOOK_1" \
    "anti-ai-cliche WARN"

rm -rf "$TMP_BOOK_1"

# (2) Per-chapter override via spec.md anti_cliche_overrides block.
TMP_BOOK_2="$(mktemp -d -t bb-override-chapter.XXXXXX)"
mkdir -p "$TMP_BOOK_2/chapters/001"
cat > "$TMP_BOOK_2/chapters/001/spec.md" <<'SPEC'
---
chapter_id: chapter-001
created_by: book-strategist
---

# Chapter spec

anti_cliche_overrides:
  pattern_35: skip
  pattern_22: warn
SPEC

# pattern 35 (journey metaphor) is normally block; with chapter-level "skip"
# the hook passes.
run_case "override #35 block→skip via chapter spec" 0 \
    "В этой главе мы отправимся в увлекательное путешествие в мир знаний." \
    "$TMP_BOOK_2/chapters/001/draft.md" "$TMP_BOOK_2"

rm -rf "$TMP_BOOK_2"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

TOTAL=$((PASS + FAIL))
echo
echo "================================================================="
echo "Test summary: $PASS / $TOTAL passed"
if [[ $FAIL -gt 0 ]]; then
    echo "Failures:"
    for n in "${FAILED_NAMES[@]}"; do
        echo "  - $n"
    done
    exit 1
fi
exit 0
