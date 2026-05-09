---
description: Final packaging of the book — concatenates all chapters/<id>/edited.md in ROADMAP.md order into final/book.md plus a TOC. With --format epub additionally produces book.epub via pandoc (if installed). Does not run audit; does not publish. Read-only with respect to chapter text.
argument-hint: "[--format md|epub] [--include-marketing]"
allowed-tools: [Read, Write, Bash, AskUserQuestion]
---

# /book:ship

<purpose>
Produce a single-file artefact for downstream publication. The framework's job ends with the markdown bundle — uploading to a publisher, e-book store, or printing service is outside scope.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- All `.book/chapters/<id>/edited.md` (ordered by `ROADMAP.md`).
- `.book/PROJECT.md` (title, author).
- Optional: `.book/context/glossary.md`, `learnings.md` (appendix).
- Optional: `.book/chapters/*/marketing.md` (if `--include-marketing`).

## Outputs

- `.book/final/book.md`, `.book/final/TOC.md`.
- With `--format epub`: `.book/final/book.epub` (requires pandoc).
- A statistics summary on stdout.

<execution>

Eight-step pattern. Mostly local file assembly; no subagent involvement.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory."; exit 0; }
[ -f .book/ROADMAP.md ] || {
  echo "No ROADMAP.md. Run /book:plan-book first."
  exit 0
}

# Parse arguments
FORMAT="md"
INCLUDE_MARKETING=0
for arg in $ARGUMENTS; do
  case "$arg" in
    --format=*)            FORMAT="${arg#--format=}" ;;
    --include-marketing)   INCLUDE_MARKETING=1 ;;
  esac
done

case "$FORMAT" in md|epub) ;; *) echo "Error: --format must be md or epub."; exit 0 ;; esac
```

### Step 2 — Build chapter list from ROADMAP.md

```bash
# Extract chapter ids in roadmap order
CHAPTER_IDS=$(awk '/^## (Chapter|Глава)/ {
  gsub(/^## (Chapter|Глава) /, "")
  gsub(/[ :].*/, "")
  print
}' .book/ROADMAP.md)

# Sanity check: every id must have edited.md
MISSING=""
for id in $CHAPTER_IDS; do
  EDITED=$(printf '.book/chapters/chapter-%03d/edited.md' "$id")
  [ -f "$EDITED" ] || MISSING="$MISSING $id"
done

if [ -n "$MISSING" ]; then
  echo "Warning: chapters with no edited.md:$MISSING"
  echo "Pass --include-incomplete to ship anyway (stage 15+ feature)."
  echo "Or finish them via /book:write-chapter <N>."
  echo ""
  # AskUserQuestion: Continue / Cancel
fi
```

### Step 3 — Confirmation gate

Present an `AskUserQuestion`:

- Title: «Ship the book?»
- Body:
  - `Format: <FORMAT>`
  - `Chapters to bundle: <count>`
  - `Output: .book/final/book.<FORMAT>`
  - `Include marketing: <yes|no>`
  - Note: «Read-only with respect to chapters. Audit and `/book:audit-book` are not run automatically.»
- Options:
  - `Ship` — proceed.
  - `Run /book:audit-book first` — exit and recommend running audit.
  - `Cancel` — exit.

### Step 4 — Resolve metadata

```bash
TITLE=$(awk '/^# / {sub(/^# /, ""); print; exit}' .book/PROJECT.md)
[ -z "$TITLE" ] && TITLE=$(awk -F: '/^title:/ {gsub(/^[ "]+|[" ]+$/, "", $2); print $2; exit}' .book/config.yaml)
[ -z "$TITLE" ] && TITLE="Untitled Book"

AUTHOR=$(awk -F: '/^author:/ {gsub(/^[ "]+|[" ]+$/, "", $2); print $2; exit}' .book/config.yaml)
[ -z "$AUTHOR" ] && AUTHOR=""
```

### Step 5 — Assemble book.md

```bash
mkdir -p .book/final
OUT_MD=".book/final/book.md"
OUT_TOC=".book/final/TOC.md"

# Header
cat > "$OUT_MD" <<HEADER
# $TITLE

${AUTHOR:+by $AUTHOR}

---

HEADER

# TOC (build alongside)
printf '# Table of Contents\n\n' > "$OUT_TOC"

# Concatenate chapters in roadmap order
TOTAL_CHARS=0
for id in $CHAPTER_IDS; do
  EDITED=$(printf '.book/chapters/chapter-%03d/edited.md' "$id")
  [ -f "$EDITED" ] || continue
  # Extract chapter title (first H1 or H2 line)
  CHTITLE=$(awk '/^# /{sub(/^# /, ""); print; exit} /^## /{sub(/^## /, ""); print; exit}' "$EDITED")
  [ -z "$CHTITLE" ] && CHTITLE="Chapter $id"

  # Append to TOC
  printf '%d. [%s](#chapter-%03d)\n' "$id" "$CHTITLE" "$id" >> "$OUT_TOC"

  # Append to book.md
  printf '\n\n<a id="chapter-%03d"></a>\n\n# %s\n\n' "$id" "$CHTITLE" >> "$OUT_MD"
  cat "$EDITED" >> "$OUT_MD"

  if [ "$INCLUDE_MARKETING" -eq 1 ]; then
    MKT=$(printf '.book/chapters/chapter-%03d/marketing.md' "$id")
    if [ -f "$MKT" ]; then
      printf '\n\n## Marketing\n\n' >> "$OUT_MD"
      cat "$MKT" >> "$OUT_MD"
    fi
  fi

  CH_CHARS=$(wc -c < "$EDITED" | tr -d ' ')
  TOTAL_CHARS=$((TOTAL_CHARS + CH_CHARS))
done

# Optional appendix: glossary
if [ -f .book/context/glossary.md ]; then
  printf '\n\n# Glossary\n\n' >> "$OUT_MD"
  cat .book/context/glossary.md >> "$OUT_MD"
fi
```

### Step 6 — Optional epub conversion

```bash
if [ "$FORMAT" = "epub" ]; then
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "Warning: pandoc is not installed. Cannot produce .epub."
    echo "Install pandoc (https://pandoc.org/installing.html) or stick with --format md."
  else
    OUT_EPUB=".book/final/book.epub"
    pandoc "$OUT_MD" -o "$OUT_EPUB" \
      --metadata title="$TITLE" \
      ${AUTHOR:+--metadata author="$AUTHOR"} \
      --toc --toc-depth=2 \
      || echo "Warning: pandoc failed. The .md bundle is still available at $OUT_MD."
  fi
fi
```

### Step 7 — Statistics

```bash
N_CH=$(echo "$CHAPTER_IDS" | wc -w | tr -d ' ')
N_BYTES=$(wc -c < "$OUT_MD" | tr -d ' ')
N_LINES=$(wc -l < "$OUT_MD" | tr -d ' ')
echo ""
echo "Bundle statistics:"
echo "  Chapters:   $N_CH"
echo "  Characters: $TOTAL_CHARS (book content) / $N_BYTES (with markup)"
echo "  Lines:      $N_LINES"
echo "  TOC:        $OUT_TOC"
echo "  Book:       $OUT_MD"
[ "$FORMAT" = "epub" ] && [ -f .book/final/book.epub ] && echo "  Epub:       .book/final/book.epub"
```

### Step 8 — Atomic state mutation + next-step

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '\n%s — `/book:ship` — bundled %d chapters into %s (%d chars)\n' \
  "$NOW" "$N_CH" "$OUT_MD" "$TOTAL_CHARS" >> .book/STATE.md

echo ""
echo "Recommended next:"
echo "  /book:extract-learnings   — capture lessons from this book."
echo "  /book:archive             — soft-hide the book in the registry."
```

### Constitutional rules

- **MUST** be read-only with respect to `chapters/` and `context/`.
- **MUST** preserve chapter order from `ROADMAP.md`.
- **MUST** confirm with the author before running (Brief-Then-Execute).
- **MUST** verify every chapter has an `edited.md`; warn (do not silently skip) if any are missing.
- **NEVER** modify the source chapters during ship.
- **NEVER** publish or upload — packaging only.
- **NEVER** invoke any subagent — pure file assembly.

</execution>
