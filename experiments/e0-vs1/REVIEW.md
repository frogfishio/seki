# E0-VS1 closeout review

- Decision: continue the architecture; do not expand the language surface yet
- Status: accepted experimental closeout; no implementation or proof authority
- Date: 2026-09-19

## Question

Did the first vertical slice justify expansion, require redesign, or show that
Seki should stop?

## Decision

E0-VS1 justifies continuing Seki's architecture. It does not justify starting
F1, freezing syntax or encodings, or adding language features.

The experiment is closed as a successful feasibility result. Work returns to
global F0 and the bootstrap foundation locks. The next program-level pressure
should come from the materially different F0 consumer case, not from making the
minimum-age example larger.

## Why continuation is justified

The slice exercised the intended separation rather than bypassing it:

1. humans supplied a complete policy and exact source;
2. the source frontend produced one exact typed-core artifact;
3. Lean consumed that artifact and checked the independently stated policy;
4. a separate backend reopened the artifact and constructed restricted C; and
5. native execution agreed with the policy for the complete admitted domain.

The typed-core artifact successfully served as the common semantic checkpoint.
The proof path and C path did not share the frontend's in-memory representation,
and a source mutation propagated observably through both. This is the central
architectural proposition E0 was meant to test.

The effort also remained small enough to audit. The generated kernel is 524 C
bytes; the policy domain has 256 values; the exact Seki cost is `(8,25,5,0)`.
The size of the handwritten experimental decoders is a warning about proof and
maintenance cost, but not evidence that the semantic architecture is unsound.

## Why unrestricted expansion is rejected

E0 used one record, one payload-free rejection, one `U8` comparison, and one
conditional. Its components intentionally recognize only that shape. It gives
no empirical basis for freezing the broader surface, module system, complete
typed-core tag set, ABI, or C profile.

Expanding the example now would mostly reward the assumptions already embedded
in it. The global F0 requirement exists specifically to obtain pressure from a
materially different customer decision. That is more valuable than adding
features to satisfy the founding lineage's first slice.

The principal assurance gap also remains exactly where expected: no theorem
connects typed-core semantics to restricted-C/Clight behavior. Adding more
syntax before addressing foundation identities and the refinement plan would
increase the future proof surface without increasing authority.

## Redesign findings

No foundational redesign is required, but four interfaces need to remain firm:

- A complete policy must include required accepting behavior as well as safety;
  otherwise reject-everything can satisfy a vacuous theorem.
- The authority-bearing typed-core bytes must be independently reopened by each
  proof or generation path; sharing an earlier mutable AST weakens the binding.
- Encoded-file identity, decoded-byte identity, semantic module identity, and
  generated-source identity are different facts and must remain distinct.
- Proof evidence and native execution evidence must remain separate until the
  Clight refinement and qualified invocation path connect them.

The experiment also confirms that generated C should stay boring: explicit
fixed-width fields, direct control flow, deterministic printing, no runtime,
and no attempt to disguise C with clever abstractions.

## Authorized next work

This closeout authorizes no F1 implementation work. The next active work package
is F0-01: select the materially different consumer decision and reviewer. In
parallel, already-planned bootstrap work may bind the Lean and Rocq foundations
and resolve the CompCert acquisition/use profile.

A second end-to-end slice should begin only when it exercises the selected F0
case or when a separately recorded decision explains why another experiment is
needed. It should reuse the artifact boundary but may replace every E0 parser,
decoder, AST, ABI, and printer detail.

## Final disposition

- Stop Seki: **no**. The experiment demonstrated the intended value chain.
- Redesign the core architecture: **no**. Preserve the typed-core checkpoint
  and independent consumers; retain the four interface findings above.
- Expand immediately: **no**. Do not grow syntax or typed core from this case.
- Continue under the delivery gates: **yes**. Close E0-VS1 and resume at F0-01.

All E0 evidence remains experimental. Global F0 is open, F1 is unauthorized,
and implementation, proof, native-binary, product, and production authority
remain false.
