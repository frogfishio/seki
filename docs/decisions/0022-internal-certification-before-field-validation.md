# ADR 0022: Internally certify the release candidate before field validation

- Status: accepted for bootstrap and pre-live delivery
- Date: 2026-09-19

## Context

Seki will not have external reviewers during early implementation. Gnosis, Kiku,
Grit, and other prospective users can provide much better feedback after Seki is
complete enough to use on real critical components. Requiring continuing design
review from those projects would create coordination cost without producing
representative evidence.

The project nevertheless needs a disciplined standard while it works alone. A
compiler that merely passes its author's examples is not ready to be handed to
customers, even experimentally.

## Decision

Seki will develop autonomously through an internally certified release candidate.
For this project, **internal certification** means a checksum-bound self-attestation
that the exact release-candidate artifacts satisfy the project's own declared
specification, proof, test, reproducibility, trust-report, and packaging gates.

Internal certification is not independent certification and must never be
described that way. It establishes what the project itself has checked and which
premises remain trusted. It does not establish market fitness or production
acceptance.

After internal certification, and before any live or production declaration,
the release candidate enters field validation. Gnosis, Kiku, and Grit will use
it on representative real work—"in anger"—and report integration failures,
missing expressivity, misleading diagnostics, performance problems, and trust or
evidence gaps. Those projects remain ordinary customers, not Seki's governing
authorities.

The sequence is therefore:

```text
implementation and internal evidence
  -> internally certified release candidate
  -> customer field validation on real workloads
  -> controlled findings and corrections
  -> final pre-live acceptance decision
  -> live eligibility
```

Global F0 remains open throughout autonomous development. Its external evidence
is gathered from field validation rather than speculative pre-implementation
review. Formal phase labels and authority claims remain governed by their exact
gates; bootstrap work must not silently claim independent validation.

## Required internal attestation

The self-attestation must bind at least:

- exact source, compiler, formal model, proofs, generated artifacts, and manifests;
- the supported language/profile and every explicit exclusion;
- complete positive, boundary, hostile, differential, sanitizer, and
  reproducibility results required by the selected profile;
- every trusted component and every unproved pipeline arrow;
- the clean-room build and installed-tool identities; and
- a signed or otherwise identity-bound project decision naming the exact bytes.

A failed or incomplete item prevents internal certification. It is not converted
into a prose exception after the fact.

## Field-validation gate

Field validation must use the internally certified bytes, or record every change
as a new candidate requiring a new self-attestation. At least one materially
different consumer case must exercise the compiler and generated artifacts, not
merely review documents. Findings return to implementation and invalidate the
affected attestation until resolved.

Going live requires a separate recorded decision after field findings are closed.
Silence, lack of bug reports, or successful demos do not constitute acceptance.

