# Canonical encoding comparison v0

- Date: 2026-09-11
- Scope: authority-bearing typed-core and bundle bytes
- Disposition: purpose-built positional binary selected provisionally
- Authority: design direction only; no byte-level freeze or implementation claim

## Requirements

The authority format must have one byte representation for every admitted value,
reject every alternate representation, support bounded single-pass decoding, bind
schema and semantic-profile identity, and keep the future verified decoder small.
Human readability is useful, but it is not worth adding a general data-model parser
to the trusted boundary.

## Comparison

| Candidate | Advantages | Trusted-boundary cost | Disposition |
| --- | --- | --- | --- |
| Purpose-built positional binary | Fixed schema, no field names or maps, fixed-width bounds, small forward decoder | New format and dedicated inspection tools | Selected provisionally |
| Strict canonical JSON | Readable, ubiquitous tooling, standardized canonicalization | Strings, escapes, Unicode, duplicate members, property ordering, and a number model unsuitable for all Seki integers without extra conventions | Reject for authority bytes |
| Deterministic CBOR subset | Compact, standardized binary representation | Generic major types, preferred encodings, map ordering, tags, and rejected alternate forms remain unnecessary proof surface | Reject for authority bytes |

[RFC 8785](https://www.rfc-editor.org/rfc/rfc8785.html) gives canonical JSON a
precise interoperable form, but it inherits the I-JSON string and number model and
sorts object properties by UTF-16 code units. Seki identifiers are ASCII and Seki
integers have explicit widths through `U64` and `I64`; carrying JSON's wider model
into admission would solve problems the core does not have.

[RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html) defines deterministic CBOR
requirements, including preferred shortest encodings and definite-length handling.
Those rules are sound, but a Seki decoder would still have to recognize and reject
more representational choices than a fixed positional schema permits.

## Selected split

Authority-bearing typed-core modules and admission bundles use the proposed Seki
Canonical Binary format, SCB-0. It is positional, fixed-schema, definite-length,
and deliberately lacks generic maps, floating point, null, tags, padding, and
extension fields.

The generated `seki.lock` uses a restricted canonical JSON document. It is human-
readable build evidence consumed by untrusted build tooling, not an admission
input. Admission reopens the actual SCB module bytes and recomputes their digests.
This keeps digest management humane without putting JSON in the proof kernel.

## Why the decision is provisional

This comparison selects the format family but does not assign final bytes. A
byte-level freeze requires:

- review of the provisional typed-core field and tag ledger;
- proof of the canonical-reconstruction witness normal form;
- hostile coverage of every provisional admission-reason pair;
- validation of the SHA-256 domain rule and `U32` ceiling; and
- positive, hostile, truncation, and digest vectors from an independent encoder.

Until those exist, SCB-0 documents are design inputs and all tag values are
provisional.
