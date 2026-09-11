# Typed-core v0 draft 0.2 review

- Date: 2026-09-11
- Scope: F1-A01/F1-A02 bootstrap review
- Disposition: coherent basis for the next specification pass; not ready to freeze
- Authority: no implementation, proof, native-binary, product, or production claim

## Findings resolved in draft 0.2

1. Intrinsic `Option` and `Result` constructors now participate in exhaustive
   matching through fully instantiated `ConstructorRef` values.
2. Modules now carry exports, required theorem obligations, and a closed claim
   ceiling explicitly.
3. Nominal identity domains are declarations distinct from data records; the
   candidate fixture uses `CandidateIdentity` rather than overloading `Candidate`.
4. Arithmetic policy is explicit on every core arithmetic node, with one stable
   `ArithmeticError` type and operation-specific result rules.
5. Parameter, block, and match binders have an explicit de Bruijn convention.
6. Canonical tables no longer repeat their keys inside declaration bodies.
7. Integer literals are mathematical typed values; physical bits belong to the
   later encoding and representation profiles.
8. Resource bounds are semantic quantities. Native stack and object-byte claims
   are deferred to the representation and C-refinement stages.
9. Kernel rejection precedence is represented at every rejection site and
   checked structurally on each executable continuation path.
10. The surface example, PEG, and abstract fixture now express the same
    `findUnique` result and rejection behavior.
11. Variant tag zero is not rejected without a profile rule that reserves it.
12. Variant record payloads now have an internal type and payload-owned field
    references; constructor shape determines whether an arm binds a payload.

## Controlled open findings

These block a typed-core or language freeze, but not further bootstrap design:

1. Select the canonical wire encoding and specify the one normal form for every
   digest-bearing derivation witness.
2. Define the exact compositional algebra for steps, live-value bits,
   evaluator-control depth, and abstract workspace bits.
3. Finish the signatures and evaluation/cost rules for every admitted bounded
   collection intrinsic; decide whether `countWhere` belongs in v0.
4. Freeze declared-variant construction and payload-pattern surface syntax.
5. Freeze checked arithmetic conversion and result-propagation surface syntax.
6. Specify export/import visibility, imported theorem reopening, and claim
   compatibility rules in admission detail.
7. Assign stable admission-reason tags only after the encoding schema is chosen.

## Review conclusion

No known contradiction remains among the module model, candidate-selection
fixture, surface example, and admission ordering at this abstraction level. The
next productive review is the F1-A04/F1-A06 binder and rejection pass, followed
by the F1-A05/F1-A07 arithmetic and resource-algebra pass. Encoding comparison
should use this draft but must not freeze it while the controlled findings remain.
