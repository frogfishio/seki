# Seki execution status

- Updated: 2026-09-19
- Plan: `docs/roadmap/DELIVERY_PLAN.md` version 0.2
- Current stage: B0 bootstrap
- Current gate: global F0 open
- Active work package: E0-VS1 experimental vertical slice
- Experimental work authorized: yes
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
- F1-B format-family comparison completed: positional SCB-0 authority bytes and
  an untrusted restricted-JSON lockfile selected provisionally; bytes remain
  unfrozen.
- Provisional SCB-0 field/discriminant ledger, canonical-reconstruction witness,
  typed key orders, envelope, `U32` ceiling, and SHA-256 domain rule drafted;
  provisional admission tags, proofs, and hostile vectors remain open.
- First experimental SCB-0 vector emitted independently by C11 and JavaScript;
  the 145-byte minimal module agrees, and Node/OpenSSL independently agree on its
  domain-separated SHA-256 digest.
- Candidate-selection lowered completely to provisional SCB-0. Independent C11
  and JavaScript emitters agree on 1,021 bytes and its digest; composition exposed
  and corrected an invalid live-value ceiling and missing profile defaults.
- Independent cursor decoder reopens both positive vectors; sixteen structural
  mutations now verify provisional rejection pairs and primary-error traversal.
- Two-module bundle fixture reopens one exported type, imported function, local
  call chain, exact digest closure, and nonempty function schedule; fifteen
  bundle mutations pass, including edge/depth profile ceilings. Indexed imports
  reduced the consumer by 56%.
- Experimental semantic reconstruction accepts all three fixtures, reopens
  imported signatures, and independently reproduces their type and exact
  resource conclusions; eight isolated semantic hostile cases pass.
- A fourth 749-byte fixture covers record construction, payload-bearing variants,
  the single payload binder, payload-owned projection, and pure exhaustive match;
  three additional hostile cases pass, including two byte mutations.
- A fifth 1,068-byte fixture covers explicit arithmetic-policy result rules,
  signed negation, conversion, shifts, comparison, short-circuit Boolean control,
  and pure `If`; four additional semantic hostile cases pass.
- A sixth 859-byte fixture covers `Let`, tuples, intrinsic sum constructors,
  `Index`, and constant-time array access; four additional hostile cases pass,
  including one byte mutation.
- A seventh 597-byte fixture covers array fold, Boolean predicates, and map,
  including static-length step expansion and intrinsic
  workspace; four additional hostile cases pass.
- An eighth 352-byte fixture completes positive coverage of all six kernel-control
  tags. A checked 65-tag semantic coverage ledger records 54 positive forms,
  eleven positive-evidence gaps, and seven broader rule gaps.
- A ninth 868-byte fixture closes all eleven tagged-form gaps; all 65 tags now
  have positive canonical evidence. Initial module/profile ceiling enforcement
  adds four hostile cases.
- Canonical structural observations now enforce expression-node count, syntax
  nesting, and reopened callable depth; three additional hostile cases pass.
- Constructive exact-digest bundle graphs now cover the 64-edge and depth-eight
  profile ceilings with `040b` and `040c`.
- Checked `U32` bound arithmetic rejects semantic-width and traversal-step
  overflow with `0b00` before stored-bound comparison.
- Fixed type-formation checks cover zero indices, digest length, empty variants,
  recursive declarations, duplicate case names, internal payload placement, and
  alias expansion. V0 equality now explicitly admits every well-formed value
  type by exact normalized identity.
- The profile now rejects three redundant empty storage forms, caps every semantic
  value by maximum live bits, and admits any otherwise well-formed public nominal
  representation; four additional profile/type hostile cases pass.
- V0 collections are now fixed arrays only. The bounded-vector type and three
  associated operations were removed; SCB-0 now has 65 fully covered semantic
  tags.
- The uncheckable `maximum_input_bytes` field was removed from typed core and
  SCB-0. Source-file limits are host-tool safeguards; runtime byte bounds require
  a future explicit interchange encoding.
- Publication eligibility now requires both the publication claim and the
  publication-equivalence theorem obligation. Two independent hostile cases
  exercise the coupling, and the enumerated semantic rule-gap ledger is empty.
- Conservative C11 engineering standard and `make check` entry point added.
- ADR 0020 authorizes one end-to-end bootstrap experiment connecting exact Seki
  source, typed core, a Lean program-property proof, restricted C, and execution
  evidence without granting implementation, proof, or product authority.
- E0-01 fixes the experimental minimum-age policy, `Applicant(age: U8)` schema,
  complete threshold behavior, boundary observations, exact Seki source digest,
  independent Lean-property shape, and deliberate exclusions. The companion
  adult-approval property prevents a reject-everything implementation from
  satisfying the safety theorem vacuously.
- The first E0 Lean nucleus defines the independent property, a minimum typed
  expression evaluator, and the candidate expression. Lean 4.33.1 checks the
  full policy plus `NoMinorApproved` and `AdultApproved`; this is experimental
  evidence only because the planned 4.30.0 identity is unbound and the exact
  foundation is not qualified.
- E0-02/E0-03 now record a 417-byte SCB-0 module with domain-separated digest
  `0ff1f489e9a20e7c09e60b079db62971318586129399a3c6fb119e54e36ddc9b`.
  The existing JavaScript decoder/type checker reopens it with exact resource
  bounds `(8,25,5,0)`. The fixture-bounded Lean decoder validates the complete
  module, constructs its typed expression, proves decoder equality with Lean's
  native decision procedure, and applies the full threshold policy to any
  decoded program. This adds the local native evaluator to the experimental
  trust report; it is not a qualified proof premise.

## Active work

`E0-VS1` is active. E0-01 through E0-03 are complete experimentally. E0-04 now
owns the minimum C11 parser and syntax-directed checker that must derive the
typed-core candidate from the exact Seki source rather than from a fixture
emitter. The experiment is disposable evidence and cannot freeze conformance
while F0 is open.

## Next unblocked tasks

1. E0-04/E0-05 — minimum C11 frontend and deterministic typed-core reproduction.
2. E0-06 through E0-09 — restricted C, execution evidence, manifest, and trust report.
3. F0-01 — independent consumer decision and reviewer selection.
4. B0-08/B0-09 — exact Lean and Rocq source locks.
5. B0-10 — CompCert acquisition and use profile.

## Open decisions and blockers

| Item | Effect |
| --- | --- |
| Independent F0 case not selected | Global F0 cannot close. |
| SCB-0 field/tag ledger and vectors incomplete | Canonical bytes, verified decoding, and operational lock digests cannot freeze. |
| Reconstruction witness rules unproved | Digest-bearing derivations cannot freeze. |
| Exact runtime/output exception not adopted | Seki-owned runtime/templates cannot enter distributable customer output. |
| CompCert rights/acquisition unresolved | F4/F5 distribution profile cannot freeze. |
| Exact toolchain source identities unbound | Formal and clean-room results cannot qualify. |
| Several surface forms remain provisional | Parser work may experiment but cannot freeze conformance. |
| E0 has no Clight refinement | Its Lean proof does not prove generated C or native behavior. |

## Verification commands

```sh
make check
make check-encoding-vectors
make check-e0-lean   # experimental; currently uses local Lean 4.33.1
```

## Last verification

Local seed, status, JSON, encoding-vector, semantic-coverage, and whitespace
checks passed on 2026-09-19. This remains a bootstrap check, not clean-room or
qualification evidence.
