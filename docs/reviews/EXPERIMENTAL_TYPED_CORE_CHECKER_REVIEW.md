# Experimental typed-core checker review

- Date: 2026-09-11
- Scope: semantic reconstruction for the current positive fixtures
- Disposition: bootstrap semantic oracle; deliberately incomplete
- Authority: no admission, type-safety, resource, proof, or byte-freeze claim

## Result

The independent JavaScript checker reopens the decoded minimal module,
candidate-selection module, two-module import bundle, and payload-record module.
For the constructs actually used by those fixtures it:

- normalizes local and indexed imported type identities against exact decoded
  modules;
- reopens imported function signatures rather than trusting a copied summary;
- checks de Bruijn locals, record projection ownership, equality operands, call
  arguments/results, record construction, payload-bearing variant construction,
  pure and kernel matches, payload binders, `FindUnique` blocks, rejection
  identity, and rejection precedence;
- derives semantic value widths from declarations; and
- independently reconstructs logical steps, maximum live value bits, evaluator
  depth, and intrinsic workspace.

The reconstructed candidate-selection kernel tuple is exactly
`{212, 19379, 8, 201}`. The imported functions reconstruct as:

| Function | Steps | Live bits | Depth | Workspace bits |
| --- | ---: | ---: | ---: | ---: |
| `base.keep` | 2 | 64 | 2 | 0 |
| `consumer.forward` | 5 | 96 | 4 | 0 |
| `consumer.twice` | 14 | 128 | 7 | 0 |

Eight hostile semantic-object mutations reject false claimed types, a mismatched
projection owner, a changed imported signature, each of the four exact resource
components, and a declared ceiling below the exact result.

The payload fixture additionally reconstructs `leftOrZero` as `{5, 290, 4, 0}`,
`makePair` as `{4, 192, 3, 0}`, and `wrapPair` as `{6, 193, 4, 0}`. Three new
hostile cases reject a changed payload label, a false payload-binder type, and a
missing record field. The first two are mutations of canonical module bytes.

The arithmetic/control fixture adds nine positive functions covering checked,
wrapping, and saturating result rules, division's policy-independent error
result, signed negation, conversion, shifts, comparison, short-circuit Boolean
evaluation, and pure `If`. Four hostile cases reject a policy/result mismatch,
different branch types, unsigned negation, and a non-`U32` shift count. The
policy mutation operates on canonical module bytes.

The construction/access fixture adds `Let`, tuples, both `Option` constructors,
both `Result` constructors, array access, bounded-vector access, and
bounded-vector length. Four hostile cases reject a collection-family mismatch,
a false option item claim, an out-of-scope let local, and a tuple shape mismatch.
The collection and option cases mutate canonical module bytes.

The traversal fixture adds `Fold`, `All`, `Any`, array/vector `MapBounded`, and
array/vector `FilterBounded`. It independently checks capacity-multiplied steps,
block frames and parameter slots, accumulator/state workspace, and partial-output
workspace. Four hostile cases reject a changed traversal result family, an
invalid fold block, a step count that omits static-capacity work, and map
workspace that omits its output buffer. The family mutation operates on
canonical module bytes.

The kernel-conditional fixture completes positive coverage of the six
kernel-control tags. Its hostile case rejects a non-Boolean `KernelIf` condition.
The separate machine-checked coverage ledger now accounts for all 69 tagged
types, declarations, pure terms, and kernel terms with positive fixture evidence.
The closure fixture supplies the former eleven gaps.

The checker also enforces the first module/profile ceiling layer: module ceiling
tuples cannot exceed `c11_bounded@1`; actual canonical bytes, imports, and
declaration counts cannot exceed the module tuple; and callable declared resource
tuples cannot exceed the module resource tuple. Four hostile cases distinguish
module failure `0b06` from profile failure `0b07`.

Module structural observation now counts local expression/kernel nodes, measures
syntax-only nesting, and derives callable depth across exact imported functions.
Candidate selection reconstructs 30 nodes at nesting seven; the import chain
reconstructs callable depths one, two, and three. Three hostile cases cover the
associated module and call-depth ceilings.

All semantic bound naturals are now checked against the SCB-0 `U32` domain.
Value-width multiplication and capacity-expanded traversal steps have explicit
overflow hostiles; overflow reports `0b00` before exact-bound mismatch.

Type formation now rechecks zero `Index` bounds, SHA-256 digest length, empty and
recursive declarations, duplicate variant case names, forbidden public
`VariantPayload`, and unexpanded declared alias references. Seven hostile cases
cover the rules. V0 equality is explicitly defined for every well-formed member
of its closed value-type sum and therefore checks exact normalized type identity.

The `c11_bounded@1` policy rejects empty bytes, tuples, arrays, and bounded
vectors with `0608`, and rejects any single semantic value wider than the
profile live-value ceiling with `0607`. A nominal accepts every otherwise
well-formed public v0 type, so the unused `invalid_nominal_representation` reason
was removed rather than preserving an unreachable failure.

## Boundary of the result

Most hostile cases deliberately mutate freshly decoded objects after structural
and digest validation. This isolates the semantic layer; two cases now mutate
SCB-0 bytes, but the suite is not yet a standalone hostile-vector corpus. The
checker implements only the term forms reached by the seven current fixtures. In
particular, it does not yet cover all construction forms, every
comparison/arithmetic combination, the remaining bounded intrinsic families,
module ceilings, or profile ceilings.

The checker is ordinary unverified JavaScript. Agreement with hand-derived
fixtures is useful design feedback, not evidence that the checker or the draft
cost algebra is correct.

## Conclusion

The current type identity and resource recurrence survive their first composed
implementation tests. The remaining broad rules are source-input ceiling meaning
and publication declaration coupling, continuing to add byte-level hostile vectors before
translating frozen rules into Lean.
