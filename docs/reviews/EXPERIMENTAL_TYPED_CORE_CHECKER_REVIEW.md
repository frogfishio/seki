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

## Boundary of the result

Most hostile cases deliberately mutate freshly decoded objects after structural
and digest validation. This isolates the semantic layer; two cases now mutate
SCB-0 bytes, but the suite is not yet a standalone hostile-vector corpus. The
checker implements only the term forms reached by the five current fixtures. In
particular, it does not yet cover all construction forms, every
comparison/arithmetic combination, the remaining bounded intrinsic families,
module ceilings, or profile ceilings.

The checker is ordinary unverified JavaScript. Agreement with hand-derived
fixtures is useful design feedback, not evidence that the checker or the draft
cost algebra is correct.

## Conclusion

The current type identity and resource recurrence survive their first composed
implementation tests. The next useful work is the remaining construction and
bounded-intrinsic families, continuing to add byte-level hostile vectors before
translating frozen rules into Lean.
