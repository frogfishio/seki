# Seki v0.3 Kiku F0 acceptance

Status: accepted by Kiku for F0 review

Decision:

```text
accepted_seki_v0_3_for_f0
```

Kiku accepts the Seki v0.3 charter at Gnosis commit
`65692f383d31b2d50d694f68133be578528b0710`.

Kiku explicitly accepts:

- universal generated-Clight-to-Rocq refinement over admitted modules and
  inputs;
- invocation-scoped Rocq-to-normative-Lean equality through one exact joint
  SSDC-1 receipt;
- generated-C-to-normative-Lean equality only for that jointly certified
  invocation;
- zero Lean-equivalence claim and zero authority publication without the exact
  joint receipt;
- distinct Lean and Rocq checker acceptances;
- certificate-gated Profile-C publication;
- API-level confinement premises;
- generated private state or a separately refined registry for token
  linearity; and
- the complete stated v0 trust and claim ceiling.

The accepted specification is
[`SEKI_V0_SPEC.md`](SEKI_V0_SPEC.md), and its machine contract is
[`SEKI_V0_3_REVIEW.json`](SEKI_V0_3_REVIEW.json).

This decision closes Kiku's F0 review only. It grants no implementation,
proof, product, native-binary, Arena-vertical or production authority.

The Seki charter independently requires acceptance from at least one
materially different prospective consumer before global F0 closure. Until
SIRCC, Tenkan or another qualifying consumer returns that decision, the exact
programme state is:

```text
kiku_f0_review=accepted
independent_consumer_f0_review=pending
global_f0=open
```

