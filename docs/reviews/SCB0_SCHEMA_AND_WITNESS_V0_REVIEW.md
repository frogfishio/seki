# SCB-0 schema and witness review

- Date: 2026-09-11
- Scope: first complete authority-shape and derivation-normal-form pass
- Disposition: coherent bootstrap candidate; vectors and proofs still required
- Authority: no byte freeze, implementation, admission, or proof claim

## Coverage result

The ledger now assigns positional fields or local discriminants to every current
authority-bearing v0 shape:

- 22 `Type` cases and four type-declaration cases;
- 33 pure `Term` cases and six tail `KernelExpr` cases;
- all reference, constructor-owner, arithmetic-policy, comparison, integer, and
  shift sums;
- module identity, imports, exports, claims, theorem requirements, declarations,
  resource bounds, and derivation fields; and
- the closed `ArithmeticError` constructor set omitted in the initial ledger
  pass.

Diagnostic sidecars are intentionally excluded because they cannot change
admission or semantic identity.

## Derivation result

V0 has one defensible normal form without inventing a proof-object language.
Term discriminants select typing rules; de Bruijn structure selects environments;
the AST supplies the resource recurrence tree; exact stored types and bounds are
the proposed conclusions. The only explicit schedules are unique least
topological orders for local types and local pure functions.

This is materially smaller than serializing rule names, premise links, copied
contexts, and intermediate cost tuples. Admission still checks every judgment;
omitted data are reconstructed, not trusted.

## Canonicality result

The candidate now has:

- fixed `U8` local sum tags;
- fixed big-endian `U32` naturals and sizes;
- structural typed-key ordering rather than encoded-byte ordering;
- a fixed module/bundle envelope candidate;
- fixed-length SHA-256 identities and explicit module-domain separation; and
- structured two-octet admission reasons preserving validation precedence.

## Controlled findings

1. The full encoder/decoder pseudocode must still resolve every recursive field
   boundary and reject before profile-unsafe allocation.
2. The resource algebra needs a formal context-sensitive recurrence before the
   reconstruction witness can be proved complete.
3. Every provisional admission reason needs an input that selects it, including
   competing-error precedence tests.
4. The empty smallest module must establish whether zero-field singleton values
   and empty tables are handled identically by independent encoders.
5. At least two implementations must agree on module, bundle, and digest bytes
   before any assignment freezes.
6. The experimental decoder must grow from structural reopening into independent
   type and resource recomputation over the composed fixtures.

## Conclusion

No uncovered tagged sum or positional authority record is known in typed-core
revision 0.3. The specification is ready for experimental vector construction,
not for a canonical-byte or verified-decoder claim.
