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
| Array operation changed to vector operation in canonical bytes | `080e` |
| `Option::None` item type changed without changing claim bytes | `0800` |
| `Let` body local points beyond its extended environment | `0702` |
| Tuple item removed without changing claimed tuple | `0800` |
| `All` changed to `MapBounded` without changing result bytes | `0800` |
| `Fold` block has the wrong parameter count | `080e` |
| `KernelIf` condition changed from `Bool` to `U32` | `0801` |
| Byte literal length differs from its claimed `Bytes` type | `0800` |
| Boolean `Not` receives a `U16` operand | `0801` |
| Module resource ceiling is below a callable declaration | `0b06` |
| Declared module import ceiling exceeds the profile | `0b07` |
| Actual declaration count exceeds the module ceiling | `0b06` |
| Canonical module bytes exceed the module ceiling | `0b06` |
| Local expression-node count exceeds the module ceiling | `0b06` |
| Local syntax nesting exceeds the module ceiling | `0b06` |
| Reopened callable chain exceeds module call depth | `0b08` |
| `All` step claim omits static-capacity work | `0b01` |
| Map workspace claim omits the partial output | `0b04` |
| Projection owner does not match record | `0704` |
| Reopened imported parameter type differs from call argument | `0803` |
| False exact logical steps | `0b01` |
| False exact maximum live bits | `0b02` |
| False exact control depth | `0b03` |
| False exact workspace bits | `0b04` |
| Declared callable ceiling below exact result | `0b05` |

These cases begin after successful structural decoding so that each mutation
isolates the semantic checker. Seven cases now operate on canonical module bytes;
the remaining object-level cases must eventually gain byte-level
counterparts. This file does not claim an admission-result vector freeze.
