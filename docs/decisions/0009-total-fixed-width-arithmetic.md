# ADR 0009: Total fixed-width arithmetic

- Status: accepted for bootstrap; not a language freeze
- Date: 2026-09-11

## Decision

Seki integer semantics are defined over mathematical integers and then mapped to
fixed-width results. They never inherit C overflow, conversion, signed remainder,
or shift behavior.

- Binary arithmetic operands have one identical integer type; there are no
  promotions.
- Negation accepts signed types only.
- Shift counts are `U32`; counts greater than or equal to the value width return
  `InvalidShift` under every policy.
- Signed division truncates toward zero and remainder satisfies `r = x - q*y`.
- Zero divisors return `DivideByZero` under every policy.
- Checked `min / -1` returns `Overflow`; wrapping returns the minimum; saturating
  returns the maximum. The corresponding remainder is zero under every policy.
- Signed right shift is mathematical floor division by a power of two.
- Checked conversion returns `OutOfRange`; wrapping and saturating conversions
  use explicitly defined mathematical functions.

Add, subtract, multiply, negate, and left shift use checked, wrapping, or
saturating range handling. Division, remainder, and shifts return `Result` under
all policies because some operational errors remain possible.

## Consequences

Generated C must guard zero division, `min / -1`, and invalid shifts before any C
operator is evaluated. Signed overflow and implementation-defined signed right
shift cannot occur in emitted code. Surface result-propagation and conversion
spellings remain to be selected.

This decision grants no C-refinement or proof authority.
