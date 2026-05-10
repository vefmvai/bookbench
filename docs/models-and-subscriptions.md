# Models and subscriptions

> Which Claude model runs which subagent, why the defaults look the way they do, and how to adapt them to your subscription plan.

## Why this matters

Every BookBench section walks through a chain of subagents (strategist → writer → factchecker → editor → marketer, plus the orchestrating coordinator and three import/maintenance roles). If every Task in that chain inherits the model from the main thread, you spend Opus on roles whose work does not need Opus — and a single section eats your daily Opus quota on the Claude Pro plan after one or two passes.

BookBench solves this by pinning each subagent to a specific model tier and exposing three named profiles you can switch between with one line in `.book/config.yaml`.

## How model choice works

Model selection cascades from the plugin defaults to per-role overrides in your book:

```
${CLAUDE_PLUGIN_ROOT}/defaults.yaml.profiles.<profile>.<role>
   ↓  (selected by)
.book/config.yaml.agents.profile          # budget | balanced | quality
   ↓  (then optionally overridden by)
.book/config.yaml.agents.model_overrides.<role>
```

The agent body files themselves (`.book/.claude/agents/<role>.md`) carry a baseline `model: <alias>` line that mirrors the `balanced` profile. Profiles and `model_overrides` win over that baseline at runtime through the standard Claude Code subagent configuration.

A per-section model override (in `sections/<N>/spec.md`) is intentionally **not** supported — section-by-section swapping adds complexity without a measurable quality gain (see decisions document for this stage).

## The nine roles and their default model

| Role | Why this tier | Baseline (balanced) |
|---|---|---|
| `book-strategist` | Designs section spec, picks supports and anchors. Creative core. | **opus** |
| `book-writer` | Produces the section draft. Creative core; the output the reader sees. | **opus** |
| `book-marketer` | Generates Twitter / Telegram / image-prompt copy with brand voice. Creative core. | **opus** |
| `book-coordinator` | Orchestrates files between roles, runs procedures, no creative writing. | sonnet |
| `book-editor` | Compresses, polishes, runs anti-cliché audit. Verify / compact, not invent. | sonnet |
| `book-factchecker` | Verifies claims against sources. Needs nuance to spot subtle errors. | sonnet |
| `book-tuner` | Reads TUNING-LOG, proposes guideline patches. Analytical, not creative. | sonnet |
| `book-doc-synthesizer` | Composes import materials into structured intel. | sonnet |
| `book-doc-classifier` | Tags incoming files into 11 deterministic classes. Trivial. | haiku |

The three creative-core roles (strategist / writer / marketer) stay on **Opus in every profile** — that is a hard architectural rule, not a tunable. The classifier stays on **Haiku in every profile** for the symmetric reason: promoting it would burn tokens on a deterministic task.

## The three profiles

### Profile matrix

| Role | budget | balanced (default) | quality |
|---|---|---|---|
| coordinator | haiku | sonnet | sonnet |
| strategist | **opus** | **opus** | **opus** |
| writer | **opus** | **opus** | **opus** |
| factchecker | sonnet | sonnet | sonnet |
| editor | haiku | sonnet | sonnet |
| marketer | **opus** | **opus** | **opus** |
| classifier | haiku | haiku | haiku |
| synthesizer | haiku | sonnet | **opus** |
| tuner | haiku | sonnet | sonnet |

### What each profile is for

- **`budget`** — fits a section cycle into a constrained daily Opus quota. The creative core stays on Opus because that is what the reader sees; everything else drops to Haiku. The factchecker is the one exception inside the verify cluster — fact verification rewards more nuance than Haiku reliably delivers, and a missed fact costs more than a saved token.
- **`balanced`** — recommended default. Mirrors the baseline shipped with the agent bodies. Verify / compose / orchestrate roles run on Sonnet; only the deterministic classifier stays on Haiku.
- **`quality`** — promotes the synthesizer to Opus because import composition is upstream of every later phase: a sloppy synthesis derails the writer, the editor, and the marketer all at once. Other Sonnet-tier roles stay on Sonnet — empirically the gain from upgrading verify roles to Opus does not justify the cost.

## Picking a profile by subscription plan

| Subscription | Recommended profile | Notes |
|---|---|---|
| Claude Pro ($20/mo) | `budget` | The three creative-core roles still consume Opus on every section. Expect 1–2 sections per Opus reset; pace yourself or pre-batch strategist + writer when fresh. |
| Claude Max-5x | `balanced` | Comfortable single-author throughput. The default profile is tuned for this plan. |
| Claude Max-20x | `quality` | Headroom is no longer the bottleneck. Promote the synthesizer for cleaner imports. |
| API access (your own key) | `quality` or hand-tuned | Cost is itemised per call; consider per-role overrides (see below) once you have telemetry data. |

These are starting points, not commandments. If you write short sections or short books, `balanced` is fine on Pro. If you write a long-form import-heavy book on Max-5x, you may want `quality` for the synthesizer alone — that is what `model_overrides` is for.

## How to override manually

Edit `.book/config.yaml`:

```yaml
agents:
  profile: balanced

  model_overrides:
    writer: opus            # force Opus on the writer regardless of profile
    factchecker: haiku      # cheap mode for a fast first-pass draft
```

Two common patterns:

1. **Cheap pass for low-stakes sections.** Set `profile: budget` and add `model_overrides: { factchecker: haiku }` if you want a fast, rough first draft. Switch back to `balanced` for the final pass.
2. **Quality boost where it matters.** Stay on `balanced` and add `model_overrides: { synthesizer: opus }` when importing a large pile of source material before the first section.

After editing `model_overrides`, the change takes effect on the next subagent invocation — no restart required.

## Cost and limits

A naive `model: inherit` policy makes every Task adopt the model the user picked for the main thread. On Claude Pro that means **every subagent invocation runs on Opus**, since users typically run the main thread on Opus for the orchestration quality. A single section cycle can then exhaust the daily Opus quota in two or three runs, which makes the framework unusable on the Pro plan.

The profile system fixes this by spending Opus only where it is structurally required (the three creative-core roles) and pushing everything else down the model ladder. The savings compound over a book: an editor pass on Sonnet costs roughly a fifth of the same pass on Opus; on Haiku, less still. With the `budget` profile on Pro, an entire section cycle typically fits inside the Opus budget that a single naive Opus inheritance would consume.

If you want hard numbers for your own setup, the telemetry hooks shipped with the plugin write per-role model usage to `.book/ops-observations/rawlog.jsonl`. Run `/bookbench:analyze-session` after a few sections to see where your Opus minutes actually go.

## Migrating an old book

If your book was initialised before this plugin version, your `.book/config.yaml > agents.models` map probably still has `inherit` for every role. Two ways to upgrade:

1. **Manual.** Open `.book/config.yaml`, set `agents.profile: balanced`, and clear the legacy `agents.models` block (or replace each `inherit` with the value from the matrix above).
2. **Via `/bookbench:update`.** Running `/bookbench:update` proposes a 3-way merge that adds the `profile` and `model_overrides` keys without touching your guidelines.

Either way, your guidelines, memory registries, and section content remain untouched — only the model selection metadata changes.

## Further reading

- `docs/architecture.md` — the two-tier plugin / book architecture
- `docs/customization.md` — guidelines and tuning
- `docs/upgrade-guide.md` — full `/bookbench:update` flow

---
*Last reviewed against the model alias system shipped in plugin version 0.1.*
