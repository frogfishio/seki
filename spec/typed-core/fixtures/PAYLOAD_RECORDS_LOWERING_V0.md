# Payload records lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/payload_records.seki`
- Emitter: `tools/encoding/emit_payload_records_scb0.mjs`

## Purpose

This fixture adds the first positive typed-core witnesses for record
construction, a payload-bearing declared variant, payload construction, a pure
exhaustive match, the single complete-payload binder, and projection through a
payload-owned `FieldRef`.

The canonical declaration order is `Pair`, `Wrapped`. Canonical function-key
order is `leftOrZero`, `makePair`, `wrapPair`.

## Exact reconstructed bounds

| Function | Steps | Live bits | Depth | Workspace bits |
| --- | ---: | ---: | ---: | ---: |
| `leftOrZero` | 5 | 290 | 4 | 0 |
| `makePair` | 4 | 192 | 3 | 0 |
| `wrapPair` | 6 | 193 | 4 | 0 |

`Pair` has width 64 bits. `Wrapped` has a one-bit tag plus its maximum 64-bit
payload, for 65 bits. The payload match arm receives one fresh 64-bit
`VariantPayload(Wrapped::Pair)` slot; it does not bind the two fields separately.

The emitted module is 753 bytes and has domain-separated module digest
`3406e18ebc7c20cd34561841cba1d1ba39760f798a1fe8bc8930e9ca538e1c0a`.
