# Typed-core semantic hostile cases v0

- Status: experimental; not frozen
- Runner: `tools/encoding/check_typed_core_vectors.sh`
- Input boundary: mutations of freshly decoded canonical objects

| Case | Expected reason |
| --- | --- |
| False expression claimed type | `0800` |
| Projection owner does not match record | `0704` |
| Reopened imported parameter type differs from call argument | `0803` |
| False exact logical steps | `0b01` |
| False exact maximum live bits | `0b02` |
| False exact control depth | `0b03` |
| False exact workspace bits | `0b04` |
| Declared callable ceiling below exact result | `0b05` |

These cases begin after successful structural decoding so that each mutation
isolates the semantic checker. They must eventually gain canonical byte-level
counterparts; this file does not claim an admission-result vector freeze.
