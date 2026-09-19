# E0-VS1 minimum-age vertical slice

- Status: E0-01 experiment contract; no qualification authority
- Date: 2026-09-19
- Governing decision: `docs/decisions/0020-experimental-end-to-end-vertical-slice.md`
- Source: `minimum_age.seki`

## Purpose

This experiment is the smallest end-to-end test of Seki's intended value:

```text
human-reviewed policy
  -> exact Seki source
  -> exact typed-core program
  -> Lean property proof over that program
  -> restricted C
  -> execution evidence
```

E0-01 fixes the first two items. E0-02/E0-03 bind the exact experimental
typed-core bytes to the Lean evaluator and property proof. E0-04/E0-05 bind the
source text to those same bytes through a closed-subset C11 frontend. Later E0
tasks must bind the restricted-C arrow and state which arrows remain unproved.

## Human policy

The complete policy is:

> An applicant whose age is less than 18 is rejected as `Underage`. An
> applicant whose age is at least 18 is approved.

The second sentence is necessary. The safety statement “no applicant younger
than 18 is approved” alone would also be satisfied by a useless implementation
that rejects everyone.

The policy owner supplies these boundary observations independently of the
implementation:

| Input age | Required result |
| ---: | --- |
| 0 | `Reject Underage` |
| 17 | `Reject Underage` |
| 18 | `Accept Unit` |
| 19 | `Accept Unit` |
| 255 | `Accept Unit` |

These examples help humans validate the threshold and direction. They are not
the universal proof.

## Closed input and result schema

```text
Applicant := { age : U8 }
Rejection := Underage@1
Result    := Decision[Unit, Rejection]
```

The admitted age domain is exactly `0..255`. Missing, negative, fractional,
textual, calendar-derived, or larger values do not cross this kernel boundary.
Any host adapter that constructs `Applicant` is outside this experiment and
must eventually establish that its source value has the stated meaning and
representation.

## Independent Lean property

E0-02 will give the notation below exact Lean names. The property is fixed now
independently of the implementation machinery:

```text
MinimumAgePolicy(run) :=
  forall applicant : Applicant,
    if applicant.age < 18 then
      run(applicant) = Reject(Underage)
    else
      run(applicant) = Accept(Unit)
```

The exact program obligation will have the shape:

```text
MinimumAgePolicy(
  evaluateKernel(
    decodeExactTypedCore(exact_e0_vs1_typed_core_bytes),
    decide))
```

The typed-core bytes must be decoded by the Lean-side decoder. The program may
not be manually re-entered as a second Lean function merely to make the theorem
easy to prove.

Two named consequences should be exported for review:

```text
NoMinorApproved:
  forall applicant, applicant.age < 18 ->
    run(applicant) != Accept(Unit)

AdultApproved:
  forall applicant, applicant.age >= 18 ->
    run(applicant) = Accept(Unit)
```

`AdultApproved` prevents the principal safety theorem from succeeding
vacuously through universal rejection.

## Candidate source behavior

The exact experimental source implements the threshold directly:

```text
(applicant age) < 18
  ifTrue:  [ reject Rejection::Underage ]
  ifFalse: [ accept unit ]
```

It uses one record field projection, one context-typed `U8` literal, one
comparison, one pure conditional, and the two kernel-tail constructors.

The module requests only the experimental claim ceilings needed to exercise the
path: semantic evaluation, Lean projection, and restricted-C source. Listing a
claim does not establish it. Publication is explicitly disabled.

## Deliberate exclusions

This experiment does not include or claim:

- imports, modules beyond the single source unit, generics, vectors, arrays,
  allocation, recursion, calls, matching, arithmetic beyond comparison, or
  external effects;
- calculation of age from a birth date, calendar, clock, jurisdiction, missing
  data, exceptions, overrides, identity, or application workflow;
- correctness of the policy as law, ethics, or business intent;
- correctness of a host-to-`Applicant` adapter or an output consumer;
- Clight refinement, CompCert compilation, GCC/Clang correctness, ABI
  correctness, or native-binary correctness; or
- frozen Seki syntax, diagnostics, typed-core bytes, resource costs, or backend
  representation.

An implementation inconvenience is not permission to add one of these features
to Seki v0.

## E0-01 exit record

E0-01 is complete when this document and `minimum_age.seki` are reviewed, the
exact source digest is bound by `CONTRACT.json`, and repository checks pass.
E0-02 then owns the minimum Lean decoder/evaluator needed to state the property
over the exact typed-core artifact.

The E0-01 source identity is:

```text
SHA-256 359ab794bc27125e2eefb80c435df1e031d119c9cedf057749e30fd13cba0a0e
```

The current experimental typed-core identity is:

```text
SCB-0 bytes 417
module SHA-256 0ff1f489e9a20e7c09e60b079db62971318586129399a3c6fb119e54e36ddc9b
exact bounds 8 steps, 25 live bits, depth 5, workspace 0
```

The module digest is domain-separated according to the SCB-0 draft. The
JavaScript emitter, generic JavaScript decoder/type checker, recorded hex bytes,
vector manifest, and fixture-bounded Lean decoder agree on this artifact.

## Experimental source frontend

`src/e0/sekic_e0.c` is a deliberately disposable C11 frontend for this closed
slice. It is not a claim that the Seki grammar or compiler architecture is
frozen. It accepts the exact experiment schema and kernel forms, checks the
`U8` threshold and declared resource ceilings, then emits SCB-0 from the parsed
values. The emitted bytes are not selected by source-file digest or copied from
the recorded fixture.

`make check-e0-frontend` compiles the frontend under the project's strict C11
warning set, reproduces the artifact twice, compares it byte-for-byte with both
the recorded vector and the independent JavaScript emitter, reopens it through
the generic decoder/type checker, and exercises a source-derived threshold
change. It also rejects six hostile mutations: an out-of-range threshold, wrong
field type, insufficient step bound, wrong true branch, trailing declaration,
and unsupported character. Failed parses create no output file.

This establishes deterministic experimental evidence for the source-to-SCB
arrow. It does not prove the C frontend correct, establish general language
conformance, or add the still-missing SCB-to-restricted-C refinement.

The contract and this review record will receive complete artifact identities
in the non-self-referential E0-08 manifest.
