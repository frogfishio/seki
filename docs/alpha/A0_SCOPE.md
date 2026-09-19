# A0 provisional usable alpha

Status: active bootstrap scope; syntax and encoding are not frozen

## Purpose

A0 turns the successful E0 vertical slice into something a prospective consumer
can actually use. It is not F1 and carries no implementation, proof, product, or
production authority. Its output is suitable for evaluation only.

The usability test is concrete: a person unfamiliar with Seki's internal fixture
tools can build `sekic`, compile both supplied kernels, compile the emitted C with
a conservative C11 compiler, run the example tests, and understand every
diagnostic and trust limitation from the public documentation.

## Required programs

The alpha is not complete until one compiler handles both:

1. `minimum-age`: one `U8` record field and a threshold decision; and
2. `grit-stage1-publication`: nominal receipt and identity fields coordinated
   into one publication permit or a deterministic rejection.

The second program is deliberately not another threshold example. It supplies
the independent structural pressure needed before F0 review.

## Supported language subset

A0 implements only the following candidate surface forms:

- one module per source file, with explicit profile, claims, and obligations;
- `Bool`, `U8`, `U16`, `U32`, `U64`, `Bytes[N]`, and `Digest[sha256, 32]`;
- nominal aliases, non-recursive records, and payload-free or single-payload
  variants with explicit stable tags;
- concrete `Decision[Accepted, Rejection]` kernel results;
- exported kernels with explicit monomorphic parameters and resource ceilings;
- literals, immutable bindings, record construction, field projection, variant
  construction, equality, ordered integer comparison, Boolean operations,
  pure `If`, exhaustive pure `Match`, and final kernel decisions; and
- deterministic rejection precedence declared by the kernel.

A0 has no imports, user-defined generics, type inference, overloads, mutation,
pointers, allocation, recursion, effects, exceptions, unbounded loops, array
traversal, user-defined arithmetic policy, or implicit conversions. A required
form outside this list is a finding to evaluate, not permission to improvise a
feature.

## Compiler interface

The intended first interface is:

```text
sekic check INPUT.seki
sekic build --core OUTPUT.scb0 --c OUTPUT.c INPUT.seki
sekic inspect INPUT.scb0
sekic --version
```

Successful `build` writes neither output until parsing, type checking, bound
checking, and complete artifact construction succeed. Output bytes cannot depend
on the current directory, input path, locale, time, process identity, pointer
values, or filesystem enumeration order. Unsupported syntax and profiles fail
closed with a stable diagnostic identifier and nonzero status.

The CLI spelling is provisional. Alpha bundles record its exact revision and
invocation; scripts must not treat it as a stable public API.

The initial `0.0.0-alpha.1` shell implements `--help` and `--version`. The three
compiler commands deliberately return `A0-CLI-0002` and exit 69 until the
reusable compiler paths are connected. This fail-closed shell fixes the command
boundary without misrepresenting the E0 program-shaped tools as a general
compiler.

## Work packages

| ID | Deliverable | Exit evidence |
| --- | --- | --- |
| A0-01 | Scope and claim ceiling | This document, ADR 0021, and checked machine status agree. |
| A0-02 | Reusable compiler core | E0 program-shape assumptions are removed; one C11 library and CLI own parsing, checking, typed-core construction, and C projection. |
| A0-03 | Alpha subset | Positive and hostile tests cover each supported form; unsupported forms reject explicitly. |
| A0-04 | Grit kernel | Exact source, expected decisions, generated artifacts, and behavioral tests are checked in. |
| A0-05 | Deterministic bundle | Two clean builds reproduce bytes and a manifest binds compiler, inputs, outputs, commands, and claim ceiling. |
| A0-06 | Consumer documentation | A clean checkout can follow one quickstart without fixture-specific knowledge. |
| A0-07 | Internal certification | A checksum-bound self-attestation names the exact release-candidate bytes and all satisfied and trusted premises. |
| A0-08 | Field validation | Gnosis, Kiku, and Grit exercise the exact candidate on representative real workloads. |
| A0-09 | Finding closure | Findings are resolved and every affected candidate artifact is regenerated and re-attested. |
| A0-10 | Pre-live decision | F0 evidence and a separate go-live eligibility decision are checksum-bound. |

## Exit and relationship to F0

A0 development proceeds without external review through a release candidate.
The project internally certifies that exact candidate only after both required
examples pass the reproducible consumer quickstart, all selected proof and test
gates pass, and the trust report contains no unrecorded pipeline arrow. Here,
internal certification means a checksum-bound project self-attestation; it is
not independent certification.

The internally certified candidate is then used in anger by Gnosis, Kiku, and
Grit before any live declaration. Feedback may require replacement of any A0
interface or artifact; a changed candidate must repeat every affected internal
gate and receive a new attestation. The field-validation record supplies the
external F0 evidence.

A0 completion alone does not close F0, authorize F1, or make Seki live-eligible.
A separate pre-live decision follows successful field validation and closure of
its findings.
