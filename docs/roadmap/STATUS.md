# Seki execution status

- Updated: 2026-09-11
- Plan: `docs/roadmap/DELIVERY_PLAN.md` version 0.1
- Current stage: B0 bootstrap
- Current gate: global F0 open
- F1 authorized: no
- Implementation authority: none
- Proof authority: none
- Product/production authority: none

## Completed bootstrap work

- Frozen v0.3 seed imported and verified.
- GPL-3.0-or-later adopted.
- Customer-controlled output policy accepted; exception wording remains pending.
- Project/customer independence recorded.
- Machine-readable claim ceiling and CI check added.
- Linux x86-64 selected as initial qualification platform.
- Zing contribution assessed as surface-language lineage.
- Seki surface-language and candidate PEG drafts created.
- Portable C11 bootstrap and selective dogfooding architecture accepted.
- Local Zing contribution classified as transient, ignored bootstrap reference.
- Initial typed-core, admission-rule, and candidate-selection fixture drafts created.
- Typed-core draft 0.2 structural review completed; freeze blockers recorded.
- Binder and rejection-precedence review completed; kernel control is tail-formed.
- Arithmetic and resource-algebra review completed; mathematical operations and
  the canonical structural cost schedule are drafted.
- V0 typing/module complexity ceiling recorded: monomorphic structural checking,
  aliased exact-version imports, and generated locked core digests.
- Conservative C11 engineering standard and `make check` entry point added.

## Active work

No task is currently marked active. Select the first unblocked item from the
immediate execution queue in the delivery plan and record its owner here.

## Next unblocked tasks

1. F0-01 — independent consumer decision and reviewer selection.
2. F1-B comparison — compare canonical encoding candidates without freezing one.
3. B0-08/B0-09 — exact Lean and Rocq source locks.
4. B0-10 — CompCert acquisition and use profile.

## Open decisions and blockers

| Item | Effect |
| --- | --- |
| Independent F0 case not selected | Global F0 cannot close. |
| Canonical typed-core/lock encoding not selected | Canonical bytes, verified decoding, and operational lock digests cannot freeze. |
| Derivation witness normal form unspecified | Digest-bearing derivations cannot freeze. |
| Exact runtime/output exception not adopted | Seki-owned runtime/templates cannot enter distributable customer output. |
| CompCert rights/acquisition unresolved | F4/F5 distribution profile cannot freeze. |
| Exact toolchain source identities unbound | Formal and clean-room results cannot qualify. |
| Several surface forms remain provisional | Parser work may experiment but cannot freeze conformance. |

## Verification commands

```sh
make check
```

## Last verification

Local seed, status, JSON, and whitespace checks passed on 2026-09-11. This is a
bootstrap check, not clean-room or qualification evidence.
