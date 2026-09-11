# ADR 0013: Canonical derivations by reconstruction

- Status: accepted for bootstrap; proof and byte freeze pending
- Date: 2026-09-11

## Decision

Seki v0 represents static derivations by canonical reconstruction rather than a
producer-chosen proof tree. The canonical AST already supplies rule choices,
premises, claimed expression types, imports, rejection indices, and final exact
bounds. Admission deterministically reconstructs every typing, totality, import,
bound, and precedence judgment and rejects any mismatched conclusion.

The explicit `DerivationBundle` contains only the unique lexicographically least
topological orders of local type declarations and local pure functions. Those
orders are constructive acyclicity witnesses and establish one replay schedule.
No inference-rule tags, premise indices, copied environments, intermediate cost
tuples, or bundle-context-dependent import order are serialized.

## Rationale

The v0 relations are deliberately syntax-directed. A general proof-object
language would duplicate the typed core, create multiple encodings of the same
derivation, enlarge the verified decoder, and introduce normalization questions
without increasing what admission can establish.

The selected form still satisfies the governing requirement that derivations be
digest-bound: the annotations and exact conclusions used for reconstruction, and
the two explicit dependency schedules, are all canonical module fields.

## Consequences

Admission does more deterministic recomputation and consumes fewer untrusted
witness bytes. An elaborator cannot choose a favorable proof path because there
is no proof-path choice. Any future relation that ceases to be functional must
introduce a new schema version and one separately specified witness normal form.

This static module certificate is not SSDC-1. SSDC-1 remains the later canonical
per-invocation semantic derivation shared by Lean and Rocq.

