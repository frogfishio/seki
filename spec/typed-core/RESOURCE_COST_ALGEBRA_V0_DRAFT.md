# Seki resource-cost algebra v0 draft

- Status: bootstrap semantic proposal; non-normative
- Companion model: `SEKI_TYPED_CORE_V0_DRAFT.md` revision 0.3
- Target work package: F1-A07

## 1. Purpose

This document defines one deterministic structural resource calculation. Its
result is deliberately independent of C object layout and optimizer behavior.
It is a canonical conservative bound, not a prediction of elapsed time or native
memory consumption. It bounds admitted Seki evaluation; decoding, admission,
proof checking, artifact generation, and host orchestration require separate
resource profiles.

Every addition, multiplication, maximum, tag calculation, and capacity expansion
uses checked natural-number arithmetic within the selected profile. Overflow
rejects admission.

## 2. Semantic value width

Define:

```text
choice_bits(n)  = 0, when n <= 1
                = ceil(log2(n)), otherwise

counter_bits(n) = choice_bits(n + 1)  ;; values 0 through n

tag_bits(t)     = 0, when t = 0
                = floor(log2(t)) + 1, otherwise
```

`value_bits(T)` is canonical:

| Type | Semantic bits |
| --- | --- |
| `Unit` | 0 |
| `Bool` | 1 |
| `U8`/`I8` ... `U64`/`I64` | integer width |
| `ArithmeticError` | 2 |
| `Bytes[N]`, `Identity[D,N]`, `Digest[A,N]` | `8*N` |
| `Index[N]` | `choice_bits(N)` |
| `Tuple[...]`, record, variant payload | sum of component/field widths |
| `Array[T,N]` | `N * value_bits(T)` |
| `BoundedVec[T,N]` | `counter_bits(N) + N*value_bits(T)` |
| `Option[T]` | `1 + value_bits(T)` |
| `Result[T,E]` | `1 + max(value_bits(T), value_bits(E))` |
| `Decision[A,R]` | `1 + max(value_bits(A), value_bits(R))` |
| declared variant | `tag_bits(max_tag) + max(payload widths, 0)` |
| nominal | width of its representation |
| alias | width after alias expansion |

The unused payload capacity in an intrinsic sum or variant is still part of its
semantic value width. Sparse stable variant tags therefore have an explicit cost.
No padding, alignment, pointer, allocator, or host-word assumption appears here.

## 3. Canonical evaluation schedule

The cost derivation symbolically executes this fixed abstract schedule:

1. Function and kernel parameter values begin in immutable typed slots.
2. Every pure expression is entered once and evaluates children in its specified
   order.
3. A child result remains live until its parent has constructed its result.
4. A result is a fresh slot of `value_bits(result_type)`; after construction,
   consumed child slots are released.
5. `Let` and `KernelLet` move the value result into the extended environment
   without copying it, then release it when the body finishes.
6. A local read and field projection produce fresh result slots. This is a
   deliberate conservative copy model, independent of backend aliasing.
7. Call argument results become callee parameter slots without copying. The
   caller environment remains live; the callee result moves back to the caller.
8. Match scrutinees remain live while the selected arm runs. A payload binder is
   a fresh slot containing the complete payload.
9. A bounded intrinsic retains its input values and declared intrinsic workspace
   while invoking its block. Block parameter slots are fresh copies.
10. Branching nodes derive the maximum of their possible schedules. Bounded
    traversal derives against static capacity even when runtime length or early
    termination would execute fewer iterations.

`maximum_live_value_bits` is the maximum sum of live typed-slot widths at any
point in this schedule, including initial parameters and the final result.
Because the schedule is fixed, two admission checkers cannot choose different
liveness optimizations.

## 4. Logical steps

A logical step is charged for each entered `Expr`, `KernelExpr`, callable body,
and block invocation. It is not a CPU instruction. For callable `f`, define
`S_callable(f) = 1 + S(f.body)`; stored callable bounds include this root entry.

Let `S(x)` be the derived worst-case step count:

| Shape | Steps |
| --- | --- |
| leaf expression | `1` |
| strict node with children `e1..en` | `1 + sum(S(ei))` |
| `AndThen`, `OrElse` | `1 + S(left) + S(right)` |
| pure `If` | `1 + S(condition) + max(S(yes), S(no))` |
| pure `Match` | `1 + S(scrutinee) + max(S(arms))` |
| `Let` | `1 + S(value) + S(body)` |
| function call | `1 + sum(S(arguments)) + S_callable(callee)` |
| `KernelAccept` | `1 + S(value)` |
| `KernelReject` | `1 + S(reason)` |
| `KernelRequire` | `1 + S(condition) + max(S(rejection), S(continuation))` |
| `KernelLet` | `1 + S(value) + S(body)` |
| `KernelIf` | `1 + S(condition) + max(S(yes), S(no))` |
| `KernelMatch` | `1 + S(scrutinee) + max(S(arms))` |

The right operand of short-circuit Boolean logic is charged because the bound is
worst-case. The non-selected branch is not charged; the maximum selected branch
is charged instead.

For a collection with static capacity `N`, block invocation costs one step in
addition to its body:

```text
S(VecLength(c))       = 1 + S(c)
S(ArrayGet(c, i))     = 1 + S(c) + S(i)
S(VecGet(c, i))       = 1 + S(c) + S(i)
S(Fold(c, z, b))      = 1 + S(c) + S(z) + N*(1 + S(b.body))
S(FindUnique(c, b))   = 1 + S(c) + N*(1 + S(b.body))
S(All(c, b))          = 1 + S(c) + N*(1 + S(b.body))
S(Any(c, b))          = 1 + S(c) + N*(1 + S(b.body))
S(MapBounded(c, b))   = 1 + S(c) + N*(1 + S(b.body))
S(FilterBounded(c,b)) = 1 + S(c) + N*(1 + S(b.body))
```

Imported function costs are reopened from the exact digest-bound admitted module,
not accepted from an untrusted summary.

## 5. Evaluator-control depth

`maximum_control_depth` is the maximum number of simultaneously active abstract
callable, expression, kernel-expression, intrinsic, and block-invocation frames.
It is calculated by the schedule in section 3:

- a leaf expression has depth one beneath its callable frame;
- a syntax node contributes one plus the maximum depth of a child it evaluates;
- a call keeps its call-expression frame while entering one callee callable frame;
- an intrinsic keeps its expression frame while entering one block-invocation
  frame and the block body; and
- sequential iterations do not accumulate depth.

The root callable frame counts as one. The separate module
`maximum_call_depth` ceiling counts callable frames only and is checked from the
acyclic call graph. Neither quantity is a native stack-byte claim.

## 6. Abstract workspace

Workspace is intrinsic state that is neither a source-visible environment slot
nor a control frame. For collection capacity `N`, the intrinsic base workspace is:

| Intrinsic | Workspace bits |
| --- | --- |
| `ArrayGet`, `VecLength`, `VecGet` | 0 |
| `Fold[..., U]` | `counter_bits(N) + value_bits(U)` |
| `FindUnique[..., T]` | `counter_bits(N) + 2 + value_bits(T)` |
| `All`, `Any` | `counter_bits(N) + 1` |
| `MapBounded[..., U]` | `counter_bits(N) + value_bits(output collection)` |
| `FilterBounded[..., T]` | `counter_bits(N) + value_bits(BoundedVec[T,N])` |

The two `FindUnique` state bits distinguish zero, one, and multiple matches. A
partial map/filter output becomes the returned value by move rather than copy.
While a block runs, its workspace is added to the retaining intrinsic's base
workspace. Across sequential children and iterations, workspace takes the
maximum; across a call it includes the caller's retained workspace plus the
callee's maximum.

All non-intrinsic nodes have zero base workspace. This classification prevents an
implementation from hiding allocation in an unspecified evaluator scratch area.

## 7. Admission obligations

Admission recomputes all four metrics from the canonical module and exact imports.
It requires equality with `exact_derived_bounds`, then checks each component
against the declared function/kernel and module ceilings. A larger producer claim
is rejected just like a smaller one: there is one canonical result.

The canonical AST is the bound-derivation tree and `exact_derived_bounds` is its
proposed conclusion. Intermediate tuples are reconstructed rather than
serialized, as specified by `DERIVATION_WITNESS_NORMAL_FORM_V0_DRAFT.md`.

The later representation and C stages must map semantic slots, control frames,
and abstract workspace to concrete objects without exceeding their separately
proved byte/alignment/stack/workspace limits.
