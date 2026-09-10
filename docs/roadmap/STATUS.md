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

## Active work

No task is currently marked active. Select the first unblocked item from the
immediate execution queue in the delivery plan and record its owner here.

## Next unblocked tasks

1. B0-14 — contributed-material provenance and license treatment.
2. F0-01 — independent consumer decision and reviewer selection.
3. F1-A01 draft — typed-core type and declaration schema.
4. B0-12 — C11 engineering and test standard.
5. B0-08/B0-09 — exact Lean and Rocq source locks.

## Open decisions and blockers

| Item | Effect |
| --- | --- |
| Independent F0 case not selected | Global F0 cannot close. |
| Canonical typed-core encoding not selected | Canonical bytes and verified decoder cannot freeze. |
| Exact runtime/output exception not adopted | Seki-owned runtime/templates cannot enter distributable customer output. |
| CompCert rights/acquisition unresolved | F4/F5 distribution profile cannot freeze. |
| Exact toolchain source identities unbound | Formal and clean-room results cannot qualify. |
| Several surface forms remain provisional | Parser work may experiment but cannot freeze conformance. |

## Verification commands

```sh
./SEKI_V0_3_PROJECT_SEED/VERIFY.sh
node tools/check_project_status.mjs
git diff --check
```

## Last verification

Local seed, status, JSON, and whitespace checks passed on 2026-09-11. This is a
bootstrap check, not clean-room or qualification evidence.

