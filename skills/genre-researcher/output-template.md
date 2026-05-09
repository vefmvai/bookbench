# Genre methodology output template

Every `<genre>-methodology.md` file produced by the genre researcher follows this exact eight-section template. It mirrors the bundled reference `skills/genres/popular-science/SKILL.md` but adapted to the researched genre.

## Frontmatter

```yaml
---
name: <genre>-methodology
description: Provides a <genre> methodology for the BookBench writing roles — <key elements>. Applied when a role writes a <genre> chapter or <specific triggers>. Not applied for <adjacent genres> — they need different genre skills.
---
```

## Section 1 — Identity of the genre

One paragraph: the genre's idea expressed plainly. The reader contract. Who reads this kind of book.

## Section 2 — Chapter structure

Structural skeleton (Pyramid / TED-3-act / Save the Cat / IMRaD / Hero's Journey / something else). Ladder of abstraction (only if the genre is non-fiction). Genre-typical chapter shape.

## Section 3 — Writer behaviour

Genre rules for the writer: SFD, voice calibration, control checkpoints every N chars, formula for explanation/showing/description (depending on genre), micro-context for famous things, term unfolding, self-sufficiency of the text.

## Section 4 — Constitution (NEVER list)

15–25 specific bans. Each is a concrete rule (not "be tasteful" — but "no fictional dialogue between historical figures unless the dialogue is in the source").

## Section 5 — Style and tone

Voice formula. Humanity checklist (semantic). Trigger → action rules.

## Section 6 — Chapter micro-cycle

Numbered procedure of 4–6 steps. Each step is a subagent. Map steps onto the blocks from `blocks-catalog.md` (do not invent new blocks; if a block is missing, write a `proposed-new-blocks.md` note instead).

## Section 7 — Genre parameters

Table of quantitative parameters with defaults and ranges. The seventeen of `popular-science` are a template; not all apply.

## Section 8 — Humanity checklist for a chapter

A 12–17-point checklist applied before submitting `edited.md`. Adapted to genre.

## Footer

```markdown
---

> Connection with other BookBench skills:
> - `base-methodology` — injected in parallel; provides 23 invariants for all genres.
> - `anti-ai-cliche` — corpus of 46 patterns with regex for the post-tool-use hook.
> - `factcheck-protocol` — separate skill for the factchecker.

> Audit / validation: see `<genre>-methodology.audit.md` for gate checks (the seven prompt-engineering anti-patterns plus the Anthropic skills checklist). Not loaded by subagents; only used during skill review.
```

## Hard requirements that the validator enforces

- File ≤ 500 lines.
- `name` ≤ 64 chars; no `anthropic` / `claude`.
- `description` in third person, ≤ 1024 chars.
- References on a single level only.
- No time-sensitive statements (no "as of 2024…").
- All eight sections present and non-empty.
- All cited block names exist in `blocks-catalog.md`.

---

## Notes

- This file is the structural contract. Content variation lives between sections 1–8.
- The audit file `<genre>-methodology.audit.md` is optional and not loaded by subagents.
