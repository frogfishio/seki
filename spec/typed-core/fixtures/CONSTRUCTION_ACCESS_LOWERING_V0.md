# Construction and constant-time access lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/construction_access.seki`
- Emitter: `tools/encoding/emit_construction_access_scb0.mjs`

## Purpose

This fixture exercises `Let`, tuple construction, `Option::None`,
`Option::Some`, `Result::Ok`, `Result::Error`, array access, bounded-vector
access, and bounded-vector length. It separates constant-time collection
operations from the traversal intrinsics whose costs expand by static capacity.

## Exact reconstructed bounds

| Function | Steps | Live bits | Depth | Workspace bits |
| --- | ---: | ---: | ---: | ---: |
| `arrayAt` | 4 | 353 | 3 | 0 |
| `error` | 3 | 33 | 3 | 0 |
| `none` | 2 | 33 | 2 | 0 |
| `ok` | 3 | 97 | 3 | 0 |
| `pair` | 4 | 99 | 3 | 0 |
| `remember` | 4 | 96 | 3 | 0 |
| `some` | 3 | 97 | 3 | 0 |
| `vecAt` | 4 | 359 | 3 | 0 |
| `vecLength` | 3 | 265 | 3 | 0 |

The array contains 128 semantic bits. `BoundedVec[U32,4]` contains 128 element
bits plus the three-bit length counter, for 131 bits. Both access forms return a
33-bit `Option[U32]`; `vecLength` returns the three-bit `Index[5]`.

The emitted module is 975 bytes and has domain-separated module digest
`1f84f39f3b7d4934df7127e086c135a94d4b87042e8887f7445dcdb4502f07d2`.
