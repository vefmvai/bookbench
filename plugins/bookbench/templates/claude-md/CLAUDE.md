# Book project — Claude Code instructions

> This file is the entry point for any Claude Code session in this book folder. Keep it short — it points at the real source of truth.

## What this folder is

A BookBench book. Plugin: `bookbench` v0.1+.

The book's content lives in `.book/`. The plugin code lives in `${CLAUDE_PLUGIN_ROOT}/`.

## Where to look

| What you need | Where to read |
|---------------|----------------|
| Vision and constraints | `.book/PROJECT.md` |
| Section plan | `.book/ROADMAP.md` |
| Current state | `.book/STATE.md` |
| Quantitative parameters | `.book/config.yaml` |
| Voice profile | `.book/context/voice-profile.md` |
| Glossary | `.book/context/glossary.md` |
| Per-role guidelines | `.book/agent-guidelines/<role>/` |
| Per-role memory (do not edit by hand) | `.book/.claude/agent-memory/<role>/MEMORY.md` |

## How to start

In this folder:

```
> /book:resume       # if continuing work
> /book:status       # to see where you are
> /book:next         # to get a recommendation
```

If this is a brand-new folder, run `/book:start` first.

## Conventions

- Hidden folders `.book/`, `.book/.claude/`, `.book/.hooks/`, `.book/.backup/` are owned by the framework. Do not edit by hand unless you know what you are doing.
- Logs `.book/TUNING-LOG.md`, `REJECTIONS-LOG.md`, `UPDATE-LOG.md` are append-only.
- Section artefacts in `.book/sections/<id>/` follow a strict per-role ownership: spec.md (strategist), draft.md (writer), factcheck.md (factchecker), edited.md (editor), marketing.md (marketer), summary.md (coordinator).

## Help

- `/book:help` — list of plugin commands.
- `docs/` inside the plugin — full documentation.
- `https://github.com/vefmvai/bookbench` — homepage.
