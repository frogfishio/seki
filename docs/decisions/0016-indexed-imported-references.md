# ADR 0016: Imported references index the canonical import table

- Status: accepted for bootstrap; byte freeze pending
- Date: 2026-09-11

## Decision

An imported type, domain, or function reference stores two `U32` values:

```text
(canonical_import_index, exported_declaration_index)
```

The selected import-table entry contains the exact `ModuleId` and canonical
module digest. Admission reopens that module, verifies the declaration is
exported in the required namespace, and checks its exact signature.

References do not repeat the full module path and SHA-256 digest at every use.
Source aliases remain elaboration-only and do not enter typed core.

## Rationale

The first two-module fixture made the redundancy measurable. Repeating identity
and digest bytes produced a 1,168-byte consumer. Indirection through the already
canonical, digest-bound import table reduced it by roughly 56%; after the later
`ModuleBounds` simplification the consumer is 514 bytes,
while retaining exactly the same authority relationship.

## Consequences

Admission adds one bounded table lookup before an imported declaration lookup.
The proof obligation is simpler: show that the import index selects the exact
digest-bearing entry, then show the declaration index selects an export of the
required kind. Transitive imports remain invisible.

Reordering imports changes reference meaning, but canonical `ModuleId` order
fixes one import table order and therefore one byte representation.
