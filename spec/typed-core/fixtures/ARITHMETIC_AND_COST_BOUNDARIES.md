# Arithmetic and cost boundary fixtures

- Status: abstract expected results; not canonical bytes
- Companions: typed-core draft 0.2 and resource-cost algebra draft

## Arithmetic boundaries

`Ok` and `Error` below are intrinsic `Result` constructors.

| Expression | Checked | Wrapping | Saturating |
| --- | --- | --- | --- |
| `I8(127) + I8(1)` | `Error(Overflow)` | `I8(-128)` | `I8(127)` |
| `-I8(-128)` | `Error(Overflow)` | `I8(-128)` | `I8(127)` |
| `I8(-7) / I8(3)` | `Ok(I8(-2))` | `Ok(I8(-2))` | `Ok(I8(-2))` |
| `I8(-7) % I8(3)` | `Ok(I8(-1))` | `Ok(I8(-1))` | `Ok(I8(-1))` |
| `I8(7) / I8(-3)` | `Ok(I8(-2))` | `Ok(I8(-2))` | `Ok(I8(-2))` |
| `I8(7) % I8(-3)` | `Ok(I8(1))` | `Ok(I8(1))` | `Ok(I8(1))` |
| `I8(-128) / I8(-1)` | `Error(Overflow)` | `Ok(I8(-128))` | `Ok(I8(127))` |
| `I8(-128) % I8(-1)` | `Ok(I8(0))` | `Ok(I8(0))` | `Ok(I8(0))` |
| `I8(1) / I8(0)` | `Error(DivideByZero)` | `Error(DivideByZero)` | `Error(DivideByZero)` |
| `I8(-3) >> U32(1)` | `Ok(I8(-2))` | `Ok(I8(-2))` | `Ok(I8(-2))` |
| `I8(64) << U32(1)` | `Error(Overflow)` | `Ok(I8(-128))` | `Ok(I8(127))` |
| `U8(255) << U32(1)` | `Error(Overflow)` | `Ok(U8(254))` | `Ok(U8(255))` |
| `U8(1) << U32(7)` | `Ok(U8(128))` | `Ok(U8(128))` | `Ok(U8(128))` |
| `U8(1) << U32(8)` | `Error(InvalidShift)` | `Error(InvalidShift)` | `Error(InvalidShift)` |
| convert `I16(-1)` to `U8` | `Error(OutOfRange)` | `U8(255)` | `U8(0)` |
| convert `U16(300)` to `U8` | `Error(OutOfRange)` | `U8(44)` | `U8(255)` |
| convert `I8(-3)` to `I8` | `Ok(I8(-3))` | `I8(-3)` | `I8(-3)` |

Negating any unsigned value and shifting by a non-`U32` count are static type
rejections rather than evaluation results.

## Candidate-selection semantic widths

Using the candidate-selection fixture:

```text
value_bits(CandidateId) = 16 * 8 = 128
value_bits(Epoch)       = 64
value_bits(Candidate)   = 1 + 64 + 128 = 193

counter_bits(32) = choice_bits(33) = 6
value_bits(Array[Candidate, 32]) = 32*193 = 6176
value_bits(Input) = 6176 + 64 + 128 = 6368

tag_bits(max rejection tag 4) = 3
value_bits(Rejection) = 3
value_bits(Decision[Candidate, Rejection]) = 1 + max(193, 3) = 194

ArrayFindUnique base workspace = counter_bits(32) + 2 + value_bits(Candidate)
                          = 6 + 2 + 193
                          = 201
```

The three-bit rejection tag is intentional: stable tags are `1` through `4`, so
the maximum tag—not merely the number of cases—determines semantic tag width.

These are algebra checks, not C sizes. Concrete records may contain padding and
the generated implementation will require separately proved byte bounds.
