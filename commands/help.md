---
description: Lists all BookBench slash commands grouped by category, the plugin version, the installation mode and the number of registered books. With a command argument prints the detailed help for that command.
argument-hint: "[<command-name>]"
allowed-tools: [Read, Bash, Glob, Grep]
---

# /book:help

<purpose>
Discoverability: show the user what is available right now. In dev installations adds a section listing dev-only commands such as `/book:evolve`.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Inputs

- `${CLAUDE_PLUGIN_DATA}/installation.yaml` (for dev-mode detection).
- `${CLAUDE_PLUGIN_DATA}/registry.yaml` (book count).
- This plugin's `manifest.json` (version, command list).

## Outputs

- A grouped command listing on stdout.

<execution>

This command is read-only; it composes a help screen out of the manifest plus the installation source. Stage 13 keeps the static category map below; if a new command is added to `manifest.json` it will appear under «Other» until the category map is updated.

### Step 1 — Resolve paths and read installation source

Run the same Bash recipe as `/book:start` Step 2 to get `PLUGIN_ROOT`, `PLUGIN_DATA`, `PLUGIN_VERSION`. Then:

```bash
SOURCE="local-dev"
if [ -f "$PLUGIN_DATA/installation.yaml" ]; then
  SOURCE=$(awk '/^source:/{print $2; exit}' "$PLUGIN_DATA/installation.yaml")
  [ -z "$SOURCE" ] && SOURCE="local-dev"
fi
BOOK_COUNT=0
if [ -f "$PLUGIN_DATA/registry.yaml" ]; then
  BOOK_COUNT=$(grep -cE '^  - id:' "$PLUGIN_DATA/registry.yaml" || echo 0)
fi
```

PS-13-01 defaults `SOURCE` to `local-dev` when the file is missing (early-install state). This means `/book:evolve` will be visible by default.

### Step 2 — Argument: detailed help for one command

If `$ARGUMENTS` is non-empty (one token: command name, optionally with leading slash), branch:

- Strip leading slash and `book:` prefix.
- Read `${PLUGIN_ROOT}/commands/<name>.md` (and the `:` variants if name contains `:`).
- Print: front-matter `description`, `argument-hint`, `allowed-tools`, then the body sections (`<purpose>`, `## Inputs`, `## Outputs`, `<execution>` summary line if present).

Then exit. The remaining steps run only when `$ARGUMENTS` is empty.

### Step 3 — Read manifest

Read `${PLUGIN_ROOT}/manifest.json`. Extract:

- `name`, `version`, `description`, `slash_prefix`.
- `commands` (array of paths to command files).

For each command path, read just the YAML front-matter `description` and `argument-hint`.

```bash
list_commands() {
  for f in "$PLUGIN_ROOT"/commands/*.md; do
    name=$(basename "$f" .md)
    desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f")
    args=$(awk '/^argument-hint:/{sub(/^argument-hint:[[:space:]]*"?/,""); sub(/"?$/,""); print; exit}' "$f")
    printf '%s\t%s\t%s\n' "$name" "$args" "$desc"
  done
}
```

### Step 4 — Group commands by category

Static category map for stage 13. Each command is mapped to one of: `Workflow`, `Book`, `Chapter`, `Import`, `Adapt`, `Registry`, `Dev`, `Other`.

```
Workflow:  start, status, resume, help, update
Book:      plan-book, audit-book, ship
Chapter:   plan-chapter, write-chapter, write-chapter:draft, write-chapter:factcheck,
           write-chapter:edit, write-chapter:market, audit-chapter, re-edit-chapter
Import:    import, resolve, debug, extract-learnings
Adapt:     guidelines, config, tune
Registry:  list, doctor, register, archive, forget
Dev:       evolve
```

Commands not present in the map are appended to `Other`.

### Step 5 — Filter dev-only commands

If `SOURCE != local-dev`, skip the `Dev` group entirely (do not print). The `evolve.md` command additionally has `visible_when: installation.source == local-dev` (PS-12-02). For stage 13 the runtime check happens here, in the help generator.

### Step 6 — Print

```
BookBench v${PLUGIN_VERSION} — framework for writing large coherent texts as a Claude Code plugin.

Installation:    ${SOURCE}
Registered books: ${BOOK_COUNT}

Workflow
  /book:start         <argument-hint>     <description>
  /book:status        ...
  /book:resume        ...
  /book:help          ...
  /book:update        ...

Book
  /book:plan-book     ...
  /book:audit-book    ...
  /book:ship          ...

Chapter
  /book:plan-chapter <N>   ...
  /book:write-chapter <N>  ...
  /book:write-chapter:draft <N>     ...
  /book:write-chapter:factcheck <N> ...
  /book:write-chapter:edit <N>      ...
  /book:write-chapter:market <N>    ...
  /book:audit-chapter <N>           ...
  /book:re-edit-chapter <N>         ...

Import
  /book:import           ...
  /book:resolve          ...
  /book:debug            ...
  /book:extract-learnings ...

Adapt
  /book:guidelines      ...
  /book:config          ...
  /book:tune            ...

Registry
  /book:list            ...
  /book:doctor          ...
  /book:register        ...
  /book:archive         ...
  /book:forget          ...

[only if SOURCE == local-dev]
Dev
  /book:evolve          ...

Stage 13 status:
  Implemented MVP commands (stage 13): start, status, resume, help, plan-book, plan-chapter, write-chapter, audit-chapter.
  Other commands above are scaffolds (stages 14–18).

Help on a single command: /book:help <command-name>
```

### Constitutional rules for this command

- **MUST** never call `Task`.
- **MUST** finish in ≤ 2 seconds.
- **MUST** filter `/book:evolve` correctly per PS-13-01 default and PS-12-02 mechanism.
- **NEVER** modify any file.

</execution>
