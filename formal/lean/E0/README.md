# E0 Lean experiment

`MinimumAge.lean` separates the independent minimum-age requirement from the
minimum typed expression evaluator and proves the candidate expression satisfies
the complete threshold policy.

This is not yet the E0-03 program proof. The expression is presently a Lean AST
constant. The authoritative theorem must instead evaluate the program obtained
by decoding the exact E0 typed-core bytes and use a decoder-equality theorem to
connect that result to `minimumAgeProgram`.

The local exploratory check used Lean 4.33.1. The planned Lean 4.30.0 source
identity remains unbound, so this file and its successful check have experimental
status only.
