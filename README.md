# Seki / 関

Seki is a deliberately small, total language for critical decision kernels.
It is designed to provide a verified compiler that emits portable C together
with machine-checkable evidence that the generated program preserves the
kernel's formal semantics, making it suitable for proof-carrying systems.

Seki is not a general-purpose programming language. It is intended for small,
bounded validators, authority decisions, normalizers, and protocol transitions
embedded in larger systems.

The bootstrap compiler and host tooling are written in stable, portable C11.
Over time, eligible critical components can be rewritten in Seki and compiled
back to C. Filesystem access, process control, diagnostics, and other application
plumbing remain ordinary C; self-hosting is not a project goal by itself.

V0 deliberately avoids a general generic or package system. Typing is
syntax-directed over concrete monomorphic types; parameterized built-ins such as
`Option[T]` and `BoundedVec[T,N]` are fixed language schemas. Source modules use
exact versions and aliases, while generated committed `seki.lock` data binds the
canonical-core digests. The admission checker receives the complete bundle and
never searches a filesystem, registry, or network.

## Project lineage and ownership

Gnosis and Kiku jointly specified Seki from a shared need for small decision
kernels whose generated C implementations can be connected to formal
semantics. They are Seki's founding customers and continue to provide feedback.

Seki is now an independent project. Gnosis and Kiku have no special authority
over its language or implementation beyond their ordinary role as customers.
Their concepts may appear in design history, examples, and integration
libraries, but they do not define Seki's language core.

The current repository contains the v0.3 project seed and design charter. It
does not yet contain a verified compiler or grant implementation, proof,
native-binary, product, or production authority. Start with
[`SEKI_V0_3_PROJECT_SEED/START_HERE.md`](SEKI_V0_3_PROJECT_SEED/START_HERE.md).

Current bootstrap records:

- [`PLAN.md`](PLAN.md) — controlled delivery plan and handoff entry point
- [`PROJECT_STATUS.json`](PROJECT_STATUS.json) — machine-enforced claim ceiling
- [`docs/architecture/TYPED_CORE_BOUNDARY.md`](docs/architecture/TYPED_CORE_BOUNDARY.md)
  — first semantic slice and serialization freeze criteria
- [`spec/encoding/SEKI_CANONICAL_BINARY_V0_DRAFT.md`](spec/encoding/SEKI_CANONICAL_BINARY_V0_DRAFT.md)
  — provisional authority-bearing binary direction; bytes are not frozen
- [`spec/encoding/SCB0_SCHEMA_LEDGER.md`](spec/encoding/SCB0_SCHEMA_LEDGER.md)
  — provisional positional fields and discriminants
- [`spec/typed-core/DERIVATION_WITNESS_NORMAL_FORM_V0_DRAFT.md`](spec/typed-core/DERIVATION_WITNESS_NORMAL_FORM_V0_DRAFT.md)
  — canonical static derivations by deterministic reconstruction
- [`spec/typed-core/fixtures/CANDIDATE_SELECTION_LOWERING_V0.md`](spec/typed-core/fixtures/CANDIDATE_SELECTION_LOWERING_V0.md)
  — first complete experimental lowering and SCB-0 composition vector
- [`spec/typed-core/fixtures/IMPORT_BUNDLE_LOWERING_V0.md`](spec/typed-core/fixtures/IMPORT_BUNDLE_LOWERING_V0.md)
  — two-module digest-bound import and export fixture
- [`spec/typed-core/fixtures/PAYLOAD_RECORDS_LOWERING_V0.md`](spec/typed-core/fixtures/PAYLOAD_RECORDS_LOWERING_V0.md)
  — record construction, variant payload, binder, and pure-match fixture
- [`spec/typed-core/fixtures/ARITHMETIC_CONTROL_LOWERING_V0.md`](spec/typed-core/fixtures/ARITHMETIC_CONTROL_LOWERING_V0.md)
  — explicit arithmetic-policy and pure-control fixture
- [`docs/reviews/EXPERIMENTAL_TYPED_CORE_CHECKER_REVIEW.md`](docs/reviews/EXPERIMENTAL_TYPED_CORE_CHECKER_REVIEW.md)
  — first fixture-bounded type and exact-resource reconstruction pass
- [`docs/f0/INDEPENDENT_USE_CASE_REQUEST.md`](docs/f0/INDEPENDENT_USE_CASE_REQUEST.md)
  — materially different use-case review
- [`docs/governance/PROJECT_CHARTER.md`](docs/governance/PROJECT_CHARTER.md)
  — independence and customer relationship

## Name

`関` is read *seki* in Japanese and *guān* in Chinese. Its meanings include a
barrier or checkpoint, a mountain pass, a critical juncture, and a connection
or relationship. Those senses reflect Seki's role: a small semantic boundary
at which a consequential decision must be checked.

## Planned tooling

- Source extension: `.seki`
- Compiler: `sekic`

## License

Seki is free software licensed under
[`GPL-3.0-or-later`](LICENSE). Third-party foundations retain their own
licenses. Running `sekic` does not change the ownership or licensing of a
customer's module or generated artifacts. Customers may distribute generated
C, proofs, manifests, and certificates under terms of their choice. Any
Seki-owned runtime or template material included in an output will carry an
explicit GCC-style runtime exception; that legal text must be adopted before
such material is distributed.
