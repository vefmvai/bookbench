# Invariants vs variables — the contract

This file is the authoritative contract between the genre-agnostic base methodology skill (`skills/base-methodology/`) and the on-demand genre researcher (`skills/genre-researcher/`).

It tells the researcher exactly which slots to fill and which slots to leave alone (because they are already covered by `base-methodology`).

## 23 invariants — already covered

The 23 invariants belong to the base methodology and are imported into every writing role automatically. The genre researcher must NOT regenerate them. Full text — `skills/base-methodology/references/23-invariants.md`.

## 8 variables — the researcher must fill

(See `skills/base-methodology/references/23-invariants.md` § 2.)

| # | Variable | Default for popular-science |
|---|----------|------------------------------|
| 1 | Structural template | TED-3-act + Pyramid |
| 2 | Feynman procedure applicability | yes (full) |
| 3 | Narrative non-fiction arcs applicability | partial (bridges between expositional and narrative passages) |
| 4 | Stylebook reference | language-specific (Rosenthal/Milchin for Russian; Chicago for English) |
| 5 | Quantitative parameters of writing | see §7 of `popular-science/SKILL.md` |
| 6 | Genre-specific anti-patterns | the 12 Russian-specific patterns (#35–46) |
| 7 | Voice calibration field | informal-conversational (with measured emotional intensity) |
| 8 | Critical-reading skill set | popular-science-methodology + anti-cliche-check |

## 5 mixed parameters — the researcher must fill

(See `skills/base-methodology/references/23-invariants.md` § 3.)

| # | Parameter | Principle (invariant) | Genre-specific value (popular-science default) |
|---|-----------|------------------------|--------------------------------------------------|
| 1 | Pyramid supports per chapter | top-down structure | 3–4 |
| 2 | SUCCESs proportion | every key idea uses ≥2 attributes from SUCCESs | emotional + concrete dominant |
| 3 | Anchor density per abstract claim | every abstract claim has ≥1 concrete anchor | 2–4 |
| 4 | LongBench-Write critical weights | quality is multi-axis | length 0.3, coherence 0.3, clarity 0.4 |
| 5 | Voice profile fields | calibration via voice samples | the six-parameter model in `voice-profile/SKILL.md` |

## What the researcher does NOT regenerate

- The 23 invariants in any form. They live in the base.
- The 46 anti-AI-cliche patterns. They live in `skills/anti-ai-cliche/`.
- The chapter micro-cycle structure. It lives in `chapter-loop` block (block 31 in `blocks-catalog.md`).
- The two-tier architecture (plugin code vs book folder). It lives in the plugin docs.

## How the contract is enforced

Each generated `<genre>-methodology.md` is checked against this file by gate G3 of the validation pipeline (see `genre-researcher/SKILL.md`). If any of the 8 variables or 5 mixed parameters is `TBD`, the gate fails and the researcher reruns.

---

## Notes

- This file is read by the researcher at every invocation. It is also referenced by the seven validation gates.
- It is intentionally short — the bulk of context lives in `skills/base-methodology/references/23-invariants.md`.
- No time-sensitive content; defaults are stable.
