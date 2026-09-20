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

Revision `0.0.0-alpha.6` connects `check`, `build`, and `inspect` through an
in-process C API. The live frontend no longer invokes the E0 source parser: it
emits the exact E0 typed-core bytes from the alpha AST after the independent
checker succeeds. The alpha backend independently decodes and fully validates
those bytes into a restricted-C model before printing C. Neither E0 adapter is
linked into the live compiler. Inspection reports both boundaries as
`frontend=alpha-u8-decision` and `backend=alpha-u8-decision`. The CLI reports
stable A0 diagnostics and refuses existing or aliased output paths.

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
and independent backend now recognize an identity-independent U8-decision shape:
arbitrary module, declaration, field, case, kernel, and parameter names; any of
the six comparison forms; an arbitrary U8 threshold; and an arbitrary U8-sized
rejection tag. A wholly renamed
`gate_policy` program now exercises two ordered U8 fields, two ordered rejection
cases, rejection tag 7, precedence index 1, and threshold 42. The emitter derives
the selected field/constructor indices and the 40-bit exact live bound. The
repository's separate general SCB decoder and semantic checker reopen and verify
that emitted artifact, and its generated C compiles strictly. The original
minimum-age artifacts remain byte-identical. Data shapes outside this slice fail closed; this is
not yet the complete A0 expression language or a general compiler core. The
remaining A0-02 work is the expression language itself: bindings, exhaustive
match, record and variant construction, and Boolean operations, together with
the general declaration parser.

Canonical ordering is now the compiler's responsibility rather than the
author's. Declarations, record fields, and variant cases are sorted by their
typed keys, and every emitted reference uses the resulting canonical position,
so a module whose source order differs from canonical order emits exactly the
same bytes. The derivation bundle records the greedy topological type order that
admission recomputes.

The checker is now an elaborator: it records one resolved type, environment
slot, field position, variant tag, and precedence index per expression node, and
typed-core construction is a recursive traversal that reads only that
elaboration. Exact resource bounds are derived from the published cost algebra
rather than a shape-specific formula, and a declared ceiling below the derived
exact bound is rejected as `A0-CHECK-0017`.

Recursive descent is bounded by the profile's `maximum_nesting` ceiling and
reports `A0-PARSE-0035` beyond it. This is a fail-closed host limit: source
mutation fuzzing under AddressSanitizer found two inputs inside the 64 KiB
source limit that could exhaust the host stack, and both are now pinned as
parser regressions.

Canonical positions follow the program's own identifiers in both directions.
The independent backend locates the record and variant by declaration kind
rather than assuming table positions zero and one, so a module whose variant
name sorts first compiles end to end. Theorem and claim vectors are validated
as strictly increasing vectors of known tags rather than as one fixed list, so
a module stating a different obligation set still projects to C.

### The two boundaries differ, deliberately

`check` validates source, static semantics, and typed-core construction.
`build` additionally requires the restricted-C projection, whose slice is
currently narrower. A module can therefore pass `check` and fail `build` with a
stable `A0-BACKEND-*` diagnostic and no output file. At revision
`0.0.0-alpha.6` the known case is payload-bearing variant cases. `inspect`
reports the two
boundaries as `frontend=alpha-decision` and `backend=alpha-decision`, and
reports `first_literal=<value>:<type>` when the kernel has an integer literal.

Alias and nominal declarations project to C typedefs, emitted in the module's
type dependency order so a typedef precedes its use. Nominals are not
substitutable even when they share a representation, and that distinction
survives into the generated C by construction: the projection resolves through
them when choosing a C form, so an octet identity behind a nominal is still
compared by content rather than by address.

A module may declare any number of records and variants. Each record becomes a
C struct in canonical order, a variant contributes no type of its own because
its cases are the `reason` octet of the decision result, and the kernel
signature selects the declarations it uses by position.

`name := expr.` binds one fresh immutable local whose scope is the rest of the
body. Bindings cannot shadow a visible local, and a binding has no type
annotation, so a bare integer literal has nothing to take its width from and is
rejected.

`require C else: V::Case.` states one premise and the rejection that reports
its failure, then continues. Several of them in sequence express a decision
whose premises are checked in declared precedence order.

Short-circuit `&&` and `||` are connected end to end, with `&&` binding tighter
and both associating to the left. Their operands must both be `Bool`; anything
else is rejected as `A0-CHECK-0018`.

`Bytes[N]` and `Digest[sha256, 32]` fields project to octet arrays. Their
equality projects to a comparison whose running time does not depend on where
the first differing octet lies, because these values are authenticated evidence
and artifact identities. Ordered comparison on an octet array is rejected by
the checker rather than given a C form.

Record fields carry their own unsigned width through both directions: `U8`,
`U16`, `U32`, and `U64` project to the matching exact-width C type, and integer
literals encode in exactly their type's octet count, most significant first.
Surface literals remain checked `U32`, so a `U64` field can be compared against
values up to 4294967295; a wider literal fails closed as `A0-LEX-0001`.

Closing that gap is A0-03 work, not a defect in either direction: both fail
closed, and `build` writes no artifact unless every stage succeeds.

### Kernel control nests

The C backend decodes a restricted-C expression and tail AST rather than
expecting one fixed byte sequence, so kernel control nests to the depth the
arena admits. A three-premise decision with ordered rejection precedence
compiles end to end; its exact bounds are independently reproduced by the
JavaScript cost algebra, and its generated C is exhaustively compared against
the policy it states.

The projection deliberately does not re-derive exact resource bounds. It checks
that the stored bounds are well formed and within the declared ceiling and
leaves exact-bound equality to admission, which owns the canonical cost
algebra. Carrying a second, weaker derivation here would produce a checker that
silently disagrees with the one that has authority.

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
