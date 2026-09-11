# Seki controlled delivery plan

- Plan version: 0.1
- Date: 2026-09-11
- Status: active bootstrap plan
- Language identity: `io.frogfish.seki/language@0`
- Governing design input: Seki v0.3 project seed
- Current gate: global F0 open

## 1. Objective

Deliver a deliberately small, total language and qualified compiler for critical
decision kernels. A source module is admitted into a canonical typed core and
projects to executable Lean, portable restricted C11, proof and representation
material, and checksum-closed manifests. Authority-bearing use requires the
claims and certificates defined by the selected qualification profile.

This plan turns the seed's F0–F8 ladder into executable project work. It does not
weaken or replace the seed charter. A later plan revision may clarify work but
cannot silently expand a phase's authority.

## 2. Operating rules

1. **Gates are real.** Work may explore later stages, but the project must not
   report a stage as started, complete, or authoritative before its entry gate.
2. **One semantic root.** Canonical serialized typed core is authoritative.
   Surface source, handwritten C, and generated artifacts are proposals or
   projections until checked under the applicable profile.
3. **Claims are artifacts.** Every claim must name its scope, premises, evidence,
   toolchain identities, and counterexamples excluded by the claim.
4. **Tests are supporting evidence.** Tests do not substitute for admission,
   refinement, representation, or installed-artifact proofs.
5. **Customer independence.** Gnosis and Kiku are founding customers, not
   governing authorities. Customer concepts stay outside the language core.
6. **Stable C.** Bootstrap and host tooling use conservative ISO C11. Critical
   pure bounded components are isolated for eventual Seki-generated replacement.
7. **No circular proof.** Self-hosting and fixed points support reproducibility;
   they do not prove the compiler that produced them.
8. **Determinism by construction.** Locale, path enumeration, pointer values,
   host hash iteration, timestamps, and unspecified evaluation order cannot
   affect authoritative artifacts.
9. **Hostile input first.** Every decoder, checker, and boundary ships with
   malformed, duplicate, ambiguous, oversized, substituted, and truncated cases.
10. **Handoff at every milestone.** A person unfamiliar with the preceding work
    must be able to reproduce the result from committed artifacts and commands.

## 3. Authority vocabulary

| Term | Meaning |
| --- | --- |
| experiment | Useful engineering work carrying no qualification claim. |
| admitted | Accepted by the qualified admission checker under an exact profile. |
| proved | Established by named theorem artifacts with an explicit trust report. |
| generated | Produced deterministically from an admitted semantic root. |
| qualified | Passed the entry/exit gate for a named stage and exact toolchain. |
| installed | Exact bytes and platform closure have been bound and reopened. |
| accepted | A named consumer has accepted the exact scoped deliverable. |

The words above should not be used casually in release notes or status reports.

## 4. Technical architecture

```text
.seki source
  ↓ handwritten C11 lexer/parser/elaborator (initially untrusted)
proposed typed core + derivation witnesses
  ↓ verified admission checker
admitted canonical typed core
  ├── Lean evaluator and theorem portfolio
  ├── restricted-C AST and canonical C11 bytes
  ├── representation schema and manifest
  ├── Rocq relation and Clight refinement
  └── SSDC-1 checkers and joint receipt
        ↓
qualified proof-carrying invocation
        ↓ confined host publication protocol
```

The C11 host shell owns files, processes, diagnostics, and tool invocation. It
must not silently decide authority-bearing semantic fields.

## 5. Workstreams

The stages below coordinate these continuing workstreams:

| ID | Workstream | Persistent responsibility |
| --- | --- | --- |
| W-SPEC | Language and typed-core specification | Syntax, static semantics, dynamic semantics, versioning. |
| W-C | Bootstrap C11 implementation | Parser, elaborator, CLI, deterministic artifact orchestration. |
| W-LEAN | Lean foundation | Decoder, admission, evaluator, proofs, trust reports. |
| W-ROCQ | Rocq/CompCert foundation | Seki relation, Clight embedding, behavioral refinement. |
| W-REPR | Representation and ABI | Wire schemas, C/Lean correspondence, bounds, adapters. |
| W-CERT | SSDC and publication | Certificates, dual acceptance, receipts, single-use commit. |
| W-TEST | Adversarial and reproducibility evidence | Fixtures, differential checks, fuzzing, clean-room builds. |
| W-REL | Dependencies and delivery | Locks, licenses, manifests, installed artifacts, release process. |
| W-CUST | Consumer qualification | Kiku vertical, independent vertical, acceptance records. |

Every tracked task has one primary workstream even when several review it.

## 6. Phase B0 — Repository bootstrap

### Purpose

Create a reproducible project shell without claiming implementation authority.

### Entry criteria

- v0.3 seed is present and verifies.
- Repository identity is `io.frogfish.seki/language@0`.

### Work

| ID | Workstream | Task | State |
| --- | --- | --- | --- |
| B0-01 | W-REL | Preserve and checksum-verify the v0.3 seed. | done |
| B0-02 | W-REL | Adopt GPL-3.0-or-later for Seki. | done |
| B0-03 | W-REL | Record customer-controlled generated-output policy. | done; exception text pending |
| B0-04 | W-SPEC | Record project independence and claim vocabulary. | done |
| B0-05 | W-REL | Add contribution, security, status, and CI scaffolding. | done |
| B0-06 | W-SPEC | Assess Zing contribution and draft Seki surface syntax. | done; draft only |
| B0-07 | W-C | Adopt portable C11 bootstrap architecture. | done |
| B0-08 | W-REL | Bind exact Lean 4.30.0 source/archive identity and license. | pending |
| B0-09 | W-REL | Bind exact Rocq 9.2.0 source/archive identity and license. | pending |
| B0-10 | W-REL | Resolve CompCert 3.18 acquisition, use, and redistribution policy. | pending |
| B0-11 | W-REL | Adopt reviewed Seki runtime/output exception text. | pending |
| B0-12 | W-C | Write the C11 engineering standard and build/test matrix. | done; compiler matrix awaits code/toolchain pins |
| B0-13 | W-TEST | Add clean-room CI with pinned container/image identity. | pending |
| B0-14 | W-SPEC | Record treatment of local `contrib` materials. | done; transient ignored reference |

### Required artifacts

- `PROJECT_STATUS.json` and its check;
- license, notice, policies, and decisions;
- exact dependency lock records or explicit pending markers;
- project-owned surface and typed-core drafts; and
- reproducible bootstrap verification commands.

### Exit criteria

B0 is complete when B0-08 through B0-14 are resolved, the seed verifies in the
pinned clean-room environment, and no foundational dependency or contributed
input has an unknown use boundary.

B0 completion does not close F0 or authorize F1.

## 7. Phase F0 — Charter and independent-consumer freeze

### Purpose

Demonstrate that Seki's charter serves a materially different bounded decision
without importing Kiku/Arena semantics into the core.

### Entry criteria

- Kiku acceptance record verifies.
- Independent review request identifies an actual candidate consumer and case.

### Work

| ID | Workstream | Task |
| --- | --- | --- |
| F0-01 | W-CUST | Select the independent decision and accountable reviewer. |
| F0-02 | W-CUST | Record immutable inputs, result, nominal domains, and rejection classes. |
| F0-03 | W-CUST | Record maximum data, traversal, step, stack, and workspace bounds. |
| F0-04 | W-SPEC | Map required operations to core versus versioned library. |
| F0-05 | W-CUST | Confirm the case needs no Kiku, Arena, or GCIR core primitive. |
| F0-06 | W-CUST | Obtain the exact scoped acceptance or a controlled finding. |
| F0-07 | W-SPEC | Resolve every controlled finding through a charter revision or rejection. |
| F0-08 | W-REL | Bind acceptance to exact charter bytes and reviewer identity. |
| F0-09 | W-REL | Update project status and record `seki_f1_implementation_authorized`. |

### Review packet

The packet contains:

- the exact v0.3 charter digest;
- `docs/f0/INDEPENDENT_USE_CASE_REQUEST.md`;
- the proposed consumer decision schema and hostile cases;
- the core/library operation map;
- the claim ceiling; and
- the exact permitted response tokens.

### Exit gate

F0 closes only when both Kiku and one materially different prospective consumer
accept the same charter without expanding its claims. The closure record must be
machine-readable and checksum-bound. `PROJECT_STATUS.json` changes atomically
with the authorization record.

## 8. Phase F1 — Lean semantic core

### Purpose

Establish the canonical typed-core semantics, verified admission, total evaluator,
and resource-bound foundation. F1 emits no qualified C backend.

### Entry criteria

- Global F0 is closed.
- `seki_f1_implementation_authorized` is recorded.
- Exact Lean toolchain identity and acquisition are locked.

### Ordered work packages

#### F1-A: Typed-core freeze

| ID | Deliverable |
| --- | --- |
| F1-A01 | Versioned type and declaration schema. |
| F1-A02 | Expression and bounded-combinator node inventory. |
| F1-A03 | Name binding without shadow ambiguity. |
| F1-A04 | Nominal identity and equality rules. |
| F1-A05 | Fixed-width arithmetic and conversion rules. |
| F1-A06 | Deterministic evaluation and rejection precedence. |
| F1-A07 | Step, live-value, control-depth, and workspace algebra; concrete storage mapping is deferred. |
| F1-A08 | Explicit exclusions and profile ceilings. |
| F1-A09 | Syntax-directed monomorphic typing and exact locked-module rules. |

No concrete encoding is frozen until every admitted value has one defined schema
shape and every field has a validation rule.

#### F1-B: Canonical encoding

Evaluate a purpose-built binary encoding, strict canonical JSON, and a canonical
CBOR subset against:

- verified-decoder size;
- injectivity proof burden;
- duplicate/unknown-field rejection;
- hostile length and integer handling;
- deterministic bytes across implementations;
- schema evolution and profile binding; and
- inspectability and test tooling.

Record the decision in an ADR. The bootstrap comparison provisionally selects a
purpose-built positional binary for authority bytes and restricted canonical JSON
for the untrusted lockfile. The byte freeze still requires canonical
encoder/decoder rules, a complete field/tag ledger, positive vectors,
noncanonical equivalents that must reject, truncated/oversized vectors, and
module and digest vectors.

#### F1-C: Lean admission

Implement and prove:

- canonical decoding or reopening of exact decoded structure;
- schema/version/profile checks;
- name, type, nominal-domain, and import checks;
- closed-bundle digest, export, profile, and acyclic dependency checks;
- duplicate and unknown-field rejection;
- totality and bound-derivation validation;
- accepted-module well-formedness; and
- deterministic accept/reject behavior.

The untrusted C elaborator may emit witnesses, but the Lean checker must validate
them rather than trust them.

#### F1-D: Lean evaluator and libraries

Deliver executable semantics for primitives, records, variants, options, results,
tuples, bounded collections, conditionals, matches, calls, arithmetic policies,
and kernel decisions. Add the proved bounded graph-traversal library only after
the simpler collection basis is stable.

#### F1-E: Micro-kernel portfolio

Use the fixture-independent candidate-selection kernel. Required cases include:

- one current enabled match;
- missing candidate;
- duplicate matching candidates;
- ambiguous evidence;
- stale epoch;
- disabled candidate;
- substituted nominal identity;
- maximum valid capacity;
- oversized decoded input; and
- multiple simultaneous failures proving rejection precedence.

#### F1-F: Reports and reproducibility

Emit theorem inventory, dependency graph, axiom audit, trust report, exact Lean
identity, source digests, canonical test-vector manifest, and clean-room commands.

### F1 exit gate

- Typed-core and encoding are versioned and frozen for the profile.
- Admission and evaluator are executable and proved total/deterministic.
- Logical-step, live-value, evaluator-control-depth, and abstract-workspace
  bounds are proved; later phases prove their concrete stack/storage mapping.
- Canonical serialization is injective over admitted values.
- Hostile vectors reject with stable reasons.
- Graph traversal meets its stated bounded theorem portfolio.
- Trust and axiom reports contain no unexplained entry.
- A clean-room verifier reproduces the exact F1 artifact manifest.

F1 grants no C refinement, installed-binary, customer, or product authority.

## 9. Phase F2 — Representation model

### Purpose

Relate admitted semantic values to bounded external and future C representations.

### Work packages

| ID | Deliverable |
| --- | --- |
| F2-01 | Versioned representation schema independent of host layout accidents. |
| F2-02 | Endianness, alignment, padding, tag, length, and absence rules. |
| F2-03 | Representation functions and inverse/correspondence theorems. |
| F2-04 | Bounded decoder/encoder workspace and failure rules. |
| F2-05 | Nominal-domain preservation across representation. |
| F2-06 | Complete malformed/unknown/duplicate/oversized corpus. |
| F2-07 | C-to-Lean representation-manifest schema. |
| F2-08 | ABI ceiling and unsupported-platform rejection. |

### Exit gate

Every admitted external value has one checked semantic interpretation; malformed
or out-of-profile values have none. Representation equality is not confused with
semantic or installed-binary equality.

## 10. Phase F3 — Restricted-C construction

### Purpose

Define the target C subset and deterministically turn admitted typed core into
exact portable C11 source and headers. F3 constructs syntax; it does not yet
claim behavioral refinement.

### Work packages

| ID | Deliverable |
| --- | --- |
| F3-01 | Versioned restricted-C AST with explicit profile limits. |
| F3-02 | Mapping from typed-core constructs to restricted-C AST. |
| F3-03 | Canonical printer with whitespace and identifier rules. |
| F3-04 | Parser for exactly the emitted restricted-C grammar. |
| F3-05 | Print/parse exact-AST correspondence portfolio. |
| F3-06 | Deterministic symbol mangling and collision rejection. |
| F3-07 | Header, workspace, and caller-ownership conventions. |
| F3-08 | No-UB construction checks for arithmetic, indexing, tags, and shifts. |
| F3-09 | GCC/Clang compile and differential execution matrix. |
| F3-10 | Generated-output notice and runtime-exception enforcement. |

### Exit gate

Exact emitted bytes parse to the intended restricted-C AST; generation is
deterministic; unsupported constructs reject; and the test matrix finds no
semantic discrepancy. No C-to-Seki proof claim is made before F4.

## 11. Phase F4 — Proof-carrying invocation and generator refinement

### Purpose

Establish the charter's exact proof boundaries: universal generated Clight to
Rocq-Seki refinement and invocation-scoped generated-C to normative-Lean equality
through one jointly accepted SSDC-1 certificate.

### Work packages

| ID | Deliverable |
| --- | --- |
| F4-01 | Rocq Seki relation for the frozen typed core. |
| F4-02 | Restricted-C AST embedding into CompCert 3.18 Clight. |
| F4-03 | Universal admitted-module/input Clight-to-Rocq refinement. |
| F4-04 | Termination, exact result, no-stuck/UB, and memory-bound proofs. |
| F4-05 | SSDC-1 schema, canonical encoding, and rule set. |
| F4-06 | Qualified Lean SSDC-1 checker. |
| F4-07 | Qualified Rocq SSDC-1 checker. |
| F4-08 | Module/input/result/publication and checker-identity bindings. |
| F4-09 | `LeanCertificateAcceptance` and `RocqCertificateAcceptance`. |
| F4-10 | `JointCertificateReceipt` construction and verification. |
| F4-11 | Certificate-gated candidate/publication state machine. |
| F4-12 | Negative portfolio for absent, mismatched, replayed, or substituted certificates. |

### Exit gate

The universal theorem states only Clight-to-Rocq scope. Lean equality and
generated-C-to-Lean equality are derived only for the exact jointly certified
invocation. Without the exact joint receipt, publication count is zero and no
Lean-equivalence claim is emitted.

## 12. Phase F5 — Installed artifacts and native trust closure

### Purpose

Bind proved source-level artifacts to reproducibly installed deliverables and
state the remaining native trusted computing base honestly.

### Work packages

| ID | Deliverable |
| --- | --- |
| F5-01 | Exact compiler, checker, runtime, OS, and platform identities. |
| F5-02 | Deterministic archive and installation layout. |
| F5-03 | Checksum-closed artifact and dependency manifests. |
| F5-04 | Reproducible builds from two clean environments where feasible. |
| F5-05 | Installed command and SDK verification. |
| F5-06 | Native compiler/assembler/linker trust report. |
| F5-07 | C11 and C++17 consumer integration tests. |
| F5-08 | Upgrade, rollback, and profile-mismatch rejection behavior. |

### Exit gate

Installed bytes reopen to the released portfolio and all unproved native
components are explicit premises. No customer acceptance follows automatically.

## 13. Phase F6 — Kiku reference vertical

### Purpose

Qualify the founding Kiku Arena decision through the full installed pipeline.

### Required evidence

- versioned Arena module outside the language core;
- authenticated input and representation adapter closure;
- positive, hostile, ambiguous, stale, substituted, and cancellation cases;
- exact SSDC-1 and joint receipt per authority-bearing invocation;
- publication equivalence and zero publication on every rejection/failure path;
- Kiku checked-unit closure and consumer acceptance record; and
- explicit statement of remaining host and native premises.

### Exit gate

Kiku accepts the exact installed vertical. This grants no authority to unrelated
Seki modules or consumers.

## 14. Phase F7 — Independent vertical

### Purpose

Qualify the materially different F0 consumer case through the same complete
pipeline and demonstrate that no Kiku-specific semantics entered the core.

### Exit gate

The independent consumer accepts its exact installed vertical; shared core
changes, if any, are demonstrably domain-neutral and both verticals continue to
pass without claim expansion.

## 15. Phase F8 — Product freeze

### Purpose

Produce the first releasable, versioned Seki profile with two qualified verticals.

### Work packages

- freeze language, typed-core, representation, SSDC, backend, and ABI versions;
- close every release-blocking decision and controlled finding;
- run the complete hostile, differential, proof, and reproducibility portfolios;
- generate theorem, dependency, axiom, license, SBOM, and trust reports;
- reproduce installed bytes from the frozen source and dependency closure;
- verify upgrade and incompatible-profile rejection;
- publish release notes whose claims are generated from machine-readable status;
- archive the exact Kiku and independent-consumer acceptance records; and
- preserve rollback artifacts and verification instructions.

### Exit gate

F8 closes only when every advertised claim can be reopened from the release
bundle without relying on project memory or conversational context.

## 16. Cross-phase quality gates

Every implementation-bearing phase must include:

### Specification

- exact identities and versions;
- normative inputs and excluded behavior;
- deterministic error/rejection precedence;
- resource ceilings; and
- compatibility and migration rules.

### Implementation

- no unresolved TODO in an authority-bearing path;
- no unbounded input-derived allocation or iteration;
- explicit ownership and length at C boundaries;
- deterministic serialization and traversal; and
- feature rejection instead of best-effort lowering.

### Verification

- positive and hostile cases;
- boundary values and maximum capacities;
- differential evidence where two implementations exist;
- proof and trust reports where required;
- exact commands and expected summaries; and
- clean-room reproduction.

### Review

- at least one reviewer not responsible for the implementation;
- claim-language review separate from code correctness;
- dependency/license review for new third-party material; and
- recorded findings with owners and closure evidence.

## 17. Change control

An ADR is required for changes to:

- language syntax or semantics;
- typed-core schema or canonical bytes;
- evaluation or rejection order;
- arithmetic, bounds, or resource accounting;
- proof scope or trusted premises;
- runtime, ABI, or representation;
- dependency identity or license;
- qualification gates or customer acceptance; or
- generated-artifact licensing.

Semantic changes require a semantic-version decision. Encoding-only changes
require a wire-version decision. Backend-only changes require a backend-profile
decision and new refinement evidence.

## 18. Handoff and stopping rule

At the end of every work package:

1. update `docs/roadmap/STATUS.md`;
2. record exact commit(s), toolchain identities, and commands;
3. list artifacts created and claims they do or do not support;
4. list open findings, risks, and the next unblocked task;
5. ensure generated files are reproducible or clearly marked experimental;
6. run the checks applicable to the current phase; and
7. complete `docs/roadmap/HANDOFF_TEMPLATE.md` for a release, phase gate, or
   change of owner.

Work stops at a gate when its evidence is incomplete. The response is to record
the missing evidence, not to weaken the gate or rename experimental work as
qualified work.

## 19. Immediate execution queue

The next tasks, in dependency order, are:

1. **F0-01:** name the materially different consumer decision and reviewer.
2. **F0-02/F0-03:** write its data, bound, and rejection inventory.
3. **F1-A01/F1-A02 review:** review the initial typed-core declaration,
   expression, admission, and fixture drafts without claiming F1 start.
4. **F1-A04/F1-A06:** review the explicit single-payload binder rule and indexed
   rejection-precedence model.
5. **B0-08/B0-09:** bind Lean and Rocq exact sources and licenses.
6. **B0-10:** resolve the CompCert acquisition/use profile.
7. Implement independent experimental SCB-0 encoders and produce positive,
   hostile, rejection-precedence, and digest vectors.
8. Assemble the F0 review packet and request the exact scoped response.

Tasks 3–7 are bootstrap/specification work and may proceed while F0 is open. No
F1 completion or authority claim may be made until task 8 closes the gate.
