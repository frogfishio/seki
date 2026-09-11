# Construction and constant-time access lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/construction_access.seki`
- Emitter: `tools/encoding/emit_construction_access_scb0.mjs`

## Purpose

This fixture exercises `Let`, tuple construction, `Option::None`,
`Option::Some`, `Result::Ok`, `Result::Error`, array access, and `Index` values.
It separates constant-time array access from traversal intrinsics whose costs
expand by static length.

## Exact reconstructed bounds

| Function | Steps | Live bits | Depth | Workspace bits |
| --- | ---: | ---: | ---: | ---: |
| `arrayAt` | 4 | 353 | 3 | 0 |
| `error` | 3 | 33 | 3 | 0 |
| `indexEcho` | 2 | 6 | 2 | 0 |
| `none` | 2 | 33 | 2 | 0 |
| `ok` | 3 | 97 | 3 | 0 |
| `pair` | 4 | 99 | 3 | 0 |
| `remember` | 4 | 96 | 3 | 0 |
| `some` | 3 | 97 | 3 | 0 |

The array contains 128 semantic bits. Array access returns a 33-bit
`Option[U32]`; `indexEcho` carries a three-bit `Index[5]` value.

The emitted module is 859 bytes and has domain-separated module digest
`6281f8bc3dff0597c55f41768ef33e33a23c4d81bde06e1b580e90f7ea180444`.
