# Bounded traversal lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/traversal.seki`
- Emitter: `tools/encoding/emit_traversal_scb0.mjs`

## Purpose

This fixture exercises `Fold`, `All`, `Any`, `MapBounded`, and `FilterBounded`
over capacity-four arrays and bounded vectors. It checks block signatures,
static-capacity step expansion, fresh block parameter slots, and intrinsic
workspace independently of concrete C layout.

## Exact reconstructed bounds

| Function | Steps | Live bits | Depth | Workspace bits |
| --- | ---: | ---: | ---: | ---: |
| `all` | 11 | 10 | 4 | 4 |
| `any` | 11 | 10 | 4 | 4 |
| `filterArray` | 11 | 289 | 4 | 134 |
| `filterVec` | 11 | 295 | 4 | 134 |
| `fold` | 12 | 416 | 4 | 35 |
| `mapArray` | 11 | 320 | 4 | 131 |
| `mapVec` | 11 | 326 | 4 | 134 |

Each capacity-four single-input traversal charges
`1 + S(collection) + 4*(1 + S(block.body))`; the callable frame adds one more
step. `All` and `Any` use four workspace bits: a three-bit counter plus one state
bit. `Fold[U32]` uses 35 bits: the counter plus a 32-bit accumulator.

Map and filter workspace contains the complete partial output. It becomes the
returned value by move, so the cost algebra does not allocate a second output
slot at traversal completion.

The emitted module is 930 bytes and has domain-separated module digest
`91d69a1172e265769f1f6d178574485c10b475e497b9491f7d1c1cf56c8627ce`.
