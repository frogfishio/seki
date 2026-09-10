# Seki v0.3 independent-consumer F0 review request

Status: ready for SIRCC, Tenkan or another materially distinct consumer

Kiku has returned `accepted_seki_v0_3_for_f0` for the exact Seki charter at
Gnosis commit `65692f383d31b2d50d694f68133be578528b0710`.

The charter requires one additional, materially different prospective
consumer before global F0 closure. This review prevents Seki from becoming a
Kiku- or Arena-specific proof language.

The reviewer must assess:

1. whether its own bounded authority decision can be represented without
   Kiku identities, GCIR semantics or Arena-specific rules;
2. whether the canonical typed core preserves the required nominal domains,
   bounded data and deterministic rejection precedence;
3. whether proof-carrying invocation and SSDC-1 can bind one concrete decision
   without assuming universal Lean/Rocq equality;
4. whether the Profile-C host boundary and API-level trust premises are honest
   for its integration;
5. whether the F0–F8 ladder prevents customer tests from substituting for
   source refinement; and
6. which materially different F7 vertical it could eventually supply.

This is a charter review only. The reviewer need not implement Seki, produce a
vertical, accept native code or grant product authority.

Return exactly one of:

```text
accepted_seki_v0_3_independent_consumer_for_f0
```

or:

```text
controlled_finding seki-v0.3 <exact-section-or-contract-path>
```

Acceptance closes global F0 only when it preserves the existing claim ceiling:
no implementation, proof, product, native-binary or production authority is
granted. F1 implementation may then begin under the frozen charter.

