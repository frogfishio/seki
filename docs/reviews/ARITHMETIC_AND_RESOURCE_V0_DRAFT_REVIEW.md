# Arithmetic and resource-algebra review

- Date: 2026-09-11
- Scope: F1-A05/F1-A07 bootstrap review
- Disposition: coherent draft semantics; not frozen or proved
- Authority: no implementation, proof, C-refinement, or native-binary claim

## Arithmetic findings resolved

1. Shift counts now have one type (`U32`) instead of ambiguously sharing the
   shifted value's signedness and width.
2. Signed quotient and remainder rules are explicit and independent of the host.
3. Zero division, `min / -1`, and `min % -1` are defined for all three policies.
4. Signed right shift is mathematical rather than implementation-defined.
5. Unsigned negation is rejected statically.
6. Checked, wrapping, and saturating conversions share explicit mathematical
   range functions.
7. The surface and PEG now recognize unary negation and remainder while leaving
   shift, conversion, and propagation spellings open.

## Resource findings resolved

1. “Exact bound” now means the unique result of a canonical structural algebra,
   not an arbitrary conservative producer claim.
2. Semantic widths are defined for every v0 type without alignment or padding.
3. One abstract slot schedule determines live-value peaks and prevents checker
   implementations from choosing different liveness optimizations.
4. Logical steps and evaluator-control depth have fixed node/frame meanings.
5. Bounded collection signatures, traversal order, and capacity charging are
   explicit.
6. Intrinsic workspace is closed and separated from source-visible values and
   control frames.
7. Admission and host-tool resource use is explicitly outside the kernel
   execution tuple.

## Controlled open findings

- Mechanize the recurrence and prove it bounds the evaluator once F1 is
  authorized.
- Turn the abstract boundary fixtures into canonical encoded vectors for every
  width, policy, and exceptional arithmetic case after encoding selection.
- Validate that the deliberately conservative slot schedule remains practical on
  the first two customer kernels.
- Freeze surface syntax for shifts, conversions, and `Result` propagation.
- Prove concrete C storage and stack mappings only in F2/F3.

## Conclusion

The arithmetic relation is total and the resource tuple is now reproducible from
typed core alone. These drafts are suitable inputs to canonical-encoding
comparison, without claiming F1 completion.
