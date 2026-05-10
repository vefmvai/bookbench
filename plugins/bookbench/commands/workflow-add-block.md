---
name: workflow:add-block
description: Adds a single block to .book/workflow.md with validation. Stub for the 0.2+ release. In 0.1 use /bookbench:workflow:edit to open the file in $EDITOR and add the block by hand; auto-validation runs on save.
argument-hint: "<block-name> [--section <name>] [--at <position>]"
allowed-tools: [Read]
---

# /bookbench:workflow:add-block

<purpose>
Atomic add operation on `workflow.md`. Not implemented in 0.1 — use `/bookbench:workflow:edit` instead.
</purpose>

<!-- ЭТАП 14: stub for 0.2+ -->

<execution>

This command is **not implemented in the 0.1 release**.

For now, to add a block to `.book/workflow.md`:

1. Run `/bookbench:workflow:edit` to open the file in `$EDITOR`.
2. Insert a new block in the right section (`book_level`, `section_loop`, `cross_cutting`, or `post_book`):
   ```yaml
   - block: <block-name>
     params:
       <key>: <value>
     requires: [<other-block>]   # optional
   ```
3. Save and close. `/bookbench:workflow:check` runs automatically and flags issues.

See `${CLAUDE_PLUGIN_ROOT}/blocks-catalog.md` for valid block names and parameters.

</execution>
