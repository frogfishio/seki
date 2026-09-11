# ADR 0017: Fixed arrays are the only v0 collection value

- Status: accepted for bootstrap; not a language freeze
- Date: 2026-09-11

## Decision

Seki v0 has `Array[T, N]` as its only collection value. The provisional
`BoundedVec[T, N]` type and its vector-specific operations are removed from the
v0 language and typed core.

An array's length is part of its static type. V0 therefore has no collection
with a separately stored runtime length, no capacity-versus-length invariant,
and no inactive element slots. Traversal intrinsics may operate over arrays, but
they do not establish a general collection protocol.

Where an interface needs up to `N` independently optional inputs, it may use
`Array[Option[T], N]`. This is not defined to be a packed sequence: every slot is
an ordinary, observable `Option[T]`. A later version may add a bounded sequence
only after a concrete customer case establishes that arrays and explicit sum
types are inadequate.

## Consequences

The value, equality, canonical-encoding, resource, and C-representation proofs
do not need rules for a runtime collection length or semantically inactive
storage. Unchecked indexing remains absent.

`VecLength`, `VecGet`, and `FilterBounded` leave the v0 typed core. Array access
and bounded array traversal remain candidates. `MapBounded` becomes an
array-only operation and should be renamed during the schema cleanup so its name
does not imply a general collection abstraction.

The candidate-selection fixture must model its bounded input with fixed slots,
most likely `Array[Option[Candidate], 32]`, and define the treatment of absent
slots explicitly. Existing SCB-0 tags and fixtures that mention bounded vectors
are provisional and will be regenerated; no compatibility is promised before
the F1-B encoding freeze.
