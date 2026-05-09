---
name: base-methodology
description: Задаёт жанрово-независимую методологическую базу для любого книжного проекта — двадцать три инварианта работы над длинным текстом, применимых к научпопу, нарративному нон-фикшн, монографиям и художественной прозе. Используется ролями book-writer, book-editor, book-strategist, book-factchecker и book-marketer при написании или ревизии главы, планировании книги или аудите готовой главы. Покрывает принцип «сначала структура», двухуровневую связность, четыре режима редактуры, правило десяти процентов, голос ИИ-автора, сквозную связность между главами, калибровку голоса и каркасную архитектуру plan-section-stitch (AgentWrite). Не заменяет жанровый скилл — тот добавляет количественные параметры и стилистическую специфику поверх этих инвариантов.
---

# Base methodology — twenty-three invariants of long-form writing

This skill supplies the genre-agnostic methodology layer for every BookBench role that produces text or critiques it. It is injected via `skills:` into book-strategist, book-writer, book-factchecker, book-editor, book-marketer (genre methodology layered on top).

## When to use

- Writer drafts a section (Phase 2 of the section micro-cycle).
- Strategist plans a section or the whole book.
- Editor performs developmental, line, copy or proof editing (Phase 4).
- Factchecker verifies factual claims and cohesion of evidence (Phase 3).
- Marketer packages the section (Phase 6).
- Tuner reasons about which guidelines to propose.

## Architecture

Twenty-three invariants are organised into seven groups (T1–T7). Each invariant has a one-line principle plus a one-line "what this means in practice for a subagent". Detailed background — `references/23-invariants.md`.

## Group T1 — structure first

- T1.1 Pyramid principle: each section has one governing thought, supported by 2–6 elements (count is genre-dependent and lives in the genre skill).
- T1.5 Structure is a separate phase before drafting; the section spec.md is its artefact.

## Group T2 — coherence between sections

- T2.1 Adjacent sections need an explicit causal connector (plot connector).
- T2.2 Red-thread keywords appear in every section (≥1) — strategist tracks the registry.
- T2.3 The editor must read neighbouring sections before line edit.
- T2.4 Two levels of cohesion: line-level (cohesion) and structure-level (coherence).

## Group T3 — writing rhythm

- T3.1 Shitty First Draft: the writer finishes the section without polishing; polishing is the editor's job.
- T3.2 Ten-percent rule: between draft and edit the volume drops by roughly ten percent (King).
- T3.3 Four editing mental modes: structural / style / voice / proof.
- T3.4 The author must always have a small next step — never leave them stuck.
- T3.5 The section is split into blocks, not treated as one atom.

## Group T4 — editing

- T4.1 Four editing levels: developmental, line, copy, proof.
- T4.2 Omit needless words — copy edit removes redundancy by checklist.
- T4.3 Hard errors (fix) versus taste preferences (flag with a comment).
- T4.4 Copy editor refers to an external stylebook, not to intuition.

## Group T5 — clarity for non-fiction

- T5.1 Simplicity: remove jargon, qualifiers, inflated phrases.
- T5.2 Curse of knowledge: experts forget what it is to not know — apply the grandmother test.
- T5.5 Ladder of abstraction: every abstract claim is closed with at least one concrete anchor.

## Group T6 — voice and AI-isms

- T6.1 Forty-six anti-AI-cliche patterns are forbidden by default in author text — see `skills/anti-ai-cliche/`.
- T6.2 Voice calibration: the writer reads voice samples from `agent-guidelines/writer/voice-samples.md` at section start; the editor performs a double-pass audit (humanity test) before submission.
- T6.3 The agent is an author, not an assistant — no "I hope this helps", no "Let me know", no "as of my last training".

## Group T7 — collaborative architecture

- T7.1 Plan → sections → stitch (AgentWrite pattern) is the framework architecture for long-form writing.
- T7.3 Multi-role collaborative editing beats a single agent — this is the philosophical core of BookBench.

## Procedure for a writing role at section start

1. Read `.book/agent-guidelines/<role>/README.md` and the files it references.
2. Read `.book/.claude/agent-memory/<role>/MEMORY.md` for active registries.
3. Read `sections/<N>/spec.md` for the structural ToR.
4. Read `.book/context/voice-profile.md`, `parameters.md`, `red-thread-keywords.md`.
5. Read previous section's `summary.md` (only N-1 by default; see `context-control.md`).
6. Apply T6.3 — author voice, not assistant.
7. Apply T3.1 — write the draft to the end before polishing.
8. Apply T5.5 — every abstract claim gets one concrete anchor.
9. Apply T6.2 — every 5000 chars (genre parameter) run a self-check.

## Procedure for an editing role on draft.md

1. Read `sections/<N>/draft.md` and `factcheck.md`.
2. Read neighbouring sections' `summary.md` (T2.3) — N-1 and N+1 if available.
3. Apply T4.1 — the four editing levels in order.
4. Apply T3.2 — aim for a ten-percent reduction.
5. Apply T6.1 — run a double-pass anti-AI-cliche audit (the hook is mechanical; this pass is semantic).
6. Apply T4.3 — distinguish hard errors from taste preferences; the latter become comments.
7. Apply T6.2 — run the humanity test from `skills/anti-ai-cliche/`.

## Tests before submission

A role using this skill is expected to apply the relevant subset of the seven-question humanity test from the `anti-ai-cliche` skill before writing its main artefact. The base methodology skill defines _which subset_ for each role:

- writer: questions 1–5 (voice, anchors, narrative variety, author voice, hesitation marker).
- editor: all seven questions, with extra weight on questions 6 and 7 (signposting, methodology bending).
- strategist: questions 1, 4 (semantic-only — the ToR is not author text but should still read like a human-written brief).
- factchecker: not applicable — uses the factcheck-protocol skill.
- marketer: questions 1, 3, 4 (marketing copy hits the same AI-isms more often).

## Files

- `references/23-invariants.md` — full text of the twenty-three invariants with sources, full one-paragraph explanations and rejected alternatives.

## Evaluation cases (eval-driven development)

The `tests/skills/base-methodology/` directory will hold ≥3 evaluation cases for stage 14:

- Test 1 — writer reads spec.md and produces draft.md that respects T3.1 (no polishing inside the writer phase).
- Test 2 — editor reads draft.md and applies T3.2 (ten-percent reduction within ±5%).
- Test 3 — strategist plans section 8 of a topic-A book and applies T2.1 (explicit plot connector to section 7).

## Notes

- This skill never carries time-sensitive information.
- All numerical parameters live in the genre skill; the base only encodes principles.
- Cross-references to neighbour skills are at depth 1 only (`anti-ai-cliche/`, `voice-profile/`).
