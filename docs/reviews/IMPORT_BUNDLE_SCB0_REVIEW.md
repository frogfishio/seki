# Import-bundle SCB-0 review

- Date: 2026-09-11
- Scope: nested module envelopes, imported references, exports, and import DAG
- Disposition: experimental bundle and hostile vectors pass
- Authority: no admission, type-safety, resource, or byte-freeze claim

## Result

The fixture contains a base module exporting record `Token` and pure function
`keep`, plus a consumer exporting `forward` and `twice`. It exercises one exact
import, imported type and function references, exported declaration checks, a
local call edge, a nonempty function schedule, nested module envelopes, and root
closure.

The bundle is 864 bytes. Its two module digests are recomputed from nested exact
envelopes, and fifteen hostile mutations produce their assigned rejection
pairs, including exact-digest graphs above the profile edge and depth ceilings.

## Findings

1. Repeating module identity and digest in every imported reference was needless.
   Canonical import-table indices reduced the consumer to 514 bytes, roughly a
   56% reduction from the original repeated-identity design.
2. `imported_declaration_wrong_kind` was unreachable because imported domain,
   type, and function references are distinct tagged schemas. The provisional
   reason was removed.
3. Import cycles must be detected from the identity graph before digest equality.
   Otherwise an ordinary hostile cycle cannot reach the cycle reason without
   solving a cryptographic fixed-point problem.
4. A bundle-wide transport digest is unnecessary for semantic identity. Exact
   root identity plus its module digest recursively binds the admitted closure.

## Remaining gaps

- The bundle has one experimental JavaScript emitter, although its bytes are
  independently parsed and its module hashes have fixed external fingerprints.
- Imported signatures and the expression forms reached by this fixture are now
  independently reopened by the experimental typed-core checker; full language
  coverage remains open.
- Resource tuples are now independently reconstructed for this fixture, but the
  checker is unverified and the recurrence remains a draft.
- Additional export substitution cases need hostile coverage.

## Conclusion

The simple module system remains a bounded digest-bound graph, not a resolver.
The composition test materially reduced the reference schema and made cycle
failure deterministic. The first syntax-directed type and resource pass now
accepts this fixture; the next step is systematic semantic-family coverage and
byte-level hostile cases.
