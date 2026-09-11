# Experimental typed-core checker review

- Date: 2026-09-11
- Scope: semantic reconstruction for the current positive fixtures
- Disposition: bootstrap semantic oracle; deliberately incomplete
- Authority: no admission, type-safety, resource, proof, or byte-freeze claim

## Result

The independent JavaScript checker reopens the decoded minimal module,
candidate-selection module, and two-module import bundle. For the constructs
actually used by those fixtures it:

- normalizes local and indexed imported type identities against exact decoded
  modules;
- reopens imported function signatures rather than trusting a copied summary;
- checks de Bruijn locals, record projection ownership, equality operands, call
  arguments/results, `FindUnique` blocks, kernel matches, rejection identity,
  and rejection precedence;
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

## Boundary of the result

The hostile cases deliberately mutate freshly decoded objects after structural
and digest validation. This isolates the semantic layer, but they are not yet
standalone hostile SCB-0 byte artifacts. The checker implements only the term
forms reached by the three current fixtures. In particular, it does not yet
cover record construction, variant payload fields, all intrinsic families,
arithmetic policies, pure branching, module ceilings, or profile ceilings.

The checker is ordinary unverified JavaScript. Agreement with hand-derived
fixtures is useful design feedback, not evidence that the checker or the draft
cost algebra is correct.

## Conclusion

The current type identity and resource recurrence survive their first composed
implementation test. The next useful work is to extend coverage one semantic
family at a time, with a positive source fixture and byte-level hostile vectors
for each family, before translating the frozen rules into Lean.
