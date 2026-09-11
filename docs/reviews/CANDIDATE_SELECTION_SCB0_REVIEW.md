# Candidate-selection SCB-0 lowering review

- Date: 2026-09-11
- Scope: first composed typed-core and SCB-0 fixture
- Disposition: independent emitter agreement; not admitted or frozen
- Authority: experimental specification evidence only

## Findings resolved

1. Canonical declaration order gives type indices `Candidate=0`,
   `CandidateId=1`, `Epoch=2`, `Input=3`, and `Rejection=4`.
2. The unique least type dependency order is `[1,2,0,3,4]`, which differs from
   declaration order and exercises the reconstruction witness.
3. Result match arms serialize as `Ok(0), Error(1)`, independently of explanatory
   source order. Option arms serialize as `None(0), Some(1)`.
4. The innermost binder environment is exactly `candidate, option, selection,
   input`, confirming `Local[3]` for the original input.
5. The original 4,096-bit live-value ceiling was invalid. The input alone is
   6,374 bits; the canonical schedule reaches 19,379 bits. The source ceiling is
   corrected to 32,768.
6. The source omitted an explicit module ceiling while typed core requires one.
   The draft `c11_bounded @ 1` profile now specifies deterministic elaboration
   defaults and hard maxima.

## Independent result

The manually structured C11 and JavaScript emitters agree on all 1,025 bytes.
Node and OpenSSL agree on the domain-separated module digest:

```text
c3b30493bec34d241bf50298078ced60ca0c9586a42936bcf12ebc7203a81439
```

This exercises declarations, nominal identity, records, variants, built-in
parameterized types, field and constructor references, blocks, bounded traversal,
nested matches, tail kernel control, rejection order, exports, theorem/claim
sets, resource tuples, and dependency schedules.

## Remaining authority gaps

- Neither emitter is an admission decoder; shared misunderstanding remains
  possible even with independent bytes.
- The resource recurrence is specified in executable order but not mechanized or
  proved.
- The semantic profile identity and ceilings remain bootstrap choices.
- Hostile mutations and authoritative rejection pairs are not yet generated.
- The vector is not evidence of C generation or semantic equivalence.

## Conclusion

The first serious composition test found two specification defects and fixed
both rather than encoding around them. No additional missing SCB-0 field or sum
case appeared. The independent decoder and targeted mutations were completed in
the following work package; no larger local-only positive fixture was needed.
