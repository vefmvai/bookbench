---
name: workflow:remove-block
description: Removes a block from .book/workflow.md with safety checks (no orphan dependencies). Stub for the 0.2+ release. In 0.1 use /book:workflow:edit and delete the block manually; auto-validation runs on save.
argument-hint: "<block-name>"
allowed-tools: [Read]
---

# /book:workflow:remove-block

<purpose>
Atomic remove operation on `workflow.md`. Not implemented in 0.1 — use `/book:workflow:edit` instead.
</purpose>

<!-- ЭТАП 14: stub for 0.2+ -->

<execution>

This command is **not implemented in the 0.1 release**.

For now, to remove a block from `.book/workflow.md`:

1. Run `/book:workflow:edit` to open the file in `$EDITOR`.
2. Locate the `- block: <name>` line and delete the whole block (including its `params:` and `requires:` sub-keys).
3. Save and close. `/book:workflow:check` runs automatically. If other blocks depended on the removed one, you will see CRITICAL issues — fix them or revert.

</execution>
