# ADR 0005: Portable C11 bootstrap and selective dogfooding

- Status: accepted
- Date: 2026-09-11

## Decision

The bootstrap Seki compiler and command-line tooling will be implemented in
portable ISO C11. The objective is stable, conservative, auditable C—not novel
or stylistically ambitious C.

Seki is not intended to implement the entire compiler application. Host-facing
orchestration remains ordinary C. Pure, bounded, authority-relevant components
will be isolated behind explicit interfaces so they can later be reimplemented
in Seki and replaced with Seki-generated C after the relevant compiler and proof
stages are qualified.

## Initial trust status

The handwritten C bootstrap is an untrusted proof producer. Its parser,
elaborator, serializer, and generated artifacts do not gain authority from being
written in C or from later reaching a self-hosting fixed point. Canonical inputs
and claimed derivations must be reopened by the qualified admission and proof
checkers.

Self-hosting is evidence for usability, determinism, and reproducibility. It is
not by itself a proof premise.

## Component boundary

Ordinary C remains appropriate for:

- command-line processing and human diagnostics;
- filesystem and process interaction;
- dependency and toolchain discovery;
- build-directory and artifact orchestration; and
- platform integration outside the semantic kernel.

Candidates for later Seki implementation include:

- canonical decoding and structural validation;
- duplicate and unknown-field rejection;
- type, nominal-identity, import, and bound checks;
- deterministic rejection precedence;
- typed-core evaluation;
- manifest validation; and
- certificate, receipt, and digest binding.

## C engineering profile

Bootstrap code will prefer:

- ISO C11 without compiler-specific language extensions in authoritative paths;
- fixed-width integers and explicit checked conversions;
- byte slices with explicit lengths rather than semantic reliance on C strings;
- caller-owned bounded storage where practical;
- narrow interfaces and explicit ownership;
- no ambient mutable global state in semantic components;
- checked size arithmetic before allocation or indexing;
- warnings-as-errors builds with both GCC and Clang;
- sanitizer builds during development; and
- deterministic behavior independent of locale, address values, hash-table
  iteration, filesystem enumeration, and unspecified evaluation order.

Generated C and handwritten C will use compatible boundary conventions where
doing so does not prematurely freeze an unproved ABI.

## Consequences

The project does not optimize for expressing application-wide abstractions in
Seki. It optimizes for identifying small decisions whose correctness is worth
formalizing and embedding those decisions into otherwise ordinary systems.

