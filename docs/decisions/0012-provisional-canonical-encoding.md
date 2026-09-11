# ADR 0012: Provisional canonical encoding direction

- Status: accepted for bootstrap; byte freeze pending
- Date: 2026-09-11

## Decision

Seki will develop a purpose-built positional binary encoding, SCB-0, for
canonical typed-core modules and closed admission bundles. The format is designed
around the closed Seki schema rather than a generic object model.

The generated `seki.lock` will instead use a small canonical JSON profile for
human inspection and ordinary tooling. The lockfile is outside the trusted
semantic boundary: admission receives the actual binary bundle, recomputes every
module digest, and does not trust or parse the lockfile.

## Initial SCB-0 constraints

- one versioned envelope and one positional schema per record;
- fixed-width big-endian unsigned counts, indices, and bounds, provisionally
  `u32`;
- `u8` discriminants with unknown values rejected;
- exact-width big-endian integer values, with signed values in two's complement;
- bytes and ASCII identifiers prefixed by their exact `u32` length;
- tables serialized in their already-defined strict canonical order;
- definite lengths only, with no padding or trailing bytes; and
- no maps, floats, nulls, generic tags, implicit defaults, or extension fields.

These constraints are provisional until the schema and vector freeze. In
particular, this ADR does not assign discriminant values, envelope bytes,
admission-reason numbers, or a final derivation-witness representation.

## Consequences

The trusted decoder can be a bounded forward cursor over a closed schema. It does
not need Unicode canonicalization, object-member lookup, arbitrary numeric
decoding, generic tag handling, or shortest-form varint logic. A separate
untrusted inspector can render SCB-0 as readable text or JSON.

Schema evolution is intentionally strict: a new incompatible schema version is
preferable to optional fields or permissive decoding in the authority format.

The lockfile remains reproducible and reviewable while digest authority remains
with the canonical module bytes. Humans edit exact module versions and aliases;
tooling writes digests.

