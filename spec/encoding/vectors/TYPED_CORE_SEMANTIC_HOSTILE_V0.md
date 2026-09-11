# Typed-core semantic hostile cases v0

- Status: experimental; not frozen
- Runner: `tools/encoding/check_typed_core_vectors.sh`
- Input boundary: mutations of freshly decoded canonical objects

| Case | Expected reason |
| --- | --- |
| False expression claimed type | `0800` |
| Payload field label changed in canonical bytes | `0806` |
| Payload binder claimed type changed in canonical bytes | `0800` |
| Required record field removed | `0805` |
| Arithmetic policy changed without changing claimed result bytes | `0800` |
| Pure `If` branches have different types | `0807` |
| Negation operand changed to unsigned | `080d` |
| Shift count changed from `U32` to `Bool` | `080c` |
| Projection owner does not match record | `0704` |
| Reopened imported parameter type differs from call argument | `0803` |
| False exact logical steps | `0b01` |
| False exact maximum live bits | `0b02` |
| False exact control depth | `0b03` |
| False exact workspace bits | `0b04` |
| Declared callable ceiling below exact result | `0b05` |

These cases begin after successful structural decoding so that each mutation
isolates the semantic checker. Three cases now operate on canonical module bytes;
the remaining object-level cases must eventually gain byte-level
counterparts. This file does not claim an admission-result vector freeze.
