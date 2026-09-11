# Semantic coverage audit v0

- Date: 2026-09-11
- Ledger: `spec/typed-core/SEMANTIC_COVERAGE_V0.json`
- Check: `node tools/encoding/check_semantic_coverage.mjs`
- Authority: bootstrap evidence only

## Result

The SCB-0 schema currently contains 69 tagged semantic forms: 23 types, four
declaration bodies, 36 pure terms, and six kernel-control terms. The checked
ledger now records positive fixture evidence for all 69 forms and no tagged-form
gaps.

The closure fixture added `BytesLit`, `NotEqual`, `Not`, `OrElse`, `Alias`, `U8`,
`U16`, `I8`, `I16`, `Bytes`, and `Digest`. All six kernel-control terms were
already covered.

The former gaps were evidence gaps rather than newly implemented language
features: several shared code paths already existed. Recording and closing them
still matters because a branch without a positive canonical fixture can regress
silently.

## Rule-level gaps

Tagged-node coverage does not establish admission completeness. Five larger
rule families remain open:

1. type parameter and profile well-formedness;
2. equality-admitting type classification;
3. checked natural arithmetic during derivation;
4. source-input byte ceiling binding;
5. publication declaration coupling.

The ledger checker freezes the inventory shape and tag/name correspondence. It
will fail when a schema tag is omitted, reordered, or silently renamed. It does
not certify that a named fixture is sufficient evidence for the associated rule.

## Next closure order

The small positive-form gaps are closed. Declared module/profile tuple checks now
cover bytes, imports, declaration counts, callable resource ceilings, and profile
maxima. Expression-node, nesting, and reopened callable-depth observations now
have explicit recurrences and hostile cases. Bundle edge and dependency-depth
ceilings now have constructive byte-level vectors. Checked-natural overflow is
next so
arithmetic failures have one deliberate precedence.
