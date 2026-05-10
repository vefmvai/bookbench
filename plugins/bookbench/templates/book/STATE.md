# Book state

> Append-only journal of the book. Every command appends an entry. Coordinator reads the tail at cold start.

## Current

- `current_section`: book_level
- `current_section`: null
- `last_action`: book initialised
- `bookbench_version`: TBD                 # filled by /bookbench:start; immutable for diagnostics
- `created_at`: TBD                        # ISO 8601, set once by /bookbench:start
- `last_touched_at`: TBD                   # ISO 8601, updated on each STATE-mutating command

## History

```
TIMESTAMP — `/bookbench:start` — initialised book in this directory
```

(Each subsequent action appends a line below.)

