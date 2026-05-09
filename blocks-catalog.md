# Blocks catalogue

> The atomic blocks of the BookBench workflow. The catalogue holds 30 atomic blocks defined in stage 7.1 plus the procedure-block `chapter-loop` defined in stage 11. Total: 31 blocks.
>
> Each block is described by a YAML frontmatter (kind, executor, inputs, outputs, requires, params) and a markdown body (when used, when not, alternatives, common errors, example).
>
> This file is the single source of truth for `workflow.md` block names. The genre researcher's preset validation (gate G4) checks that every block name in any preset YAML resolves to a block defined here.

## Index of 31 blocks

The first 30 blocks are defined in stage 7.1 of the BookBench design (`blocks-catalog.md` of stage 7.1) and are inherited unchanged. Stage 12 adds block 31, `chapter-loop`.

Stage 12 status: this file currently lists only block 31 in full detail. Blocks 1–30 will be inlined here in stage 13 (or this file may be replaced with a single canonical document). For now, the design source is `.bpd/stages/07-1-katalog-blokov/blocks-catalog.md` of the BookBench framework project.

| # | Name | Category | Kind | Executor |
|---|------|----------|------|----------|
| 1 | setup-interview | onboarding | atomic | book-coordinator |
| 2 | book-plan | book_level | atomic | book-strategist |
| ... | (blocks 3–30) | (various) | (various) | (various) |
| 31 | chapter-loop | writing | procedure | book-coordinator |

## Block 31 — chapter-loop

> Macro-block that wraps all phases of one chapter into a single procedure. Coordinator-owned (`internal_logic_owner: book-coordinator`).

### YAML definition

```yaml
---
name: chapter-loop
version: "0.1.0"
category: writing
kind: procedure
executor: book-coordinator
required_skill: null
inputs:
  - chapters/<N>/chapter-state.yaml
  - workflow.md
  - context/parameters.md
outputs:
  - chapters/<N>/spec.md
  - chapters/<N>/draft.md
  - chapters/<N>/factcheck.md
  - chapters/<N>/edited.md
  - chapters/<N>/marketing.md
  - chapters/<N>/summary.md
  - chapters/<N>/reviews/*.md
  - chapters/<N>/chapter-state.yaml
requires:
  requires_artifact: chapters/<N>/chapter-state.yaml
  requires_block_done: setup-chapter
  requires_block_done_in_scope: chapter
params:
  enable_marketer:
    type: bool
    default: true
    description: Includes Phase 6 (Marketer) after the editor.
  enable_skill_reviews:
    type: array<string>
    default: []
    description: Editor skill modes to run sequentially (philosophical-review, sensitivity-review, consistency-check, anti-cliche-deep, ethical-review, cultural-translation-review).
  factcheck_max_iterations:
    type: int
    default: 3
    range: [1, 5]
    description: Maximum factcheck-loop iterations before ESCALATE-flow.
  gates:
    type: array<string>
    default: [spec, approval]
    values: [spec, draft, factcheck, edit, market, approval]
    description: Author gates between phases.
  imported_writer_mode_default:
    type: enum
    default: skip
    values: [skip, voice-revise, full-rewrite]
    description: Default writer mode for an imported chapter (Phase 0g).
  override_quantitative_allowed:
    type: bool
    default: true
    description: Allows spec.md override_quantitative to override config.yaml.
  consistency_check_on_skip:
    type: bool
    default: true
    description: Force consistency-check skill mode for skip-imported chapters.
  on_completed:
    type: enum
    default: ask
    values: [ask, re-write, re-edit, abort]
    description: Behaviour when /book:write-chapter is invoked for a chapter that already has chapter-state.yaml.completed = true. Closes OQ-19. Aligned with commands/write-chapter.md frontmatter.
import_behavior: prompt-user
internal_logic_owner: book-coordinator
---
```

### When used

Every time the author runs `/book:write-chapter <N>` or `/book:next --execute` and the next recommended action is a chapter loop. The block contains all five core phases (strategist → writer → factchecker → editor → optional marketer) plus coordinator finalisation.

### When NOT used

When the author wants to intervene between phases via the atomic subcommands `/book:write-chapter:draft|factcheck|edit|market <N>`. The coordinator then dispatches to a single phase procedure rather than the loop.

Also not used for book-level phases (`setup-interview`, `book-plan`, `ship`) and cross-cutting blocks (`audit-book`, `doctor`).

### Alternatives

- **Atomic blocks in `workflow.md`**: list the five phases explicitly. Pro: transparent to the reader of `workflow.md`. Con: parameters scatter; genre presets harder to override; `workflow.md` grows.
- **Coordinator-internal loop without catalogue entry**: the loop lives only in the coordinator's system prompt. Pro: simpler. Con: `workflow.md` cannot configure it; no place for genre presets; violates WF-02 (every macro-process is a catalogue block).

### Common errors

1. Invoking `/book:write-chapter <N>` before `chapter-state.yaml` exists. The block requires the state created by `setup-chapter`.
2. Overriding `factcheck_max_iterations` to 1 (loses DEC-03 guarantees) or to 5 (token cost grows linearly).
3. Enabling all five `enable_skill_reviews` at once. Each adds a separate editor invocation; cost grows linearly. Recommendation: 1–2 modes per chapter.
4. Setting `gates: []` for a working book — removes both author gates; not recommended.

### Example use in `workflow.md`

```yaml
# Default for popular-science (5-phase pipeline, marketer on)
chapter_loop:
  block: chapter-loop
  params:
    enable_marketer: true
    enable_skill_reviews: []
    factcheck_max_iterations: 3
    gates: [spec, approval]
    on_completed: ask

# For an academic monograph
chapter_loop:
  block: chapter-loop
  params:
    enable_marketer: false
    enable_skill_reviews: [ethical-review]
    factcheck_max_iterations: 5
    gates: [spec, draft, edit, approval]
    on_completed: ask
```

### Closing OQ-19

The `on_completed` parameter closes the open question OQ-19 from stage 11. When the author invokes `/book:write-chapter <N>` for a chapter whose `chapter-state.yaml.completed` is `true`, behaviour follows `on_completed`:

| Value | Behaviour |
|-------|-----------|
| `ask` (default) | Coordinator presents an `AskUserQuestion`: re-write, re-edit, abort. |
| `re-write` | Backs up `edited.md` to `<artifact>-prev-<ts>.md` and re-runs the full pipeline. |
| `re-edit` | Re-runs Phase 4 (Editor) only, equivalent to `/book:write-chapter:edit <N>`. |
| `abort` | Exits with a notice; no changes made. |

This parameter mirrors the `on_completed` field in `commands/write-chapter.md` frontmatter; the two must stay in sync.

---

*Stage 12: this file is the catalogue scaffold. Blocks 1–30 are inlined in stage 13 (or this file is rebased over the source-of-truth in stage 7.1 of the BookBench framework project).*
