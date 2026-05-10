#!/usr/bin/env bash
# Stage 08.1, Wave B, T4-C — privacy structural test for /bookbench:voice * commands.
# PS-08.1-07: every <execution> bash block in voice-build / voice-extract / voice-save-as
# / voice-import / voice-list MUST refuse to write inside the plugin tree
# (`${CLAUDE_PLUGIN_ROOT}` / `bookbench/`). voice-list must be read-only.
#
# This is a STRUCTURAL test: it greps the markdown source of each command for
# (a) the presence of a privacy guard ("refusing to write inside plugin tree"
# diagnostic plus a `case "$..." in "$PLUGIN_ROOT"*)` pattern), and
# (b) the absence of any direct write into the plugin tree
# (no `cp ... bookbench/`, no `Write ... bookbench/`, no `mv ... bookbench/`).
#
# Returns exit 0 if all four cases PASS, exit 1 otherwise.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$(cd "$SCRIPT_DIR/../plugins/bookbench/commands" && pwd)"

PASS=0
FAIL=0
FAILURES=()

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$file"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("[FAIL] $label  (pattern not found: $pattern in $(basename "$file"))")
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -qE "$pattern" "$file"; then
    FAIL=$((FAIL + 1))
    HITS=$(grep -nE "$pattern" "$file" | head -3)
    FAILURES+=("[FAIL] $label  (forbidden pattern matched in $(basename "$file"): $HITS)")
  else
    PASS=$((PASS + 1))
  fi
}

# Test 1: voice-extract.md — read-only on .book/, optional --to-file outside plugin.
TEST1_FILE="$COMMANDS_DIR/voice-extract.md"
assert_contains    "$TEST1_FILE" 'refusing to write inside plugin tree'                            'T1.1 voice-extract has plugin-tree privacy diagnostic'
assert_contains    "$TEST1_FILE" 'case "\$ABS_OUT" in'                                             'T1.2 voice-extract checks --to-file path against plugin tree'
assert_not_contains "$TEST1_FILE" '(cp|mv|Write)[^"]*\$PLUGIN_ROOT'                                'T1.3 voice-extract has no direct writes into PLUGIN_ROOT'
assert_not_contains "$TEST1_FILE" '(^|[^a-z])cp [^"\n]*bookbench/'                                  'T1.4 voice-extract has no direct cp into bookbench/'

# Test 2: voice-save-as.md — writes only to ~/.bookbench/voices/<name>.md.
TEST2_FILE="$COMMANDS_DIR/voice-save-as.md"
assert_contains    "$TEST2_FILE" 'refusing to write inside plugin tree'                            'T2.1 voice-save-as has plugin-tree privacy diagnostic'
assert_contains    "$TEST2_FILE" 'case "\$TARGET_PATH" in'                                         'T2.2 voice-save-as guards TARGET_PATH against PLUGIN_ROOT'
assert_contains    "$TEST2_FILE" 'refusing to write inside the current book'                       'T2.3 voice-save-as guards against writing inside .book/'
assert_not_contains "$TEST2_FILE" '(^|[^a-z])cp [^"\n]*bookbench/'                                  'T2.4 voice-save-as has no direct cp into bookbench/'

# Test 3: voice-import.md — reads from ~/.bookbench/voices/, writes only to .book/.
TEST3_FILE="$COMMANDS_DIR/voice-import.md"
assert_contains    "$TEST3_FILE" 'refusing to write inside plugin tree'                            'T3.1 voice-import has plugin-tree privacy diagnostic'
assert_contains    "$TEST3_FILE" 'case "\$PROFILE_PATH" in'                                        'T3.2 voice-import guards PROFILE_PATH against PLUGIN_ROOT'
assert_contains    "$TEST3_FILE" 'case "\$SAMPLES_PATH" in'                                        'T3.3 voice-import guards SAMPLES_PATH against PLUGIN_ROOT'
assert_not_contains "$TEST3_FILE" '(^|[^a-z])cp [^"\n]*bookbench/'                                  'T3.4 voice-import has no direct cp into bookbench/'

# Test 4: voice-list.md — strictly read-only.
TEST4_FILE="$COMMANDS_DIR/voice-list.md"
# Read-only: no Write, no Edit, no cp/mv (other than referencing them in prose).
# The frontmatter `allowed-tools` MUST NOT include Write or Edit.
ALLOWED=$(awk '/^allowed-tools:/ {print; exit}' "$TEST4_FILE")
case "$ALLOWED" in
  *Write*) FAIL=$((FAIL + 1)); FAILURES+=("[FAIL] T4.1 voice-list allowed-tools includes Write");;
  *Edit*)  FAIL=$((FAIL + 1)); FAILURES+=("[FAIL] T4.1 voice-list allowed-tools includes Edit");;
  *)       PASS=$((PASS + 1));;
esac
# The body should not contain any cp/mv/redirect-to-file inside execution that
# would write a real file. We allow `printf`/`echo` to stdout, but reject `> "$X"`.
if grep -nE '(^|[^|])>[ \t]*"\$' "$TEST4_FILE" >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  FAILURES+=("[FAIL] T4.2 voice-list has a file write redirection '> \"\$...\"'")
else
  PASS=$((PASS + 1))
fi
assert_not_contains "$TEST4_FILE" '(^|[^a-z])cp [^"\n]*bookbench/'                                  'T4.3 voice-list has no direct cp into bookbench/'

# Bonus: voice-build.md — writes to .book/ only, never to bookbench/ or to library.
TEST5_FILE="$COMMANDS_DIR/voice-build.md"
assert_contains    "$TEST5_FILE" 'refusing to write inside plugin tree'                            'T5.1 voice-build has plugin-tree privacy diagnostic'
assert_contains    "$TEST5_FILE" 'case "\$PROFILE_PATH" in'                                        'T5.2 voice-build guards PROFILE_PATH against PLUGIN_ROOT'
assert_not_contains "$TEST5_FILE" '(^|[^a-z])cp [^"\n]*bookbench/'                                  'T5.3 voice-build has no direct cp into bookbench/'

echo ""
echo "voice-commands-privacy.test.sh: PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  $f"
  done
  exit 1
fi
exit 0
