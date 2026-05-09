# Memory pointer — marketer

The actual memory file for this role lives at the native Claude Code project-memory path:

```
.book/.claude/agent-memory/marketer/MEMORY.md
```

This file is just a pointer for the author — it stays at `.book/agent-memory/marketer/README.md`. The agent itself reads and writes to the native path because the agent's frontmatter has `memory: project`.

## What is in MEMORY.md

For role `marketer`, the MEMORY.md follows the schema in `role-memory-schemas.md` (etap 08). Key sections:

- Active high-level decisions (for the role).
- Active registries (per-role: metaphors, sources, anti-cliche occurrences, etc.).
- Recently archived entries (auto-compacted on section approval).

## How to inspect

```
cat .book/.claude/agent-memory/marketer/MEMORY.md
```

## How to edit

Do NOT edit by hand. The agent owns this file. Use `/book:guidelines marketer` to influence its behaviour through guidelines instead.
