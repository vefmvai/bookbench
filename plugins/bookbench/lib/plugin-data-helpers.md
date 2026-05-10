# Plugin data helpers (referenced by commands at stage 13)

> Shared helper procedures used by `/bookbench:start`, `/bookbench:status`, `/bookbench:help`, `/bookbench:plan-book` etc. Stage 13 implementation. PS-13-01 closes the resolution policy.
>
> The bash code blocks below are recipes that the coordinator (or the command itself, since commands are markdown prompts executed by Claude Code) runs through the Bash tool. They are deterministic and idempotent.

## H1. resolve_plugin_data_path

Resolves the absolute path to `${CLAUDE_PLUGIN_DATA}` for this plugin (`bookbench`).

Order of precedence (PS-13-01):

1. Environment variable `CLAUDE_PLUGIN_DATA` if set and the directory exists or can be created.
2. Platform fallback:
   - macOS / Linux: `${XDG_DATA_HOME:-$HOME/.local/share}/bookbench`.
   - Windows (incl. WSL): `${LOCALAPPDATA}/bookbench` if `LOCALAPPDATA` is set; otherwise the macOS / Linux fallback.

Bash recipe (run via the Bash tool):

```bash
resolve_plugin_data_path() {
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    echo "$CLAUDE_PLUGIN_DATA"
    return 0
  fi
  if [ -n "${LOCALAPPDATA:-}" ]; then
    echo "$LOCALAPPDATA/bookbench"
    return 0
  fi
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"
}

PLUGIN_DATA="$(resolve_plugin_data_path)"
mkdir -p "$PLUGIN_DATA"
echo "$PLUGIN_DATA"
```

Use the resulting path in subsequent reads/writes.

## H2. resolve_plugin_root_path

Resolves the absolute path to `${CLAUDE_PLUGIN_ROOT}` for this plugin.

Order of precedence:

1. Environment variable `CLAUDE_PLUGIN_ROOT` if set.
2. Otherwise, walk upwards from the command file location to find a directory that contains a `.claude-plugin/plugin.json` whose `name` field equals `bookbench`. This is the directory of the plugin source.

Bash recipe (best-effort fallback when no env var; the coordinator usually has the plugin path injected):

```bash
resolve_plugin_root_path() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    echo "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  # Fallback: search common locations.
  for candidate in "$HOME/.claude/plugins/bookbench" "$HOME/.claude/plugins/bookbench/main"; do
    if [ -f "$candidate/manifest.json" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}
```

In stage 13 the coordinator may need to read `manifest.json` for the plugin version. If `resolve_plugin_root_path` fails, fall back to the literal string `"unknown"` for `bookbench_version` (do not block on this — it is diagnostic only).

## H3. ensure_installation_yaml

Ensures `${CLAUDE_PLUGIN_DATA}/installation.yaml` exists. If absent — creates it with default fields:

```yaml
source: local-dev          # local-dev | github-release | marketplace
installed_at: <ISO 8601>
plugin_version: <from manifest.json or "unknown">
```

Bash recipe:

```bash
ensure_installation_yaml() {
  local data_path="$1"
  local plugin_version="$2"   # may be "unknown"
  local installation_file="$data_path/installation.yaml"
  if [ ! -f "$installation_file" ]; then
    cat > "$installation_file" <<YAML
source: local-dev
installed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
plugin_version: $plugin_version
YAML
  fi
}
```

## H4. registry_record

Adds or updates a record in `${CLAUDE_PLUGIN_DATA}/registry.yaml`.

Schema of one record:

```yaml
- id: <slug>-<YYYY-MM-DD>
  title: <human title>
  path: <absolute path to the book directory>
  genre: <e.g. popular-science>
  language: <e.g. ru | en>
  created: <ISO 8601>
  last_touched: <ISO 8601>
  bookbench_version: <e.g. 0.1.0>
  status: active            # active | archived
```

ID generation: lowercase slug of the title (alphanumerics + dashes; whitespace collapsed; non-ASCII transliterated to ASCII or stripped) plus the YYYY-MM-DD of creation. Example: title `My Book` created on `2026-05-06` → id `my-book-2026-05-06`. If a book with the same `path` already exists, do **not** create a new record — just update `last_touched`.

Bash recipe sketch (the actual coordinator can use Python, awk, or a YAML library if available; for stage 13 a minimal sed-and-grep approach is acceptable since records are simple):

```bash
slugify() {
  # 1) lower-case 2) strip diacritics best-effort 3) replace non-alnum with dashes 4) collapse 5) trim
  printf '%s' "$1" \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

registry_record_upsert() {
  local data_path="$1"
  local book_path="$2"
  local title="$3"
  local genre="$4"
  local language="$5"
  local plugin_version="$6"
  local registry_file="$data_path/registry.yaml"

  # Initialise file if absent
  if [ ! -f "$registry_file" ]; then
    printf 'books:\n' > "$registry_file"
  fi

  local now id slug
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  slug="$(slugify "$title")"
  id="${slug}-$(date -u +%Y-%m-%d)"

  # Idempotency: check by absolute book_path
  if grep -F "  path: $book_path" "$registry_file" >/dev/null 2>&1; then
    # Update last_touched on the matching record (simple two-line replace)
    awk -v p="$book_path" -v ts="$now" '
      BEGIN{found=0}
      {
        print
        if ($0 ~ ("  path: " p)) found=1
        if (found && $0 ~ /^  last_touched: /) { sub(/last_touched: .*/, "last_touched: " ts); found=0 }
      }
    ' "$registry_file" > "$registry_file.tmp" && mv "$registry_file.tmp" "$registry_file"
    return 0
  fi

  # Append new record
  cat >> "$registry_file" <<YAML
  - id: $id
    title: $title
    path: $book_path
    genre: $genre
    language: $language
    created: $now
    last_touched: $now
    bookbench_version: $plugin_version
    status: active
YAML
}
```

Note: the awk substitution above is a best-effort single-record updater. Stage 14 replaces this with a proper YAML library call once `book-doctor` and `book-list` need richer querying.

## H5. read_installation_source

Reads the field `source` from `${CLAUDE_PLUGIN_DATA}/installation.yaml`. If the file is missing — returns `local-dev` (PS-13-01 fallback).

```bash
read_installation_source() {
  local data_path="$1"
  local installation_file="$data_path/installation.yaml"
  if [ ! -f "$installation_file" ]; then
    echo "local-dev"
    return 0
  fi
  awk '/^source:/ {print $2; exit}' "$installation_file" || echo "local-dev"
}
```

## H6. plugin_version_from_manifest

Reads `version` from `${CLAUDE_PLUGIN_ROOT}/manifest.json` (project-level) or `bookbench.version` for the BookBench-specific schema.

```bash
plugin_version_from_manifest() {
  local plugin_root="$1"
  local manifest="$plugin_root/manifest.json"
  if [ ! -f "$manifest" ]; then
    echo "unknown"
    return 0
  fi
  # Best-effort parse; jq is preferred, sed is fallback.
  if command -v jq >/dev/null 2>&1; then
    jq -r '.version // "unknown"' "$manifest"
  else
    awk -F\" '/"version":/ {print $4; exit}' "$manifest"
  fi
}
```

## When commands use these helpers

- `/bookbench:start` — H1 + H2 + H6 + H3 + H4 (full chain).
- `/bookbench:status` — H1 + H6 (compares plugin version with `.book/config.yaml.compatibility.last_synced_with`).
- `/bookbench:help` — H1 + H5 (filters dev-only commands like `/bookbench:evolve`).
- `/bookbench:plan-book`, `/bookbench:plan-section`, `/bookbench:write-section`, `/bookbench:audit-section` — usually do not touch `${CLAUDE_PLUGIN_DATA}` (they work inside `.book/`); they may call H2 to read `defaults.yaml` or genre skill if needed.

## Border with stage 14

Stage 14 implements the full `/bookbench:list`, `/bookbench:doctor`, `/bookbench:register`, `/bookbench:archive`, `/bookbench:forget` commands which require richer YAML manipulation (filter by status, walk scan-paths.yaml, archive without deletion). For stage 13 the helpers above are sufficient for MVP.
