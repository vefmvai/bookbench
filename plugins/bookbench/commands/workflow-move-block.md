---
name: workflow:move-block
description: Reorders a block inside its workflow section (or moves it to a different section). Stub for the 0.2+ release. In 0.1 use /bookbench:workflow:edit and reorder the YAML lines manually; auto-validation runs on save.
argument-hint: "<block-name> [--to <position>] [--to-section <name>]"
allowed-tools: [Read]
---

# /bookbench:workflow:move-block

<purpose>
Atomic move operation on `workflow.md`. Not implemented in 0.1 — use `/bookbench:workflow:edit` instead.
</purpose>

<!-- ЭТАП 14: stub for 0.2+ -->

<execution>

This command is **not implemented in the 0.1 release**.

For now, to move a block in `.book/workflow.md`:

1. Run `/bookbench:workflow:edit` to open the file in `$EDITOR`.
2. Cut the `- block: <name>` block (with its `params:` and `requires:` lines).
3. Paste it at the new position.
4. Save and close. `/bookbench:workflow:check` runs automatically. If `requires:` references are now in the wrong order, you will see HIGH issues — fix or revert.

</execution>
