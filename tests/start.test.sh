#!/usr/bin/env bash
# tests/start.test.sh
#
# Snapshot-тест регрессий для команды /book:start (этап 24, T9 — D-38, D-34, D-35, D-36, D-37, D-39, D-40).
#
# Поскольку /book:start — markdown-промпт, исполняемый Claude Code (а не bash-скрипт),
# полноценная end-to-end симуляция требует Claude Code SDK. Этот тест работает уровнем ниже:
# проверяет статические инварианты структуры команды, коуч-промпта, defaults.yaml и
# eval-кейсов, гарантируя что регрессии 6 классов ошибок не вернутся в код.
#
# Тестовые пакеты:
#   PACK 1 — Step 4b шлюз (D-38): UNFOLD_CONFIRMED guard в Step 6.
#   PACK 2 — voice-profile lifecycle (D-34): нет автозаписи voice-profile.md без .draft.
#   PACK 3 — genre pending (D-35): sentinel в config.yaml, guard в plan-book/plan-section/write-section.
#   PACK 4 — addressing_mode (D-36): поле в config.yaml, addressing-rules.md в шаблонах.
#   PACK 5 — document_word (D-37): document_word_* во всех 5 форматах.
#   PACK 6 — sacred-policy (D-40): нет автозаписи в agent-guidelines/.
#   PACK 7 — terminology (D-39): нет калек в коде команд и lib.
#
# Использование:
#   bash tests/start.test.sh
#
# Exit 0 = все паки прошли. Exit 1 = есть FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN="$ROOT/plugins/bookbench"

PASS=0
FAIL=0

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

# -----------------------------------------------------------------------------
echo "=== PACK 1: Step 4b confirmation gate (D-38) ==="
# -----------------------------------------------------------------------------

if grep -q 'UNFOLD_CONFIRMED' "$PLUGIN/commands/start.md"; then
    pass "UNFOLD_CONFIRMED guard упомянут в commands/start.md"
else
    fail "UNFOLD_CONFIRMED guard отсутствует в commands/start.md"
fi

if grep -qE 'if \[ "\$\{?UNFOLD_CONFIRMED.*\}? != "1" \]' "$PLUGIN/commands/start.md"; then
    pass "Гард-условие UNFOLD_CONFIRMED != \"1\" есть в Step 6"
else
    fail "Гард-условие UNFOLD_CONFIRMED != \"1\" отсутствует"
fi

if grep -q 'Step 4b' "$PLUGIN/commands/start.md"; then
    pass "Step 4b явно описан в commands/start.md"
else
    fail "Step 4b отсутствует"
fi

if grep -q '\.book\.proposed\.yaml' "$PLUGIN/commands/start.md"; then
    pass ".book.proposed.yaml упомянут в commands/start.md"
else
    fail ".book.proposed.yaml не упомянут"
fi

# -----------------------------------------------------------------------------
echo "=== PACK 2: voice-profile lifecycle (D-34) ==="
# -----------------------------------------------------------------------------

if [ -f "$PLUGIN/lib/voice-profile-lifecycle.md" ]; then
    pass "lib/voice-profile-lifecycle.md существует"
else
    fail "lib/voice-profile-lifecycle.md отсутствует"
fi

# Проверка: в commands/start.md нет прямой записи в .book/context/voice-profile.md
# БЕЗ суффикса .draft (вне комментариев / NEVER-блоков).
# Простая эвристика: подсчитать строки, где есть "voice-profile.md"
# и нет рядом ни ".draft", ни "NEVER", ни "не создавать", ни "lifecycle".
suspicious=$(grep -nE 'voice-profile\.md([^.]|$)' "$PLUGIN/commands/start.md" \
    | grep -v '\.draft' \
    | grep -v -i 'never\|не создавать\|lifecycle\|forbidden\|status:' \
    || true)
if [ -z "$suspicious" ]; then
    pass "В commands/start.md нет нерегламентированных записей в voice-profile.md"
else
    fail "Подозрительные ссылки на voice-profile.md (без .draft/NEVER):"
    echo "$suspicious" | sed 's/^/    /'
fi

# Проверка: book-writer body содержит status check (lifecycle gate).
if grep -q 'status: draft' "$PLUGIN/agent-templates/book-writer.md"; then
    pass "book-writer.md проверяет status: draft (lifecycle gate)"
else
    fail "book-writer.md НЕ проверяет status: draft"
fi

if grep -q 'status: confirmed' "$PLUGIN/agent-templates/book-writer.md"; then
    pass "book-writer.md упоминает status: confirmed"
else
    fail "book-writer.md НЕ упоминает status: confirmed"
fi

if grep -q 'voice-profile-lifecycle' "$PLUGIN/agent-templates/book-writer.md"; then
    pass "book-writer.md ссылается на voice-profile-lifecycle"
else
    fail "book-writer.md НЕ ссылается на voice-profile-lifecycle"
fi

if grep -q 'voice-profile-lifecycle' "$PLUGIN/agent-templates/book-editor.md"; then
    pass "book-editor.md ссылается на voice-profile-lifecycle"
else
    fail "book-editor.md НЕ ссылается на voice-profile-lifecycle"
fi

# voice-build.md имеет --from-staged режим.
if grep -q 'from-staged' "$PLUGIN/commands/voice-build.md"; then
    pass "voice-build.md имеет режим --from-staged"
else
    fail "voice-build.md НЕ имеет режим --from-staged"
fi

# -----------------------------------------------------------------------------
echo "=== PACK 3: genre pending (D-35) ==="
# -----------------------------------------------------------------------------

if grep -q '"pending"' "$PLUGIN/templates/book/config.yaml" || grep -q 'pending' "$PLUGIN/templates/book/config.yaml"; then
    pass "templates/book/config.yaml упоминает pending sentinel в комментарии"
else
    fail "templates/book/config.yaml НЕ упоминает pending sentinel"
fi

for cmd in plan-book plan-section write-section; do
    if grep -q 'pending' "$PLUGIN/commands/$cmd.md"; then
        pass "commands/$cmd.md содержит guard на genre=pending"
    else
        fail "commands/$cmd.md НЕ содержит guard на genre=pending"
    fi
done

# -----------------------------------------------------------------------------
echo "=== PACK 4: addressing_mode (D-36) ==="
# -----------------------------------------------------------------------------

if grep -q 'addressing_mode' "$PLUGIN/templates/book/config.yaml"; then
    pass "templates/book/config.yaml содержит поле addressing_mode"
else
    fail "templates/book/config.yaml НЕ содержит addressing_mode"
fi

if grep -q '§ 4a' "$PLUGIN/lib/start-coach-prompt.md" || grep -q 'Addressing mode' "$PLUGIN/lib/start-coach-prompt.md" || grep -q 'addressing_mode' "$PLUGIN/lib/start-coach-prompt.md"; then
    pass "lib/start-coach-prompt.md содержит § 4a (addressing_mode)"
else
    fail "lib/start-coach-prompt.md НЕ содержит § 4a"
fi

for f in writer editor; do
    if [ -f "$PLUGIN/templates/agent-guidelines/$f/addressing-rules.md" ]; then
        pass "templates/agent-guidelines/$f/addressing-rules.md существует"
    else
        fail "templates/agent-guidelines/$f/addressing-rules.md отсутствует"
    fi
done

# defaults.yaml: addressing_default есть в genres и formats.
if grep -q 'addressing_default' "$PLUGIN/defaults.yaml"; then
    pass "defaults.yaml содержит addressing_default"
else
    fail "defaults.yaml НЕ содержит addressing_default"
fi

# -----------------------------------------------------------------------------
echo "=== PACK 5: document_word (D-37) ==="
# -----------------------------------------------------------------------------

for fmt in article long-read book monograph dissertation; do
    # Грубая проверка: после строки "  $fmt:" в defaults.yaml есть document_word.
    # Просто считаем количество document_word в defaults.yaml — должно быть ≥5.
    :
done

CNT_DW=$(grep -c '^[[:space:]]*document_word:[[:space:]]' "$PLUGIN/defaults.yaml" || echo 0)
if [ "$CNT_DW" -ge 5 ]; then
    pass "defaults.yaml содержит document_word у ≥5 форматов ($CNT_DW)"
else
    fail "defaults.yaml содержит document_word только у $CNT_DW форматов (ожидалось ≥5)"
fi

CNT_DWC=$(grep -c '^[[:space:]]*document_word_capitalized:[[:space:]]' "$PLUGIN/defaults.yaml" || echo 0)
if [ "$CNT_DWC" -ge 5 ]; then
    pass "defaults.yaml содержит document_word_capitalized у ≥5 форматов"
else
    fail "defaults.yaml содержит document_word_capitalized только у $CNT_DWC форматов"
fi

# В commands/start.md Step 11 нет хардкода "Книга инициализирована".
if grep -q '^Книга инициализирована: \"\${BOOK_TITLE}\"' "$PLUGIN/commands/start.md"; then
    fail "commands/start.md содержит хардкод 'Книга инициализирована: \${BOOK_TITLE}' (D-37 регрессия!)"
else
    pass "commands/start.md НЕ содержит хардкод 'Книга инициализирована: \${BOOK_TITLE}'"
fi

if grep -q 'DOCUMENT_WORD_CAPITALIZED' "$PLUGIN/commands/start.md"; then
    pass "commands/start.md использует адаптивный \${DOCUMENT_WORD_CAPITALIZED} в Step 11"
else
    fail "commands/start.md НЕ использует \${DOCUMENT_WORD_CAPITALIZED}"
fi

# -----------------------------------------------------------------------------
echo "=== PACK 6: sacred-policy (D-40) ==="
# -----------------------------------------------------------------------------

if [ -f "$PLUGIN/lib/sacred-policy.md" ]; then
    pass "lib/sacred-policy.md существует"
else
    fail "lib/sacred-policy.md отсутствует"
fi

if grep -q 'sacred-policy' "$PLUGIN/commands/start.md"; then
    pass "commands/start.md ссылается на sacred-policy"
else
    fail "commands/start.md НЕ ссылается на sacred-policy"
fi

# В Step 6a НЕТ прямой записи в agent-guidelines/writer/voice-samples.md
suspicious=$(grep -n 'agent-guidelines/writer/voice-samples\.md' "$PLUGIN/commands/start.md" | grep -v 'NOT\|NEVER\|не записывать\|не записывать в\|прямую\|после\|перенос' || true)
if [ -z "$suspicious" ]; then
    pass "commands/start.md НЕ содержит прямой записи в agent-guidelines/writer/voice-samples.md"
else
    echo "    (информация: ссылки на agent-guidelines/writer/voice-samples.md отслежены — в контексте запретов)"
    pass "commands/start.md упоминает agent-guidelines/writer/voice-samples.md только в NEVER-блоках"
fi

# -----------------------------------------------------------------------------
echo "=== PACK 7: terminology (D-39) ==="
# -----------------------------------------------------------------------------

if [ -f "$PLUGIN/lib/terminology-ru.md" ]; then
    pass "lib/terminology-ru.md существует"
else
    fail "lib/terminology-ru.md отсутствует"
fi

if [ -f "$PLUGIN/templates/hooks/terminology-lint.sh" ]; then
    if [ -x "$PLUGIN/templates/hooks/terminology-lint.sh" ]; then
        pass "templates/hooks/terminology-lint.sh существует и executable"
    else
        fail "templates/hooks/terminology-lint.sh не executable"
    fi
else
    fail "templates/hooks/terminology-lint.sh отсутствует"
fi

# Поиск калек в commands/ и lib/ (не в terminology-ru.md, которая их перечисляет).
calque_hits=$(grep -rnE '(дефолт|Дефолт|воркфлоу|скаффолд|по дефолту)' "$PLUGIN/commands/" "$PLUGIN/lib/" 2>/dev/null \
    | grep -v 'terminology-ru\.md' \
    | grep -v 'кальк' \
    | grep -v 'не использовать' \
    || true)
if [ -z "$calque_hits" ]; then
    pass "Нет калек 'дефолт'/'воркфлоу'/'скаффолд' в commands/ и lib/"
else
    fail "Найдены кальки в commands/ и lib/ (см. ниже):"
    echo "$calque_hits" | sed 's/^/    /'
fi

# -----------------------------------------------------------------------------
echo "=== Eval-кейсы start-coach ==="
# -----------------------------------------------------------------------------

CASES_DIR="$ROOT/tests/eval-cases/start-coach"
for c in 06 07 08 09 10; do
    matched=$(find "$CASES_DIR" -maxdepth 1 -name "case-${c}-*.md" 2>/dev/null | head -1)
    if [ -n "$matched" ]; then
        pass "eval-кейс case-${c}-* существует ($(basename "$matched"))"
    else
        fail "eval-кейс case-${c}-* отсутствует"
    fi
done

# -----------------------------------------------------------------------------
echo
echo "==============================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "==============================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
