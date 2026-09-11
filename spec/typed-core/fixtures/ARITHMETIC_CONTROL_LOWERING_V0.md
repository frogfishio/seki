# Arithmetic and pure control lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/arithmetic_control.seki`
- Emitter: `tools/encoding/emit_arithmetic_control_scb0.mjs`

## Purpose

This fixture exercises explicit arithmetic policies and their result-type
consequences, comparison, short-circuit Boolean control, pure `If`, signed
negation, conversion, division, and shift-count typing. It contains no declared
types so primitive and intrinsic-result rules are exposed directly.

## Exact reconstructed bounds

| Function | Result | Steps | Live bits | Depth | Workspace bits |
| --- | --- | ---: | ---: | ---: | ---: |
| `addChecked` | `Result[U32, ArithmeticError]` | 4 | 161 | 3 | 0 |
| `addWrapping` | `U32` | 4 | 160 | 3 | 0 |
| `both` | `Bool` | 4 | 3 | 3 | 0 |
| `choose` | `U32` | 4 | 97 | 3 | 0 |
| `convertSaturating` | `I32` | 3 | 160 | 3 | 0 |
| `divideWrapping` | `Result[U32, ArithmeticError]` | 4 | 161 | 3 | 0 |
| `less` | `Bool` | 4 | 129 | 3 | 0 |
| `negateChecked` | `Result[I32, ArithmeticError]` | 3 | 97 | 3 | 0 |
| `shiftChecked` | `Result[U32, ArithmeticError]` | 4 | 161 | 3 | 0 |

The contrast between `addWrapping` and `divideWrapping` is intentional:
wrapping addition returns the integer directly, while division retains a
`Result` under every policy because division by zero remains possible.

Short-circuit `both` releases the left condition before evaluating the right.
Its maximum live-value count is therefore three bits, not the five bits a strict
two-child schedule would derive.

The emitted module is 1,072 bytes and has domain-separated module digest
`9c62caef27938c9331f70515699e582c1dce4b304343c6104ef11b1f658a3a3d`.
