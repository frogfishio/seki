# ADR 0020: Begin an experimental end-to-end vertical slice

- Status: accepted for bootstrap; no implementation or proof authority
- Date: 2026-09-19

## Context

The language, typed-core, encoding, and assurance drafts are now detailed enough
that further specification without implementation pressure has diminishing
value. The project also needs to demonstrate its central proposition on one
concrete program:

> A human-written Seki decision can be connected to an independently stated
> Lean property and emitted as restricted C without losing the decision's
> formal meaning.

Global F0 remains open. Its purpose is to prevent the project from freezing a
customer-specific language or making qualification claims before an independent
consumer has accepted the charter. It need not prohibit clearly labelled,
discardable implementation experiments.

## Decision

Seki authorizes bootstrap experiment `E0-VS1`, the first end-to-end vertical
slice. It may proceed while global F0 is open under all of these restrictions:

- it carries no implementation, proof, native-binary, product, or production
  authority;
- it cannot freeze source syntax, typed-core encoding, diagnostics, ABI, or a
  qualification profile;
- every artifact and test result is experimental evidence and may be replaced;
- it uses only the smallest existing candidate-language subset needed by the
  slice; and
- discoveries feed back into the owning draft or produce a recorded finding.

The slice is one bounded applicant decision with an independently stated
property equivalent to:

```text
No applicant younger than 18 can be approved.
```

The implementation boundary is deliberately small:

- one source module;
- fixed-width integers, Booleans, one input record, and one decision variant;
- field access, comparison, Boolean composition, pure `If`, and return;
- no imports, generics, vectors, allocation, recursion, external effects, or
  general application programming facilities.

The slice must connect the following exact artifacts:

```text
Seki source
  -> experimental C11 parser and syntax-directed checker
  -> canonical typed-core candidate
  -> Lean decoding/evaluation and program-property proof
  -> experimental restricted-C AST and canonical C bytes
  -> ordinary native compilation and behavioral tests
```

The Lean property proof and native tests establish different things. The proof
is about the exact typed-core program under the experimental Lean semantics.
The tests exercise the emitted C. Until the later Clight refinement closes,
the slice does not claim that Lean has proved the emitted C or native binary.

## Required evidence

`E0-VS1` is complete only when it has:

1. exact source, typed-core, theorem, generated-C, and manifest artifacts;
2. deterministic regeneration with recorded digests;
3. a Lean theorem applying the independent property to the exact decoded
   program rather than to a manually re-entered surrogate;
4. positive and hostile parser/type-checker cases around the supported subset;
5. boundary cases at ages 17, 18, and 19 plus broader behavioral comparison;
6. strict C11 compilation and sanitizer execution for the generated artifact;
7. an explicit list of unproved arrows and trusted tools; and
8. a review deciding whether the architecture earned expansion.

CompCert acquisition and the Rocq/Clight refinement are not prerequisites for
this bootstrap experiment. They remain required before the later generated-C
proof claims defined by F4.

## Consequences

Work now moves from schema expansion to an executable proof-oriented slice.
No new language feature is justified merely because the experiment encounters
an inconvenience. The preferred response is to simplify the example or expose
the missing semantic requirement.

F0 remains open, F1 remains unauthorized, and all project claim-ceiling fields
remain false. Successful completion demonstrates feasibility only; it does not
qualify a compiler or certify generated C.
