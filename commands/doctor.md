---
description: Diagnoses the global book registry and detects drift between registered entries and what exists on disk. Walks scan-paths from ${CLAUDE_PLUGIN_DATA}/scan-paths.yaml. Reports broken paths, missing config files, version mismatches, and orphan .book/ folders not in the registry. Read-only by default; --repair offers interactive fixes.
argument-hint: "[--add-path <path>] [--repair]"
allowed-tools: [Read, Write, Edit, Bash, Glob, AskUserQuestion]
---

# /book:doctor

<purpose>
Global health-check for the multi-book setup. Finds drift between the file system and the registry; reports problems with severity tags and recommends fixes. Default mode is read-only.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `${CLAUDE_PLUGIN_DATA}/registry.yaml`.
- `${CLAUDE_PLUGIN_DATA}/scan-paths.yaml` (optional; if missing, only registered books are checked).
- `${CLAUDE_PLUGIN_DATA}/installation.yaml` for plugin version comparison.
- File system under registered paths and scan paths.

## Outputs

- A structured report on stdout (severity-labelled).
- With `--repair`: optional updates to `registry.yaml` and `scan-paths.yaml`.

<execution>

Eight-step orchestrator pattern (read-only by default; --repair adds interactive write step).

### Step 1 — Pre-flight

```bash
# H1: resolve plugin data
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  PLUGIN_DATA="$CLAUDE_PLUGIN_DATA"
elif [ -n "${LOCALAPPDATA:-}" ]; then
  PLUGIN_DATA="$LOCALAPPDATA/bookbench"
else
  PLUGIN_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bookbench"
fi
REGISTRY="$PLUGIN_DATA/registry.yaml"
SCAN="$PLUGIN_DATA/scan-paths.yaml"
INSTALL="$PLUGIN_DATA/installation.yaml"
```

If `$REGISTRY` is missing, print a friendly message and exit. The plugin is freshly installed.

### Step 2 — Parse arguments

- `--add-path <path>`: add a new directory to `scan-paths.yaml` and re-scan.
- `--repair`: enter interactive repair mode after the diagnostic pass.

### Step 3 — Read installation context

```bash
# H5: read installation source
INSTALL_SOURCE="local-dev"
[ -f "$INSTALL" ] && INSTALL_SOURCE=$(awk '/^source:/ {print $2; exit}' "$INSTALL" 2>/dev/null || echo "local-dev")

# H6: plugin version (best-effort)
PLUGIN_VERSION="unknown"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/manifest.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    PLUGIN_VERSION=$(jq -r '.version // "unknown"' "$CLAUDE_PLUGIN_ROOT/manifest.json")
  else
    PLUGIN_VERSION=$(awk -F\" '/"version":/ {print $4; exit}' "$CLAUDE_PLUGIN_ROOT/manifest.json")
  fi
fi
```

### Step 4 — Parse the registry

Use the same awk parser as `/book:list` to extract `id`, `title`, `path`, `genre`, `status`, `bookbench_version` for each record. Build a list of registered absolute paths.

### Step 5 — Diagnose registered books

For each registered entry, run these checks and assign a severity tag:

| Check | Severity | Notes |
|---|---|---|
| `path` exists on disk | CRITICAL if missing | broken-path |
| `<path>/.book/` directory exists | CRITICAL if missing | not-a-book |
| `<path>/.book/config.yaml` exists | HIGH if missing | corrupted-book |
| `<path>/.book/STATE.md` exists | MEDIUM if missing | missing-state |
| `bookbench_version` field equals current `$PLUGIN_VERSION` | INFO if mismatch | version-drift |
| Optional: `<path>/.book/.claude/agents/` has 9 files | LOW if not | partial-install |

Emit one diagnostic line per problem. Group by severity (CRITICAL → HIGH → MEDIUM → LOW → INFO).

Example output:

```
== Diagnostics for 3 registered books ==

[CRITICAL] my-book-2026-05-06: path /Users/x/Books/my-book does not exist on disk
[HIGH]     detective-2026-04-30: .book/config.yaml is missing (path exists, .book/ exists)
[INFO]     memoir-2026-03-12: bookbench_version 0.0.9 differs from current 0.1.0
```

### Step 6 — Detect orphan .book/ folders (scan-paths walk)

If `$SCAN` exists and is non-empty:

```bash
# Read the YAML list of scan paths (one path per line under "paths:")
awk '/^  - /{print substr($0,5)}' "$SCAN" 2>/dev/null > /tmp/bookbench-scan-paths.txt
```

For each scan path, find sub-directories matching `<scan_path>/*/.book/` (depth=2). For each found `.book/` folder, check whether the parent directory is already in the registered-paths set. If not — emit:

```
[ORPHAN] /Users/x/Other-Books/random-book/.book/  not in registry
         (To add: /book:register /Users/x/Other-Books/random-book)
```

If `$SCAN` is missing — emit a one-line note: `(no scan-paths.yaml; orphan detection skipped)`.

### Step 7 — Summary + repair offer

Print the summary line:

```
== Summary ==
Books registered: N
Critical issues:  X
High issues:      Y
Medium / Low / Info: Z
Orphan folders:   K
```

If `--repair` was passed AND there are issues — present an `AskUserQuestion`:

- Title: «Doctor wants to apply repairs»
- Options:
  - `Prune dead entries` (remove records with CRITICAL broken-path / not-a-book)
  - `Register orphans` (add detected orphans to the registry one-by-one)
  - `Add a new scan path` (ask for the path; append to scan-paths.yaml)
  - `Skip / cancel`

For `Prune dead entries` — for each CRITICAL entry, ask `confirm <id>?` (per-entry AskUserQuestion). On confirm, remove the entry by re-writing `registry.yaml` without that block.

For `Register orphans` — for each orphan, the equivalent of `/book:register <path>` is run interactively (re-uses logic; can be deferred by the author).

### Step 8 — Next-step message

```
Recommended next:
  /book:list                       — see the (cleaned) registry.
  /book:register <path>            — manually register a book.
  /book:doctor --add-path <path>   — add a directory to the orphan-scan list.
```

### Constitutional rules

- **MUST** be read-only without `--repair`. Default mode never edits files.
- **MUST** tolerate missing `scan-paths.yaml` (warn, do not fail).
- **MUST** request confirmation before pruning any registry entry.
- **NEVER** delete the actual `.book/` folder on disk — only update the registry.
- **NEVER** read inside any book's `chapters/` or `inputs/` — only structural / config files.

</execution>
