# Semantic coverage audit v0

- Date: 2026-09-11
- Ledger: `spec/typed-core/SEMANTIC_COVERAGE_V0.json`
- Check: `node tools/encoding/check_semantic_coverage.mjs`
- Authority: bootstrap evidence only

## Result

The SCB-0 schema currently contains 69 tagged semantic forms: 23 types, four
declaration bodies, 36 pure terms, and six kernel-control terms. The checked
ledger records positive fixture evidence for 58 forms and eleven explicit gaps.

All six kernel-control terms now have positive evidence. The pure-term gaps are
`BytesLit`, `NotEqual`, `Not`, and `OrElse`. The declaration gap is `Alias`. The
type gaps are `U8`, `U16`, `I8`, `I16`, `Bytes`, and `Digest`.

These gaps are evidence gaps, not necessarily implementation gaps: several rules
share implemented code paths with covered forms. They remain explicit because a
branch without a positive canonical fixture can regress silently.

## Rule-level gaps

Tagged-node coverage does not establish admission completeness. Seven larger
rule families remain open:

1. type parameter and profile well-formedness;
2. equality-admitting type classification;
3. checked natural arithmetic during derivation;
4. declared module ceilings;
5. hard profile ceilings;
6. bundle import-edge and dependency-depth ceilings; and
7. publication declaration coupling.

The ledger checker freezes the inventory shape and tag/name correspondence. It
will fail when a schema tag is omitted, reordered, or silently renamed. It does
not certify that a named fixture is sufficient evidence for the associated rule.

## Next closure order

Close the small positive-form gaps first with one compact fixture, then implement
module/profile and bundle graph ceilings. Checked-natural overflow should be
introduced with the ceiling pass so arithmetic failures have one deliberate
precedence rather than scattered JavaScript-number behavior.
