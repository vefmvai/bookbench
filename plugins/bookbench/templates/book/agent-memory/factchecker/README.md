# Memory pointer — factchecker

The actual memory file for this role lives at the native Claude Code project-memory path:

```
.book/.claude/agent-memory/factchecker/MEMORY.md
```

This file is just a pointer for the author — it stays at `.book/agent-memory/factchecker/README.md`. The agent itself reads and writes to the native path because the agent's frontmatter has `memory: project`.

## What is in MEMORY.md

For role `factchecker`, the MEMORY.md follows the schema in `role-memory-schemas.md` (etap 08). Key sections:

- Active high-level decisions (for the role).
- Active registries (per-role: metaphors, sources, anti-cliche occurrences, etc.).
- Recently archived entries (auto-compacted on section approval).

## How to inspect

```
cat .book/.claude/agent-memory/factchecker/MEMORY.md
```

## How to edit

Do NOT edit by hand. The agent owns this file. Use `/book:guidelines factchecker` to influence its behaviour through guidelines instead.
