# Experimental minimal SCB-0 module vector

- Status: experimental; not a byte freeze or admitted-module claim
- Machine record: `minimal-module-v0.json`
- Independent emitters: C11 and JavaScript

## Abstract value

```text
Module {
  schema_version: 0,
  language: io.frogfish.seki/language@0,
  identity: a @ 1,
  semantic_profile: c11_bounded @ 1,
  imports/domains/types/functions/kernels: empty,
  exports: all empty,
  required_theorems/claim_ceiling: empty,
  declared_module_ceiling: {
    maximum_typed_core_bytes: 1024,
    every other quantity: 0
  },
  derivations: { schema_version: 0, type_order: [], function_order: [] }
}
```

The complete envelope is 145 octets and its payload is 132 octets (`0x84`). The
recorded digest is SHA-256 over the specified ASCII domain, one zero octet, and
the complete 145-octet module envelope.

The vector establishes agreement about current field order, zero-octet singleton
values, empty sequences, framing, and digest domain separation. It does not yet
establish that the abstract module is admissible under a frozen profile: profile
definitions and admission are not implemented.

Run:

```sh
make check-encoding-vectors
```
