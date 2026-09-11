# ADR 0008: Tail-formed kernel control

- Status: accepted for bootstrap; not a language freeze
- Date: 2026-09-11

## Decision

Kernel acceptance, rejection, and ordered requirements use a dedicated
`KernelExpr` grammar. They are not ordinary value-producing `Expr` nodes.

The kernel grammar contains only terminal acceptance/rejection and tail control:
pure-value binding, requirement continuation, conditional branches, and exhaustive
match arms. Consequently, every admitted kernel path terminates in exactly one
acceptance or rejection, and kernel control cannot be stored or embedded inside a
record field, arithmetic operand, function argument, or collection block.

Rejection precedence is checked with a lower-bound index carried through the
whole tail-control tree. A requirement raises that bound for its continuation;
lets preserve it; conditionals and matches pass it independently to every branch.
Mutually exclusive branches may use unrelated indices, while indices along any
sequentially reachable path must strictly increase.

Match constructors determine binder arity. Nullary constructors bind nothing;
payload constructors bind exactly one complete payload at local index 0. Neither
the surface producer nor typed core carries a Boolean that can contradict the
constructor.

## Consequences

- Pure functions and collection blocks cannot perform semantic rejection.
- Surface `require` statements elaborate into tail continuations.
- Surface bindings in kernels elaborate to `KernelLet`.
- Final kernel conditionals and matches elaborate to `KernelIf` and
  `KernelMatch`; value-producing conditionals and matches remain pure `Expr`.
- Admission can verify termination shape, binder depth, and rejection precedence
  structurally without path-sensitive theorem search.

This is a bootstrap specification decision and grants no implementation or proof
authority.
