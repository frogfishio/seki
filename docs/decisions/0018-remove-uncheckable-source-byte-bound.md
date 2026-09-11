# ADR 0018: Source byte limits are outside typed-core admission

- Status: accepted for bootstrap; not a language freeze
- Date: 2026-09-11

## Decision

Remove `maximum_input_bytes` from `ModuleBounds` and SCB-0. It had no single
checkable meaning: source text is not an input to typed-core admission, and v0
does not define a byte encoding for runtime argument values.

`maximum_typed_core_bytes` continues to bound the canonical encoded module.
Bundle byte limits continue to bound the complete admission bundle. Runtime
argument values are bounded by their admitted types and the semantic
live-value/resource calculation.

A source compiler may impose a source-file byte limit as an ordinary host-tool
safeguard. That limit is not semantic identity, is not copied into typed core,
and cannot support an admission or proof claim. A future runtime interchange
encoding must define and bound its own byte representation explicitly.

## Consequences

`ModuleBounds` contains only observations available to an admission checker.
All provisional SCB-0 fixtures are regenerated because the bounds record loses
one `U32` field.

Admission reason `0000` is renamed from the ambiguous
`input_bytes_ceiling_exceeded` to `module_envelope_bytes_ceiling_exceeded`. It
refers only to the selected profile's hard ceiling on incoming canonical module
bytes. A module's smaller declared `maximum_typed_core_bytes` remains a module
structure-ceiling failure.
