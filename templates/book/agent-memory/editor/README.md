# Memory pointer — editor

The actual memory file for this role lives at the native Claude Code project-memory path:

```
.book/.claude/agent-memory/editor/MEMORY.md
```

This file is just a pointer for the author — it stays at `.book/agent-memory/editor/README.md`. The agent itself reads and writes to the native path because the agent's frontmatter has `memory: project`.

## What is in MEMORY.md

For role `editor`, the MEMORY.md follows the schema in `role-memory-schemas.md` (etap 08). Key sections:

- Active high-level decisions (for the role).
- Active registries (per-role: metaphors, sources, anti-cliche occurrences, etc.).
- Recently archived entries (auto-compacted on chapter approval).

## How to inspect

```
cat .book/.claude/agent-memory/editor/MEMORY.md
```

## How to edit

Do NOT edit by hand. The agent owns this file. Use `/book:guidelines editor` to influence its behaviour through guidelines instead.
