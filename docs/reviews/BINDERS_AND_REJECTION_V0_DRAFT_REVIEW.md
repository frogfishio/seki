# Binder and rejection-precedence review

- Date: 2026-09-11
- Scope: F1-A04/F1-A06 bootstrap review
- Disposition: structural model accepted for the next draft pass; not frozen
- Authority: no implementation or proof claim

## Findings

### Resolved: kernel control was not confined to tail position

`Require`, `Accept`, and `Reject` previously appeared in the general expression
grammar. Type checking would reject many nonsensical placements, but the model did
not make it structurally impossible to place kernel control in a value-producing
context.

They now inhabit a separate inductive `KernelExpr`. Its pure children are `Expr`
and its control children are `KernelExpr`, so every path has one terminal decision.

### Resolved: precedence checking did not cross structural nodes

The previous rule discussed nested requirements but did not state how an earlier
requirement constrained a later rejection reached through a binding, conditional,
or match.

Admission now carries a minimum permitted rejection index through the entire
kernel tail. Requirements increase it for their continuation; structural nodes
preserve and distribute it. This defines one simple deterministic check.

### Resolved: payload binder cardinality was implicit

The model now specifies binder arity and type for every intrinsic constructor and
for declared nullary and payload variants. Constructor shape is authoritative.
Every payload arm binds exactly one complete payload at local index 0; nested
destructuring requires nested matches.

### Confirmed: the candidate fixture exercises the intended rule

The duplicate and missing outcomes are mutually exclusive branches and may use
indices 1 and 0 independently. In the unique-candidate branch, stale index 2 is
followed only by disabled index 3. The nested result and option payloads place the
original input at local index 3 exactly as documented.

## Remaining work

- Add canonical positive and hostile vectors once the wire encoding is selected.
- Freeze declared-variant field-pattern surface syntax.
- Include `KernelExpr` nodes in the exact step/control-depth cost algebra.
- Prove the structural checker sound with respect to the eventual evaluation
  relation during F1.

## Conclusion

The binder and rejection model no longer relies on producer discipline or an
unstated traversal convention. It is ready to feed the arithmetic and resource
algebra review, but remains non-normative while global F0 is open.
