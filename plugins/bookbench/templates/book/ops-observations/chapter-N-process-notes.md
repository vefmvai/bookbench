# Chapter N — process notes (template)

> Template populated by `book-observer` on `/book:analyze-session
> --chapter N`. Replace `N` with the actual chapter number.
>
> **Privacy:** abstract author replies, NEVER quote them verbatim. NEVER
> include text from `chapters/<N>/draft.md` or `edited.md`.

## Session metadata

- chapter: <N>
- session_id: <from rawlog>
- started: <ISO 8601 UTC>
- ended: <ISO 8601 UTC>
- total_tool_calls: <int>
- roles_invoked: [book-coordinator, book-strategist, book-writer, book-factchecker, book-editor, ...]

## Summary

<2-3 sentences abstract description of how the chapter session went, in
abstract terms: "fast / slow / blocked", "many / few revise loops",
"factchecker rejected K assertions", "marketer skipped".>

## Token usage by role

| Role | Calls | Input tokens | Output tokens | Avg duration ms |
|---|---|---|---|---|
| book-coordinator | <N> | <N> | <N> | <N> |
| book-strategist | <N> | <N> | <N> | <N> |
| book-writer | <N> | <N> | <N> | <N> |
| book-factchecker | <N> | <N> | <N> | <N> |
| book-editor | <N> | <N> | <N> | <N> |
| ... | | | | |

## Process signals (NO content quotes)

### Friction event A
- timestamp: <ISO 8601>
- pattern: <abstract; e.g., "factchecker invoked twice on same set">
- impact: <short>
- proposed_fix_local: <if any>
- proposed_fix_global: <link to upgrade-candidate id, if promoted>

### Friction event B
- ...

## Revise loops

| Step | Iterations | Reason category |
|---|---|---|
| writer→editor | <N> | <voice / structure / style / cliche> |
| writer→factchecker | <N> | <fact / source / year> |

## Cross-chapter memory misses (if any)

> The observer flags here every author reply that essentially asks
> "look at chapter X again" — meaning the registry didn't surface what
> was needed. Each entry feeds `upgrade-candidates.md` under
> `memory-gaps`.

- <abstract description of the miss>
- <abstract description of the miss>

## Recommendations for next chapter (local, not BookBench-level)

> Suggestions about THIS book's local guidelines / registries. NOT about
> the plugin. Plugin-level suggestions go to `upgrade-candidates.md`.

- <e.g., "add character X's introduction date to intel/timeline.md to
  prevent repeated questions">
- <e.g., "extend writer/forbidden-phrases.md with pattern observed
  three times this chapter">
