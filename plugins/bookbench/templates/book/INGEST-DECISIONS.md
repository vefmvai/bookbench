# Ingest decisions

> Created during `/bookbench:import`. Three buckets: auto-resolved, competing-variants (await `/bookbench:resolve`), rejected. Append-only audit trail.

## Auto-resolved

(Populated by book-doc-synthesizer; high-confidence fragments without conflict.)

## Competing-variants

(Populated by book-doc-synthesizer; conflicts that need `/bookbench:resolve <variant-id>`.)

## Rejected

(Populated by book-doc-synthesizer; low-confidence or out-of-scope fragments.)
