# ADR 0007: Typed-core v0 draft structure

- Status: accepted for bootstrap; not a language freeze
- Date: 2026-09-11

## Decision

The v0.2 typed-core draft uses one canonical, typed, name-independent expression
model with these structural rules:

- public declarations live in uniquely keyed canonical tables;
- cross-module references bind exact module identities and digests;
- locals use zero-based de Bruijn indices with one payload binder per match arm;
- declared variants and intrinsic `Option`, `Result`, `Decision`, and
  `ArithmeticError` constructors share one exhaustive-match reference model;
- every arithmetic node carries its effective policy;
- every kernel rejection site carries an index into one complete declared
  rejection order;
- resource claims are semantic steps, live-value bits, evaluator-control depth,
  and abstract workspace bits rather than premature C byte-layout claims; and
- module exports, theorem requirements, claim ceiling, and intended publication
  eligibility are explicit semantic data.

Variant record payloads have an internal `VariantPayload(case)` type so one
payload binder can be typed and projected without inventing anonymous surface
types. Whether an arm binds is determined by its constructor, not by an
untrusted Boolean in the proposed core.

As required by the governing v0.3 seed, canonical derivations remain within the
typed-core digest. Their unique normal form must be specified before the encoding
can freeze.

## Consequences

The surface grammar remains an elaboration language rather than an authority
root. It may use readable names, inherited arithmetic defaults, and omitted
function bounds only where elaboration produces the fully explicit core form.

This decision resolves the initial structural review findings but does not
authorize F1 implementation, select a wire encoding, or claim any proof.
