# ADR 0004: Zing-derived surface syntax

- Status: accepted for bootstrap drafting; concrete grammar not frozen
- Date: 2026-09-11

## Decision

Seki's surface syntax will use the contributed Zing specification as lineage
and a design accelerator. Seki owns its resulting syntax and semantics; no Zing
document is normative for Seki.

The draft adopts period terminators, bracket bodies, keyword selectors, unary
field-like projection, uppercase type names, lowercase value names, record
literals, and deterministic receiver-first evaluation. It adapts function heads
to require types and bounds.

The visible distance from C is intentional. Generated C is a backend artifact,
not the source language's semantic model. A C-like surface would invite readers
to import incorrect expectations about pointer access, mutation, integer
promotion, overflow, evaluation order, looping, allocation, and undefined
behavior. Zing's message-oriented syntax makes an Seki module immediately
recognizable as a different language with a different contract.

Seki rejects Zing's mutable assignment, non-local `ret`, general loops, dynamic
dispatch, foreign operations, flat binary precedence, escaping closures, and
unbounded integer families. These would either contradict the v0.3 charter or
add proof surface without serving bounded decision kernels.

## Consequences

An existing Zing lexer or parser may be adapted as an untrusted frontend, but
its accepted parse is never semantic authority. It must emit typed-core data and
complete derivation witnesses for reopening by the verified admission checker.

The initial conclusions and rejected inheritances are recorded in
`docs/lineage/ZING_SURFACE_ASSESSMENT.md`. The working surface proposal and
candidate grammar live under `spec/language/`.

Surface familiarity must therefore be judged within Seki and its Zing lineage,
not by resemblance to the generated C. The compiler may print straightforward
C11, but no source construct gains C semantics merely because it lowers to C.
