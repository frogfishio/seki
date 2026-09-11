# Bounded array traversal lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/traversal.seki`
- Emitter: `tools/encoding/emit_traversal_scb0.mjs`

## Purpose

This fixture exercises `ArrayFold`, `ArrayAll`, `ArrayAny`, and `ArrayMap` over
length-four arrays. It checks block signatures, static-length step expansion,
fresh block parameter slots, and intrinsic
workspace independently of concrete C layout.

## Exact reconstructed bounds

| Function | Steps | Live bits | Depth | Workspace bits |
| --- | ---: | ---: | ---: | ---: |
| `all` | 11 | 10 | 4 | 4 |
| `any` | 11 | 10 | 4 | 4 |
| `fold` | 12 | 416 | 4 | 35 |
| `mapArray` | 11 | 320 | 4 | 131 |

Each length-four single-input traversal charges
`1 + S(collection) + 4*(1 + S(block.body))`; the callable frame adds one more
step. `ArrayAll` and `ArrayAny` use four workspace bits: a three-bit counter plus
one state bit. `ArrayFold[U32]` uses 35 bits: the counter plus a 32-bit
accumulator.

Map workspace contains the complete partial output. It becomes the
returned value by move, so the cost algebra does not allocate a second output
slot at traversal completion.

The emitted module is 597 bytes and has domain-separated module digest
`9873293868f08df4fea66802ffb3dbdb71b98f4a241cef9d79f48aee0d683cc2`.
