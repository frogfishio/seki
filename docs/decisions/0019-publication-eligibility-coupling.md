# ADR 0019: Publication eligibility is explicitly coupled

- Status: accepted for bootstrap; not a language freeze
- Date: 2026-09-11

## Decision

A kernel may set `publication_eligible = true` only when its module both:

- includes `publication` in `claim_ceiling`; and
- includes `publication_equivalence` in `required_theorems`.

Admission rejects a missing half of this conjunction with
`0a0a invalid_publication_declaration`. The implication is intentionally
one-way: listing the claim or theorem does not force every kernel to be
publication-eligible.

Eligibility records intended downstream use only. It does not establish a
theorem, grant publication authority, emit a claim, or bypass the later
certificate and host publication protocol.

## Consequences

The `kernel-if-v0` fixture is the positive canonical example. Separate hostile
cases remove the claim and theorem requirement independently. This closes the
last broad semantic rule gap recorded by the experimental coverage ledger.
