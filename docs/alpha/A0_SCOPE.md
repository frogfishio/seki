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

Revision `0.0.0-alpha.3` connects `check`, `build`, and `inspect` through an
in-process C API. The live frontend no longer invokes the E0 source parser: it
emits the exact E0 typed-core bytes from the alpha AST after the independent
checker succeeds. Restricted-C projection and inspection still use the E0
backend. Inspection reports both boundaries as `frontend=alpha-minimum-age` and
`backend=e0-vs1`. The CLI reports stable A0 diagnostics and refuses existing or
aliased output paths.

The replacement path has begun with `src/alpha/seki_lexer.c`: an allocation-free,
name-agnostic lexer for the candidate grammar. It handles CR, LF, and CRLF source,
comments, identifiers, checked `U32` literals, hexadecimal string bodies, and all
current punctuation/operator tokens. Its independent strict-C11 test covers 32
token observations and four hostile classes. The live alpha frontend consumes
this lexer directly.

`src/alpha/seki_parser.c` now uses that lexer on the live `check` and `build`
paths. It parses arbitrary lower-case module paths, module/profile versions,
claim ceilings, and theorem-obligation lists into fixed-capacity borrowed slices,
rejecting duplicate names and excessive path/list shapes. It also parses the
candidate `type`, `nominal`, `record`, and `variant` declarations, including
bounded byte and digest types, record fields, variant payload fields, explicit
tags, and duplicate rejection. The parser also recognizes an exported kernel's
complete envelope: labelled parameters, applied result type, arithmetic policy,
four resource ceilings, ordered rejection references, publication mode, and a
kernel body. The first tail-expression AST covers names, natural and Boolean
literals, `unit`, record-field projection, comparisons, `ifTrue:/ifFalse:`, and
terminal `accept`/`reject`. A separate allocation-free checker resolves kernel
parameters and record fields, checks comparison operands and Boolean conditions,
and relates terminal values and rejection constructors to `Decision[A, R]` and
the ordered rejection inventory. `src/alpha/seki_core.c` then constructs SCB-0
from that checked AST. It reproduces the 417-byte regression artifact exactly,
while a threshold mutation changes both core and projected C. The core emitter
still recognizes the minimum-age semantic shape and the visibly labelled E0
backend still performs restricted-C generation; this is not yet the complete A0
expression language or a general compiler core.

The live entry point requires end-of-file after the supported declarations.
Unknown declarations and trailing tokens fail as `A0-PARSE-0034`; no later
stage may silently ignore source text outside the constructed module AST.

Build and exercise the current increment with:

```sh
make alpha
build/sekic check experiments/e0-vs1/minimum_age.seki
build/sekic build --core /tmp/minimum_age.scb0 --c /tmp/minimum_age.c \
  experiments/e0-vs1/minimum_age.seki
build/sekic inspect /tmp/minimum_age.scb0
```

## Work packages

| ID | Deliverable | Exit evidence |
| --- | --- | --- |
| A0-01 | Scope and claim ceiling | This document, ADR 0021, and checked machine status agree. |
| A0-02 | Reusable compiler core | E0 program-shape assumptions are removed; one C11 library and CLI own parsing, checking, typed-core construction, and C projection. |
| A0-03 | Alpha subset | Positive and hostile tests cover each supported form; unsupported forms reject explicitly. |
| A0-04 | Grit kernel | Exact source, expected decisions, generated artifacts, and behavioral tests are checked in. |
| A0-05 | Deterministic bundle | Two clean builds reproduce bytes and a manifest binds compiler, inputs, outputs, commands, and claim ceiling. |
| A0-06 | Consumer documentation | A clean checkout can follow one quickstart without fixture-specific knowledge. |

## Exit and relationship to F0

A0 exits when both required examples pass the reproducible consumer quickstart
and the alpha trust report contains no unrecorded pipeline arrow. This creates a
usable compiler and authorizes entry into internal formal delivery work; it does
not internally certify a release candidate.

F1 through F5 subsequently freeze and prove the semantic, representation, C,
certificate, and installed-artifact layers. Only then does R0 issue the
checksum-bound internal release-candidate attestation. Gnosis, Kiku, and Grit
use that exact candidate in F6/F7 field validation before F0 closure and the F8
go-live decision.

A0 completion does not close F0 or make Seki live-eligible. It may authorize F1
through an atomic project-status update after the A0 exit evidence passes.
