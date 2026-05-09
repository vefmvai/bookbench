# Ingest decisions

> Created during `/book:import`. Three buckets: auto-resolved, competing-variants (await `/book:resolve`), rejected. Append-only audit trail.

## Auto-resolved

(Populated by book-doc-synthesizer; high-confidence fragments without conflict.)

## Competing-variants

(Populated by book-doc-synthesizer; conflicts that need `/book:resolve <variant-id>`.)

## Rejected

(Populated by book-doc-synthesizer; low-confidence or out-of-scope fragments.)
