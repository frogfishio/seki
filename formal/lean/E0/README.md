# E0 Lean experiment

`MinimumAge.lean` separates the independent minimum-age requirement from the
minimum typed expression evaluator. Its closed-subset SCB-0 decoder consumes the
exact hex artifact under `experiments/e0-vs1`, validates the complete 417-byte
module structure, and constructs the typed expression from the encoded terms.

Lean proves with its native decision procedure that this decoded expression is
exactly `minimumAgeProgram`. The final E0 theorem is stated for any program
returned by the exact decoder, rather than assuming the handwritten AST
constant as its input. It establishes the complete threshold policy and derives
both `NoMinorApproved` and `AdultApproved`.

This decoder is intentionally fixture-bounded. It is evidence for the vertical
slice, not the eventual complete SCB-0 admission checker or a frozen encoding.

The local exploratory check used Lean 4.33.1. The planned Lean 4.30.0 source
identity remains unbound, so this file and its successful check have experimental
status only. The decoder-equality proof also places this exploratory use of
`native_decide` and Lean's native evaluation path in the recorded E0 trust
boundary; a qualified proof portfolio must reassess or remove that premise.
