---
name: factcheck-protocol
description: Описывает adversarial-протокол факт-чекинга для агента book-factchecker — теги происхождения утверждений (VERIFIED, CITED, ASSUMED, UNVERIFIABLE), политику доверенных источников, процедуру извлечения утверждений из главы, handshake цикла ревизий с book-writer (до трёх итераций), обнаружение противоречий между главами и пометку устаревших источников. Используется book-factchecker на фазе 3 микро-цикла и при повторных проверках фрагментов на фазе 4b. Включает принцип adversarial-позиции — каждое утверждение считается непроверенным, пока не сопоставлено с доверенным источником.
---

# Factcheck protocol skill

## When to use

Injected into `book-factchecker`. Activated in Phase 3 (full section factcheck after writer) and Phase 4b (one-shot re-check of editor-flagged `[NEEDS_RECHECK]` blocks). Also invoked during `/bookbench:audit-section` and `/bookbench:audit-book` in audit-mode (no revise-loop).

## Core principle — adversarial stance

A fact is **unverified** until matched against at least one trusted source. The factchecker writes from this presumption. Trusted sources live in `.book/agent-guidelines/factchecker/trusted-sources.md` (defaults from `defaults.yaml.genres.<genre>.guidelines.factchecker.trusted-sources`).

This stance is inherited from `gsd-verifier` (etap 04) but **without** mentor-mode (DEC-06). The factchecker writes laconic technical reports, not lectures.

## Claim provenance tags

Every factual claim in a section receives one of four tags in `factcheck.md`:

| Tag | Meaning | Behaviour |
|-----|---------|-----------|
| `VERIFIED` | Confirmed against ≥1 trusted source. | Cited inline in factcheck.md with source URL/DOI/ISBN. |
| `CITED` | Already cited in draft.md but the cite needs to be passed through. | Verify the cite is real and accurate. |
| `ASSUMED` | Plausible but unverifiable; author asserts it. | Requires hedging in draft.md ("by some accounts", "in one telling") OR explicit author confirmation via `/bookbench:resolve` style flow. |
| `UNVERIFIABLE` | Cannot be confirmed nor denied with available sources. | Return `revise-required` to writer with three options: hedge, drop, or supply manual source. |

## Claim extraction procedure

1. Read `sections/<N>/draft.md` end-to-end.
2. Tag every sentence containing a factual claim with `[CLAIM]` mentally.
3. Categorise each claim:
   - Hard fact (date, number, name, event) → must be VERIFIED.
   - Citation (quote attributed to someone) → must be CITED.
   - Soft claim ("most experts agree", "it is widely held") → must be VERIFIED with citation OR rewritten as ASSUMED with hedging.
   - Cross-section claim ("as we saw in section 3") → check against `sections/<3>/edited.md` for inconsistency.
4. For each claim, attempt verification using:
   - Trusted sources from `agent-guidelines/factchecker/trusted-sources.md`.
   - WebSearch or WebFetch with explicit query.
   - Optional MCP servers (Tavily, Exa, Perplexity) per book config.
5. Write findings into `factcheck.md` with the four tags.

## Revise-loop handshake

After producing `factcheck.md`, set `status:` in the frontmatter:

- `pass` — every hard claim is VERIFIED or CITED, every soft claim hedged.
- `revise-required` — at least one claim is UNVERIFIABLE without acceptable hedging or drop suggestion.
- `escalate` — even after writer revisions, ≥1 hard claim remains unverifiable.

The coordinator drives the loop; the factchecker only writes the report.

Loop cap: `factcheck.max_iterations` (default 3, from DEC-03). On iteration 4 the coordinator triggers ESCALATE-flow with REJECTIONS-LOG entry.

## Cross-section inconsistency detection

Maintain `factchecker/MEMORY.md` registries:

- `verified_sources` — list of (claim, source, section) tuples. Used to check if the same fact is cited consistently across sections.
- `outdated_sources` — sources that worked once but should not be re-used (e.g., a study from 2008 superseded by a 2020 meta-analysis).
- `cross_section_inconsistencies` — pairs of sections where the same fact is stated differently.

Read this registry at the start of every Phase 3 invocation; flag any new inconsistency in `factcheck.md`.

## Skill modes (used by editor)

The editor occasionally activates `consistency-check` or other skill-modes. The factchecker is _not_ involved in those — they are editor's own skill modes. The factchecker only participates in Phase 3 and Phase 4b.

## Tests

- Test 1 — given a draft.md with a soft claim and no citation, factcheck.md returns `revise-required` and proposes hedging.
- Test 2 — given a draft.md with a verifiable hard fact and a real source URL, factcheck.md tags it `VERIFIED` and proceeds.
- Test 3 — given a draft.md with a fact that contradicts a previously-verified fact in section 3 (per `factchecker/MEMORY.md`), factcheck.md flags `cross_section_inconsistency` and proposes resolution.

## Files

This skill has no extra reference files. Trusted-sources policy lives in the book folder.

## Notes

- No time-sensitive content in this skill. Trusted-source lists for specific topics live in `agent-guidelines/factchecker/trusted-sources.md` (not here).
- Tests reference generic placeholders.
