# Seki Canonical Binary (SCB-0) draft

- Status: provisional format direction; non-normative; byte assignments not frozen
- Scope: canonical typed-core modules and closed admission bundles

The provisional field and discriminant assignments are maintained in
`SCB0_SCHEMA_LEDGER.md`. Candidate framing, key ordering, and digest rules are in
`SCB0_KEYS_ENVELOPE_AND_DIGEST.md`.

## 1. Design rule

SCB-0 is not a general serialization language. Each byte position is interpreted
by one versioned Seki schema. A decoder either returns that unique typed value or
rejects the input; it does not preserve unknown data or choose among equivalent
representations.

## 2. Primitive candidates

The following primitives are the working design. Their use is not a byte freeze.

```text
U8          ::= exactly 1 octet
U32         ::= exactly 4 octets, unsigned, most-significant octet first
Bytes       ::= U32 byte_length | byte_length octets
Ascii       ::= Bytes whose payload octets are all in 0x00..0x7f
Name        ::= Ascii satisfying the nonempty Seki identifier grammar
Option[A]   ::= U8(0) | U8(1) A
Sequence[A] ::= U32 element_count | exactly element_count values of A
```

Other `Option` tags reject. Counts and byte lengths must also satisfy the active
profile ceiling before allocation or iteration. Schema positions may impose a
stricter grammar on `Ascii`, including `Name` and module path-segment rules.

Integer literal payloads have the exact width selected by their typed-core type,
are most-significant octet first, and use two's-complement representation for
signed types. Boolean payloads are one octet: `0` or `1` only.

## 3. Schema values

Closed sums use a one-octet discriminant followed immediately by the fields of
the selected case in schema order. Unknown discriminants reject. Records carry
only their fields in schema order: there are no serialized field names, omitted
defaults, unknown-field bags, or presence bitmaps.

Sequences that model canonical tables must arrive in strictly increasing order
under the table's typed-core key order. Equal or decreasing adjacent keys reject.
The decoder does not sort producer input.

References are fixed-width `U32` indices into the schema-designated table or
binder space. Admission validates their range and kind after structural decode.

## 4. Module envelope candidate

A canonical module envelope will contain, in fixed order:

1. format magic and SCB schema version;
2. language version;
3. semantic-profile identity;
4. exact module identity;
5. exact direct imports and their digests;
6. declarations and exported-kernel indices; and
7. canonical derivation witnesses.

The final magic bytes, version widths, digest representation, node discriminants,
and complete field ledger are intentionally unassigned. A module digest covers
the complete final canonical module byte sequence.

## 5. Bundle envelope candidate

A bundle contains one exact root `ModuleId` and a definite sequence of canonical
module envelopes in strict `ModuleId` order. Each nested envelope carries its own
payload length. Admission rejects
duplicates, unused modules, a missing root, noncanonical order, digest mismatch,
profile mismatch, cycles, and trailing bytes. Length delimitation permits profile
ceilings to be checked before each module is decoded.

The lockfile is not embedded as authority and is not an admission input.

## 6. Decoder discipline

The decoder is a single forward cursor. Before reading or allocating it checks
that the requested length fits both the containing envelope and the active
profile ceiling. Arithmetic on cursor positions, counts, and allocation sizes is
checked for overflow. A nested decode consumes exactly its declared extent; a
successful top-level decode consumes the input exactly.

SCB-0 has no:

- variable-length integers;
- indefinite lengths;
- padding or alignment bytes;
- generic maps or string-keyed objects;
- floating-point values, nulls, or generic semantic tags;
- alternate text encodings or Unicode normalization; or
- extension fields ignored by older readers.

## 7. Freeze ledger

SCB-0 cannot freeze until these are complete:

1. every typed-core record, field, sum, and table ledger entry is reviewed;
2. the reconstruction witness normal form is proved sufficient;
3. all discriminant and rejection-reason registries are assigned;
4. the `U32` ceiling is enforced by every v0 profile;
5. digest and domain-separation vectors confirm the candidate rule;
6. encoder/decoder pseudocode has exact rejection precedence; and
7. independent positive, noncanonical, hostile, truncation, and digest vectors
   agree byte for byte.
