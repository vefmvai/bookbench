#!/usr/bin/env bash
# terminology-lint.sh
#
# Дополнительный PostToolUse hook (этап 24, D-40): проверка англицизмов-калек
# в русскоязычных артефактах книги (`draft.md`, `edited.md`, `marketing.md`,
# `summary.md`). Обращается к глоссарию `lib/terminology-ru.md`.
#
# Поведение:
#   - "block" уровень (exit 2) — для калек с прямым русским эквивалентом:
#     `скаффолдинг`, `скаффолд`, `дефолт`, `по дефолту`.
#   - "warn"  уровень (exit 0 + stderr) — для остальных калек из глоссария.
#
# Скрипт самодостаточен: список калек захардкожен в этом файле как
# зеркало `lib/terminology-ru.md`. При обновлении глоссария — обновлять и здесь.
#
# Контракт hook'а: получает на stdin JSON-конверт {tool_name, file_path, content}
# или fallback на CLAUDE_TEST_CONTENT / CLAUDE_TEST_FILE_PATH для прямого вызова.
#
# Источник: lib/terminology-ru.md (этап 24, D-40).

set -uo pipefail

SIZE_LIMIT_BYTES="${BOOKBENCH_LINT_SIZE_LIMIT:-204800}"

# -----------------------------------------------------------------------------
# Patterns (mirror of lib/terminology-ru.md)
# -----------------------------------------------------------------------------

# Уровень "block": прямой русский эквивалент есть.
declare -a BLOCK_PATTERNS=(
    'скаффолдинг'
    'скаффолд'
    '\bдефолт\b'
    'по дефолту'
    'по\s+дефолту'
)

# Уровень "warn": замена желательна, но не блокирующая.
declare -a WARN_PATTERNS=(
    'воркфлоу'
    'пайплайн'
    'чекпоинт'
    'таймстамп'
    '\bфоллбэк\b'
    '\bфолбэк\b'
    'апрув(нул|нуть|нул|ить)?'
    'заапрувить'
    'конфирм(нул|нуть|нул|ить)?'
    'сэмпл(ы|ов|ам|ами|ах)?'
    'батч'
    'саммари'
)

# -----------------------------------------------------------------------------
# Read input
# -----------------------------------------------------------------------------

CONTENT=""
FILE_PATH=""

if [[ -n "${CLAUDE_TEST_CONTENT:-}" ]]; then
    CONTENT="$CLAUDE_TEST_CONTENT"
    FILE_PATH="${CLAUDE_TEST_FILE_PATH:-}"
elif [[ ! -t 0 ]]; then
    # Read JSON envelope from stdin.
    INPUT="$(cat)"
    # Best-effort extraction without jq (Bash 3.2-compatible).
    FILE_PATH=$(printf '%s' "$INPUT" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)
    CONTENT=$(printf '%s' "$INPUT" | sed -nE 's/.*"content"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)
    # Если content пустой — попробуем читать файл.
    if [[ -z "$CONTENT" && -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
        CONTENT=$(cat "$FILE_PATH" 2>/dev/null || echo "")
    fi
fi

# Проверять только текстовые артефакты книги.
case "$FILE_PATH" in
    *draft.md|*edited.md|*marketing.md|*summary.md|*.book/inputs/*) ;;
    *) exit 0 ;;  # пропустить — не наш файл
esac

# Размер.
CONTENT_SIZE=${#CONTENT}
if (( CONTENT_SIZE > SIZE_LIMIT_BYTES )); then
    exit 0
fi
if (( CONTENT_SIZE == 0 )); then
    exit 0
fi

# -----------------------------------------------------------------------------
# Match patterns
# -----------------------------------------------------------------------------

BLOCK_HITS=()
WARN_HITS=()

for pat in "${BLOCK_PATTERNS[@]}"; do
    # Case-insensitive grep (egrep -i).
    if printf '%s' "$CONTENT" | grep -E -i -q "$pat"; then
        BLOCK_HITS+=("$pat")
    fi
done

for pat in "${WARN_PATTERNS[@]}"; do
    if printf '%s' "$CONTENT" | grep -E -i -q "$pat"; then
        WARN_HITS+=("$pat")
    fi
done

# -----------------------------------------------------------------------------
# React
# -----------------------------------------------------------------------------

if (( ${#BLOCK_HITS[@]} > 0 )); then
    {
        echo "[terminology-lint] BLOCK: найдены англицизмы-кальки с прямым русским эквивалентом."
        echo "Файл: $FILE_PATH"
        echo "Замены (см. lib/terminology-ru.md):"
        for pat in "${BLOCK_HITS[@]}"; do
            case "$pat" in
                *скаффолд*) echo "  «скаффолдинг» / «скаффолд» → «развёртывание» / «создание скелета» / «каркас»" ;;
                *дефолт*)   echo "  «дефолт» / «по дефолту» → «значение по умолчанию» / «по умолчанию»" ;;
            esac
        done
        echo ""
        echo "Перепиши и сохрани файл заново. Если калька — намеренный технический термин (имя поля,"
        echo "переменной, идентификатора) и должна остаться — добавь исключение в"
        echo ".book/agent-guidelines/<role>/forbidden-phrases.md → секция \"# Allowed (overrides default)\"."
    } >&2
    exit 2
fi

if (( ${#WARN_HITS[@]} > 0 )); then
    {
        echo "[terminology-lint] WARN: найдены англицизмы-кальки. Замени, если возможно (см. lib/terminology-ru.md):"
        for pat in "${WARN_HITS[@]}"; do
            echo "  паттерн: $pat"
        done
    } >&2
    # Warn не блокирует.
    exit 0
fi

exit 0
