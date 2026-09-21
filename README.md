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
`Option[T]` and `Array[T,N]` are fixed language schemas. Source modules use
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

Bootstrap experiment `E0-VS1` exercised one complete
source-to-Lean-property-to-restricted-C path and is now closed as successful
feasibility evidence. It remains explicitly experimental: global F0 is open,
F1 is not authorized, and successful execution does not certify the generated C. See
[`ADR 0020`](docs/decisions/0020-experimental-end-to-end-vertical-slice.md).

The project is now building `A0`, a provisional usable alpha. Development and
evidence gathering proceed autonomously through a checksum-bound internal
release-candidate attestation. Gnosis, Kiku, and Grit then use those exact bytes
on representative real work before any live decision. This internal certification
is a self-attestation, never an independent-certification claim. A0 must compile
both the minimum-age and Grit publication kernels through one general `sekic`
CLI, but it does not freeze the language, authorize F1, or carry production
authority. See
[`A0 scope`](docs/alpha/A0_SCOPE.md) and
[`ADR 0021`](docs/decisions/0021-build-usable-alpha-before-f0-review.md) and
[`ADR 0022`](docs/decisions/0022-internal-certification-before-field-validation.md).

Repository bootstrap B0 is complete. Its portfolio passes locally, and passed
once in the immutable Linux/amd64 environment recorded by
[`toolchains/CLEAN_ROOM.json`](toolchains/CLEAN_ROOM.json) before the hosted
workflow was removed. There is no continuous integration: `make check` is run
by hand. This verifies the bootstrap repository; it does not install or qualify
the formal foundations.

[`VISION.md`](VISION.md) states what Seki is for, how its assurance is meant
to work, and — separately — what is true today.

A consumer starts with
[`docs/alpha/QUICKSTART.md`](docs/alpha/QUICKSTART.md) and
[`docs/alpha/HOST_BOUNDARY_CONTRACT.md`](docs/alpha/HOST_BOUNDARY_CONTRACT.md).

Current bootstrap records:

- [`PLAN.md`](PLAN.md) — controlled delivery plan and handoff entry point
- [`alpha/ALPHA_PLAN.json`](alpha/ALPHA_PLAN.json) — checked A0 work ledger
- [`PROJECT_STATUS.json`](PROJECT_STATUS.json) — machine-enforced claim ceiling
- [`docs/architecture/TYPED_CORE_BOUNDARY.md`](docs/architecture/TYPED_CORE_BOUNDARY.md)
  — first semantic slice and serialization freeze criteria
- [`foundations/FOUNDATION_LOCK.json`](foundations/FOUNDATION_LOCK.json)
  — exact Lean, Rocq, and CompCert source/archive and license identities
- [`docs/foundations/FORMAL_FOUNDATION_ACQUISITION.md`](docs/foundations/FORMAL_FOUNDATION_ACQUISITION.md)
  — non-vendoring acquisition policy and qualification limits
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
- [`spec/typed-core/fixtures/CONSTRUCTION_ACCESS_LOWERING_V0.md`](spec/typed-core/fixtures/CONSTRUCTION_ACCESS_LOWERING_V0.md)
  — value construction and constant-time array access fixture
- [`spec/typed-core/fixtures/TRAVERSAL_LOWERING_V0.md`](spec/typed-core/fixtures/TRAVERSAL_LOWERING_V0.md)
  — static-length array traversal and intrinsic-workspace fixture
- [`docs/reviews/SEMANTIC_COVERAGE_AUDIT_V0.md`](docs/reviews/SEMANTIC_COVERAGE_AUDIT_V0.md)
  — checked tagged-form coverage and explicit rule-gap inventory
- [`spec/typed-core/fixtures/COVERAGE_GAPS_LOWERING_V0.md`](spec/typed-core/fixtures/COVERAGE_GAPS_LOWERING_V0.md)
  — compact closure fixture giving every tagged form positive evidence
- [`docs/reviews/EXPERIMENTAL_TYPED_CORE_CHECKER_REVIEW.md`](docs/reviews/EXPERIMENTAL_TYPED_CORE_CHECKER_REVIEW.md)
  — first fixture-bounded type and exact-resource reconstruction pass
- [`docs/f0/INDEPENDENT_USE_CASE_REQUEST.md`](docs/f0/INDEPENDENT_USE_CASE_REQUEST.md)
  — materially different use-case review
- [`docs/f0/GRIT_STAGE1_PUBLICATION_CANDIDATE.md`](docs/f0/GRIT_STAGE1_PUBLICATION_CANDIDATE.md)
  — selected F0 candidate; field validation deferred until release candidate
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
C, proofs, manifests, and certificates under terms of their choice. Seki-owned
material included in Generated Output carries the project-owned
[`Seki Generated Output Exception 1.0`](SEKI_OUTPUT_EXCEPTION), a GPLv3 section
7 additional permission. Standalone compiler, runtime, library, and third-party
material retain their applicable licenses.
