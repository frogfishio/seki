# Seki controlled delivery plan

- Plan version: 0.4
- Date: 2026-09-19
- Status: bootstrap complete; A0 active
- Language identity: `io.frogfish.seki/language@0`
- Governing design input: Seki v0.3 project seed
- Current delivery gate: A0 usable-alpha construction
- Current deferred pre-live gate: global F0 open

## 1. Objective

Deliver a deliberately small, total language and qualified compiler for critical
decision kernels. A source module is admitted into a canonical typed core and
projects to executable Lean, portable restricted C11, proof and representation
material, and checksum-closed manifests. Authority-bearing use requires the
claims and certificates defined by the selected qualification profile.

This plan turns the seed's F0–F8 ladder into executable project work. It does not
silently expand a phase's authority. ADR 0022 explicitly revises the seed's gate
ordering: internal implementation and proof construction precede external field
validation, while all production and live authority remains blocked by it.

The operative dependency order is:

```text
B0 -> E0 -> A0 -> F1 -> F2 -> F3 -> F4 -> F5 -> R0
                                                  |
                                                  v
                                      F6 + F7 field validation
                                                  |
                                                  v
                                           F0 closure -> F8
```

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
11. **Experiments may cross future phase boundaries without crossing their claim
    boundaries.** An explicitly authorized bootstrap experiment may exercise a
    later architecture while an earlier gate is open, but it cannot freeze the
    exercised interfaces or inherit the later phase's authority vocabulary.
12. **Usability precedes consumer acceptance.** A provisional bootstrap alpha
    may be built while F0 is open so consumers have a real artifact to evaluate.
    It cannot freeze the language, satisfy an F1 gate, or carry authority.

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
| B0-08 | W-REL | Bind exact Lean 4.30.0 source/archive identity and license. | done; source bound, installation/qualification pending |
| B0-09 | W-REL | Bind exact Rocq 9.2.0 source/archive identity and license. | done; source bound, installation/qualification pending |
| B0-10 | W-REL | Resolve CompCert 3.18 acquisition, use, and redistribution policy. | done; user-supplied, no full redistribution |
| B0-11 | W-REL | Adopt reviewed Seki runtime/output exception text. | done; Seki Generated Output Exception 1.0 |
| B0-12 | W-C | Write the C11 engineering standard and build/test matrix. | done; compiler matrix awaits code/toolchain pins |
| B0-13 | W-TEST | Add clean-room CI with pinned container/image identity. | done; Linux/amd64 image and checkout action commit locked |
| B0-14 | W-SPEC | Record treatment of local `contrib` materials. | done; transient ignored reference |

### Required artifacts

- `PROJECT_STATUS.json` and its check;
- license, notice, policies, and decisions;
- exact dependency lock records or explicit pending markers;
- project-owned surface and typed-core drafts; and
- reproducible bootstrap verification commands.

### Exit criteria

B0 completed on 2026-09-19: B0-08 through B0-14 are resolved, the seed and
bootstrap portfolio verify in the pinned clean-room environment, and no
foundational dependency or contributed input has an unknown use boundary.

B0 completion does not close F0 or authorize F1.

## 6A. Bootstrap experiment E0 — first end-to-end vertical slice

### Purpose

Test Seki's complete value proposition on one tiny decision before expanding
the specification: human-written source, exact typed core, an independently
stated Lean property, restricted C output, and executable integration evidence.

This is bootstrap implementation pressure, not the start of F1 or F3. ADR 0020
defines its claim ceiling.

### Entry criteria

- The candidate surface and typed-core drafts can express the selected policy.
- `make check` passes before the experiment begins.
- Project status names `E0-VS1` while retaining every authority field as false.

### Work

| ID | Workstream | Task | State |
| --- | --- | --- | --- |
| E0-01 | W-SPEC | Freeze only the experiment's source text, input/output schema, property statement, and exclusions. | done; experiment-only |
| E0-02 | W-LEAN | Define the minimum experimental Seki AST/decoder/evaluator needed to state the property over the exact typed-core artifact. | done; fixture-bounded experiment |
| E0-03 | W-LEAN | Prove that the exact experiment program cannot approve an applicant younger than 18. | done experimentally; full threshold policy and non-vacuity companion |
| E0-04 | W-C | Implement the minimum C11 source parser and syntax-directed checker for the selected subset. | done experimentally; closed subset |
| E0-05 | W-C | Emit the exact canonical typed-core candidate and bind its digest. | done experimentally; byte-identical independent reproduction |
| E0-06 | W-C | Implement the restricted-C AST projection and canonical printer for the selected subset. | done experimentally; independent SCB reopen |
| E0-07 | W-TEST | Add positive, hostile, boundary, differential, strict-C11, and sanitizer evidence. | done experimentally on local `cc`; toolchain unpinned |
| E0-08 | W-REPR | Bind source, typed core, theorem, generated C, compiler invocation, and result identities in one experimental manifest. | done experimentally; machine-checked non-self-referential manifest |
| E0-09 | W-SPEC | Record every unproved arrow, trusted tool, and discrepancy exposed by the slice. | done experimentally; explicit trust report |
| E0-10 | W-CUST | Review whether the completed slice justifies expansion, redesign, or termination. | done; continue architecture without language expansion |

### Exit gate

The experiment closes only when all required artifacts regenerate
deterministically, Lean checks the property against the exact decoded program,
the restricted C executes the boundary portfolio as expected, and the review
states precisely what remains unproved. Completion grants no qualification or
release authority and does not close F0.

## 6B. Bootstrap alpha A0 — first usable compiler

### Purpose

Turn the E0 feasibility slice into a compiler a prospective consumer can build,
run, and criticize. A0 resolves the circular dependency in which F0 requested
consumer acceptance before the project supplied anything usable. ADRs 0021 and
0022 and `docs/alpha/A0_SCOPE.md` define its limits and pre-live sequence.

A0 remains B0 bootstrap work. It is not F1, does not freeze conformance, and
grants no implementation, proof, native-binary, product, or production authority.

### Entry criteria

- E0-VS1 is complete with its trust report and closeout review.
- Exact upstream source identities for Lean, Rocq, and CompCert are bound.
- Project status explicitly authorizes the provisional alpha while keeping F0
  open, F1 unauthorized, and every authority field false.

### Work

| ID | Workstream | Task | State |
| --- | --- | --- | --- |
| A0-01 | W-SPEC | Fix the alpha subset, CLI intent, usability test, and claim ceiling. | done |
| A0-02 | W-C | Extract E0 into a reusable C11 compiler core and general `sekic` CLI. | active |
| A0-03 | W-C/W-TEST | Implement and test every form in the documented monomorphic alpha subset. | pending |
| A0-04 | W-CUST/W-TEST | Compile and exercise the Grit Stage 1 publication coordinator. | pending |
| A0-05 | W-REL | Produce deterministic, manifest-bound build and artifact bundles. | pending |
| A0-06 | W-CUST | Write a clean-checkout consumer quickstart and diagnostics guide. | pending |

### Exit gate

One compiler must handle both the minimum-age and Grit publication kernels, emit
deterministic candidate typed-core and restricted-C11 artifacts, reject the
hostile portfolio, and pass the clean-checkout consumer quickstart. Every
unproved arrow remains explicit.

The project develops without external review. A0 completion produces a usable
alpha, not an internally certified release candidate. Its exact evidence may
atomically authorize F1; it neither closes F0 nor makes Seki live.

## 7. Deferred phase F0 — Pre-live field-validation closure

### Purpose

Close the pre-live gate using actual field evidence that Seki serves both the
founding Kiku decision and a materially different bounded decision without
importing customer semantics into the core. F0 is defined here but executes
after F6 and F7.

### Entry criteria

- R0 has internally certified exact installed release-candidate bytes.
- F6 and F7 exercised those bytes on representative real workloads.
- The Kiku and independent-consumer findings are closed or explicitly reject
  live release.

### Work

| ID | Workstream | Task |
| --- | --- | --- |
| F0-01 | W-CUST | Bind the independent field decision, exact candidate, and accountable validator. |
| F0-02 | W-CUST | Confirm immutable inputs, result, nominal domains, and rejection classes from field use. |
| F0-03 | W-CUST | Confirm maximum data, traversal, step, stack, and workspace bounds. |
| F0-04 | W-SPEC | Confirm the core-versus-library operation map against implementation evidence. |
| F0-05 | W-CUST | Confirm the case introduced no customer-specific core primitive. |
| F0-06 | W-CUST | Obtain exact scoped field acceptance or a controlled finding. |
| F0-07 | W-SPEC | Resolve every controlled finding through a charter revision or rejection. |
| F0-08 | W-REL | Bind acceptance to exact charter bytes and reviewer identity. |
| F0-09 | W-REL | Update project status and record product-freeze authorization. |

Current F0 candidate: Grit Stage 1's sole semantic-handoff publication boundary.
The draft packet fixes the decision shape and future field-validator role.
Identity and consumer confirmation are intentionally deferred until A0 has an
internally certified release candidate. F0-02 through F0-05 are proposals to be
tested and corrected through actual field use, not accepted customer facts.

### Review packet

The packet contains:

- the exact v0.3 charter digest;
- `docs/f0/INDEPENDENT_USE_CASE_REQUEST.md`;
- the proposed consumer decision schema and hostile cases;
- the core/library operation map;
- the claim ceiling; and
- the exact permitted response tokens.

### Exit gate

F0 closes only when both Kiku and one materially different consumer accept the
exact fielded release candidate without domain-specific claim expansion. The
closure record must be machine-readable and checksum-bound. Project status
changes atomically with product-freeze authorization. F0 never retrospectively
grants proof authority to artifacts that failed their internal gates.

## 8. Phase F1 — Lean semantic core

### Purpose

Establish the canonical typed-core semantics, verified admission, total evaluator,
and resource-bound foundation. F1 emits no qualified C backend.

### Entry criteria

- B0 is complete and A0's usable-alpha exit gate is closed.
- `seki_f1_implementation_authorized` is recorded from internal A0 evidence.
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
tuples, fixed arrays, conditionals, matches, calls, arithmetic policies,
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
- maximum valid array length;
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

## 12A. Phase R0 — Internal release-candidate certification

### Purpose

Issue the project's checksum-bound self-attestation for exact installed
release-candidate bytes before any customer field validation. Internal
certification is not independent certification and grants no live authority.

### Work packages

| ID | Deliverable |
| --- | --- |
| R0-01 | Exact source, compiler, proof, generated-artifact, installation, and dependency manifest. |
| R0-02 | Machine-readable inventory of proved claims, tests, trusted premises, exclusions, and unproved arrows. |
| R0-03 | Clean-room reproduction of every authority-relevant artifact and report. |
| R0-04 | Identity-bound project self-attestation naming the exact candidate bytes. |
| R0-05 | Invalidation rule requiring affected gates and attestation to repeat after any change. |

### Exit gate

Every required internal gate passes for the exact installed candidate, its trust
report has no unexplained entry, and the self-attestation reopens from committed
bytes. R0 authorizes F6/F7 field validation only; it does not authorize live use.

## 13. Phase F6 — Kiku reference vertical

### Purpose

Field-validate the founding Kiku Arena decision through the internally certified
installed pipeline.

### Required evidence

- versioned Arena module outside the language core;
- authenticated input and representation adapter closure;
- positive, hostile, ambiguous, stale, substituted, and cancellation cases;
- exact SSDC-1 and joint receipt per authority-bearing invocation;
- publication equivalence and zero publication on every rejection/failure path;
- Kiku checked-unit closure and consumer acceptance record; and
- explicit statement of remaining host and native premises.

### Exit gate

Kiku accepts or records controlled findings against the exact installed
candidate. Findings invalidate affected R0 attestations until corrected and
re-attested. This grants no authority to unrelated Seki modules or consumers.

## 14. Phase F7 — Independent vertical

### Purpose

Field-validate the materially different F0 consumer case through the same
complete pipeline and demonstrate that no Kiku-specific semantics entered the
core.

### Exit gate

The independent consumer accepts or records controlled findings against its
exact installed candidate. Shared core changes, if any, are demonstrably
domain-neutral, repeat affected R0 gates, and both verticals continue to pass
without claim expansion.

## 15. Phase F8 — Product freeze

### Purpose

Produce the first releasable, versioned Seki profile with two qualified verticals.

### Entry criteria

- F6 and F7 field validation completed on internally certified bytes.
- Global F0 closed with exact acceptance and finding-closure records.
- Project status explicitly authorizes product freeze while live eligibility
  remains false until the F8 exit gate closes.

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

### Review and attestation

- development gates may use documented project self-review and self-attestation;
- the internally certified release candidate must receive pre-live field
  validation from consumers not responsible for its implementation;
- claim-language assessment remains separate from code correctness;
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

1. **A0-02:** extract a reusable C11 compiler core and general `sekic` CLI from
   the E0 implementation without preserving its program-shaped assumptions.
2. **A0-03:** implement the exact alpha subset and its positive/hostile suite.
3. **A0-04:** compile and execute the proposed Grit publication kernel.
4. **A0-05/A0-06:** make the result reproducible and usable from a clean checkout.
5. **A0 exit:** bind the alpha evidence and atomically authorize F1 internal work.
6. **F1-F5:** freeze and prove semantics, representation, restricted C,
   invocation certificates, and installed artifacts in dependency order.
7. **R0:** internally certify the exact installed release-candidate bytes.
8. **F6/F7:** have Kiku and the independent Grit case use those bytes in anger;
   close findings and repeat affected R0 gates after changes.
9. **F0/F8:** bind field acceptance, authorize product freeze, and make the
   separate go-live decision.

F0 remains open during A0 and internal F1-F5/R0 delivery. This blocks product
freeze and live authority, not internally controlled implementation and proof
work. No phase inherits authority from a later gate.
