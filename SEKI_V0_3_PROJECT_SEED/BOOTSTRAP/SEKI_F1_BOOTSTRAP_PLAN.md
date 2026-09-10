# Seki F1 project bootstrap plan

Status: project-seed plan; implementation authority not yet granted

## 1. Purpose

This document is the bootstrap map for a new repository implementing Seki / 関
from the accepted v0.3 charter. The new project owns Seki. It must not become a
subdirectory of Gnosis, inherit Gnosis authority, or encode Kiku-specific
semantics in the language core.

Kiku has accepted the charter for F0. Global F0 remains open until one
materially different prospective consumer accepts it. Repository scaffolding,
toolchain experiments and dependency qualification may proceed, but the
project must not report F1 as started or complete until global F0 closes.

## 2. Normative inputs

The project begins from exactly:

- `SEKI_V0_SPEC.md` — normative v0.3 charter;
- `SEKI_V0_3_REVIEW.json` — machine-readable claim and scope contract;
- `SEKI_V0_3_KIKU_F0_ACCEPTANCE.*` — Kiku consumer acceptance;
- `SEKI_F0_INDEPENDENT_CONSUMER_REVIEW_REQUEST.md` — remaining global-F0 gate;
- `SEKI_V0_2_SPEC.md` and `SEKI_V0_2_REVIEW.json` — immediate design history;
  and
- the historical FPKL v0.1 specification and review contract — naming and
  decision traceability only.

No Gnosis C implementation, private provider record, API number, package
identity or Kiku adapter is a normative Seki input.

## 3. Proposed repository layout

```text
seki/
├── README.md
├── LICENSE
├── NOTICE
├── spec/
│   ├── language/
│   ├── typed-core/
│   ├── ssdc/
│   └── profiles/
├── contracts/
├── src/
│   ├── syntax/
│   ├── typed_core/
│   ├── admission/
│   └── canonical/
├── formal/
│   ├── lean/
│   └── rocq/
├── backend/
│   ├── restricted_c/
│   └── clight/
├── runtime/
│   └── profile_c/
├── tools/
├── tests/
│   ├── positive/
│   ├── hostile/
│   ├── differential/
│   └── reproducibility/
├── examples/
├── delivery/
└── history/
```

The Lean and Rocq trees are peers. Neither may silently generate the other's
semantics. Their only v0 bridge is the exact concrete SSDC-1 invocation
certificate and joint acceptance receipt frozen by the charter.

## 4. Immediate bootstrap tranche

Before F1 begins, establish:

1. repository identity `io.frogfish.seki/language@0`;
2. contribution, licensing and security policies;
3. exact dependency locks for Lean 4.30.0, Rocq 9.2.0 and CompCert 3.18;
4. checksums or commits for every toolchain source;
5. deterministic UTF-8, JSON and archive rules;
6. clean-room CI on the first supported platform;
7. the independent-consumer F0 acceptance record; and
8. a machine gate that prevents implementation claims while F0 is open.

CompCert's public distribution has licensing conditions that differ from Lean
and Rocq. The project must decide whether it will consume a suitably licensed
CompCert distribution, use only permitted proof sources, or require users to
supply their own installation. It must not vendor or redistribute CompCert by
assumption.

## 5. F1 — Lean semantic core

F1 delivers no C backend and no product authority. Its required outputs are:

1. a versioned canonical typed-core schema;
2. an injective canonical serialization over admitted values;
3. duplicate-label and unknown-field rejection;
4. a small verified admission checker;
5. the normative Lean evaluator;
6. fixed-width arithmetic and nominal equality;
7. bounded arrays, records, variants, options and results;
8. deterministic total rejection precedence;
9. proved logical-step, live-value, stack and workspace bounds;
10. a proved bounded graph-traversal library; and
11. theorem, axiom, dependency and trust reports.

F1 must expose a fixture-independent micro-kernel before importing the Arena
vertical. A suggested first kernel is a nominal, bounded candidate-selection
decision with positive, missing, duplicate, ambiguous, stale and substituted
cases.

## 6. Later qualification map

- F2: representation model and encoding proofs.
- F3: restricted-C AST, parser and canonical printer.
- F4: SSDC-1 checkers, proof-carrying invocation, Rocq semantics and Clight
  behavioral refinement.
- F5: installed artifacts and native-toolchain trust closure.
- F6: Kiku Arena reference vertical.
- F7: materially different independent vertical.
- F8: product freeze.

No tranche may borrow authority from a later tranche. Tests and customer
success are supporting evidence, not substitutes for the required refinement
theorems.

## 7. First project decisions

The new project must freeze, before implementation spreads:

- final repository and package names;
- source and generated-file extensions;
- canonical typed-core wire encoding;
- whether checked caller-owned allocation enters v0;
- Profile-C adapter representation;
- supported host and target platform for the first release;
- dependency acquisition and licensing policy; and
- the independent F7 consumer.

## 8. Initial acceptance token

After the seed verifies and the independent consumer closes global F0, the new
project may record:

```text
seki_f1_implementation_authorized
```

That token authorizes work on the F1 semantic core only. It grants no proof,
C-refinement, native, customer or product authority.

