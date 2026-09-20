# Seki execution status

- Updated: 2026-09-20
- Plan: `docs/roadmap/DELIVERY_PLAN.md` version 0.4
- Current stage: A0 provisional alpha
- Bootstrap status: complete
- Current gate: global F0 open
- Active work package: A0-02 reusable C11 compiler core and `sekic` CLI
- E0-VS1 experimental work: complete
- A0 provisional alpha: active; no authority
- Internal certification: not ready
- Customer field validation: deferred until release candidate
- Live eligibility: no
- F1 authorized: no
- Implementation authority: none
- Proof authority: none
- Product/production authority: none

## Completed bootstrap work

- Frozen v0.3 seed imported and verified.
- GPL-3.0-or-later adopted.
- Customer-controlled output policy and Seki Generated Output Exception 1.0 adopted.
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
- E0-04/E0-05 add a strict-C11, closed-subset source frontend. It lexes, parses,
  and shape/type-checks the exact experiment source, rejects declarations below
  the derived resource bounds, and emits the same 417 SCB-0 bytes as the
  independent JavaScript fixture emitter. A source threshold mutation changes
  exactly the encoded literal byte; six hostile source mutations are rejected
  before any output artifact is created.
- E0-06/E0-07 add an independent closed-subset SCB-0 decoder, restricted-C AST,
  and canonical printer. The backend validates the complete 417-byte module and
  emits a stable 524-byte C11 translation unit with raw SHA-256
  `5843e2df8f58719f74dd25a3fb32868881f54361ce5045dea9c8ff7ed5cbf201`.
  The generated kernel agrees with the policy for all 256 admitted ages, runs
  under AddressSanitizer and UndefinedBehaviorSanitizer, propagates a valid
  threshold mutation, and rejects three structural SCB mutations.
- E0-08 binds nine core/evidence artifacts plus the trust report and closeout in a
  machine-checked, non-self-referential manifest. It separately records the
  encoded hex-file identity, decoded SCB byte identity, domain-separated module
  identity, exact C identity, invocation shapes, and unqualified local tool
  observations.
- E0-09 accounts for every pipeline arrow, trusted component, known discrepancy,
  and prohibited claim. It records the missing SCB-to-Clight refinement as the
  central proof gap and does not mistake exhaustive native `U8` execution for a
  compiler-correctness proof.
- E0-10 closes the slice with the decision to continue the typed-core checkpoint
  architecture without expanding the language surface. The next program-level
  pressure must come from the materially different F0 consumer case.
- F0-01 now has a concrete candidate: Grit Stage 1 handoff publication. The
  proposed kernel coordinates eight nominal authenticated evidence receipts and
  exact artifact/pack/vocabulary identities into one publication permit or a
  deterministic rejection with zero publication. The candidate is materially
  different from the Arena decision and requires no customer-specific core
  primitive. Its field-validator role is fixed, while identity and acceptance
  are deliberately deferred until the release candidate exists.
- B0-08/B0-09 bind the exact Lean 4.30.0 and Rocq 9.2.0 upstream tags,
  resolved commits, source-archive sizes and SHA-256 identities, and license
  identities. The archives are not vendored, and neither tool is installed or
  qualified from the locked source yet.
- B0-10 adopts a user-supplied CompCert policy: Seki will not vendor or
  redistribute the full public distribution; commercial use requires the
  operator's lawful AbsInt agreement or a separately audited permissive proof
  closure. The official `v3.18` archive is bound, with a controlled finding that
  its root `VERSION` file still reports `3.17`.
- B0-11 adopts the original Seki Generated Output Exception 1.0 as a GPLv3
  section 7 additional permission, without copying or modifying GCC's exception.
- B0-13 pins bootstrap CI to an immutable Linux/amd64 Node 22 Bookworm image
  manifest and an exact `actions/checkout` commit. The lock explicitly carries
  no formal-foundation or qualification authority.
- The complete bootstrap portfolio passes inside that pinned Linux/amd64 image.
  The local observation records a mounted working tree; the pinned CI workflow
  is responsible for reproducing it from a clean checkout after commit.
- B0 is complete. Foundation sources and use policies are bound; their installed
  builds and qualification remain later formal-delivery work rather than
  repository-bootstrap conditions.
- ADRs 0021 and 0022 resolve the sequencing problem: Seki develops autonomously
  through a checksum-bound, internally certified release candidate, then Gnosis,
  Kiku, and Grit use those exact bytes in anger before any live decision. Internal
  certification is a self-attestation, not independent certification.
- A0-01 fixes the alpha subset, CLI intent, usability test, six-package work
  ledger, and claim ceiling. It requires both the minimum-age and Grit Stage 1
  publication kernels to pass through one general compiler.
- A0-02 now has a strictly compiled `sekic 0.0.0-alpha.6` vertical. `check`,
  `build`, and `inspect` execute through an in-process C API; `build` reproduces
  the exact E0 typed-core and restricted-C bytes and rejects existing or aliased
  outputs. Inspection exposes `frontend=alpha-u8-decision` and
  `backend=alpha-u8-decision`.
- The first adapter-independent A0-02 component is complete: a name-agnostic,
  allocation-free lexer covers the candidate grammar's identifiers, checked
  `U32` numbers, hexadecimal strings, comments, newlines, delimiters, and
  operators. Its strict-C11 suite checks 32 token observations and four hostile
  classes.
- The live CLI now parses module paths, module/profile versions, claims, and
  theorem obligations through the general lexer/parser before invoking the E0
  adapter. Fixed capacities and duplicate rejection have independent positive
  and hostile coverage.
- The general parser now accepts aliases, nominal types, non-recursive records,
  and explicitly tagged variants with optional payload fields. It rejects
  duplicate declaration, record-field, variant-name, and variant-tag identities.
  It also parses exported kernel envelopes through parameters, applied result
  types, policy, resource bounds, rejection order, publication mode, and balanced
  body extent.
- The minimum-age kernel tail now becomes a fixed-capacity AST rather than an
  opaque token span. An independent checker resolves parameters and record
  fields, enforces comparison and condition types, and checks `accept`/`reject`
  against the declared `Decision` and rejection inventory. The live CLI runs
  this checker before its E0 regression adapter. The remaining expression forms,
  pure functions, domains, full declaration semantics, typed-core construction,
  and general emission remain open, so A0-02 is still active.
- The live `sekic` frontend no longer links the E0 source parser. A new bounded
  core emitter maps the checked minimum-age AST to the exact 417-byte SCB-0
  regression artifact; changing the threshold to 19 changes both the core and
  generated C. Core emission remains shape-limited.
- The live compiler no longer links the E0 backend adapter. Its alpha backend
  independently validates the complete SCB-0 U8-decision slice, reconstructs a
  restricted-C model, and prints the exact 524-byte regression output. Bad
  magic and payload-length mutations reject before inspection or C generation.
- The frontend, core emitter, decoder, and C printer no longer require the
  minimum-age program's identifiers. A renamed `gate_policy` module with renamed
  data, field, rejection, kernel, and parameter names, tag 7, and threshold 42
  passes end to end and its emitted C compiles strictly. The minimum-age C ABI is
  retained only as a byte-regression compatibility case.
- The U8-decision slice now admits multiple canonically ordered input fields and
  payload-free rejection cases. The emitter derives field index, constructor
  tag, precedence index, and exact live-value bounds. The renamed two-field,
  two-rejection artifact is independently reopened by the general JavaScript SCB
  decoder and semantic/resource checker; its exact live bound is 40 bits.
- Complete-module parsing is now mandatory on the live path. Unsupported
  declarations and trailing source reject instead of disappearing beyond a
  parsed prefix, closing a dependency that had previously been covered by the
  second E0 source parse.
- The checker is now an elaborator. It records one resolved type, environment
  slot, field position, variant tag, and precedence index per expression, and
  the typed-core emitter reads that elaboration instead of resolving names a
  second time. The two components can no longer disagree about what a program
  means.
- Typed-core construction is now a recursive traversal of the checked AST
  rather than a fixed byte sequence guarded by a program-shape match. The
  417-byte minimum-age artifact and its 524-byte C remain byte-identical.
- Exact resource bounds are derived from the published cost algebra over
  `value_bits`, the evaluation schedule, control depth, and workspace, instead
  of a shape-specific live-bit formula. The minimum-age derivation reproduces
  `(8,25,5,0)`, and a declared ceiling below the derived bound is now rejected
  by the checker as `A0-CHECK-0017`.
- Canonical table ordering moved into the compiler. Declarations, record
  fields, and variant cases are sorted by their typed keys and every emitted
  reference uses the canonical position, so source order no longer has to match
  canonical order. Declaring the variant before the record emits identical
  bytes. The derivation bundle records the greedy topological type order.
- All six comparison forms lower through the general emitter and the
  independent backend, which decodes the operator instead of requiring
  `LessThan`. Each is reopened and revalidated by the separate JavaScript
  decoder and semantic checker.
- Two unbounded-recursion defects were found by source mutation fuzzing under
  AddressSanitizer and fixed. Deeply nested parentheses consume no
  expression-arena slot per level, and a stale token after a lexer failure
  re-entered the conditional production forever; each exhausted the host stack
  on a source well inside the 64 KiB limit. Recursive descent is now bounded by
  the profile's `maximum_nesting` ceiling and reports `A0-PARSE-0035`. Both
  inputs are pinned as parser regressions.
- The host now owns the parsed module and elaboration workspace, so no
  component below `main` carries a multi-megabyte frame.
- The independent backend no longer assumes the record occupies type-table
  position zero, nor one fixed theorem/claim vector. Canonical positions follow
  the program's own identifiers and the obligation vectors are validated as
  strictly increasing known tags, so a module whose variant name sorts first or
  that states a different obligation set now compiles through both directions
  instead of being accepted by `check` and refused by `build`.
- The remaining `check`/`build` divergence is now enumerated in the A0 scope
  rather than implicit: the typed-core direction is broader than the
  restricted-C projection, and `inspect` reports the two boundaries separately
  as `frontend=alpha-decision` and `backend=alpha-u8-decision`. Closing that
  gap is A0-03 work; both directions fail closed and `build` writes no artifact
  unless every stage succeeds.
- The C backend decodes a restricted-C AST instead of a linear byte
  expectation. Kernel control now nests: a three-premise decision with ordered
  rejection precedence compiles end to end, its exact bounds `(18,40,7,0)` are
  independently reproduced by the JavaScript cost algebra, and the generated C
  agrees with the stated policy on all 65,536 input pairs under
  AddressSanitizer and UndefinedBehaviorSanitizer. Boolean literal conditions
  also project. The minimum-age C remains byte-identical.
- Record fields carry their own unsigned width end to end. `U8`, `U16`, `U32`,
  and `U64` fields project to the matching exact-width C type, and integer
  literals encode in exactly their type's octet count, most significant first.
  The independent decoder confirms `IntLit(U32, 70000)` as `00 01 11 70` and
  the `U64` boundary as eight octets. Surface literals remain checked `U32`, so
  a `U64` field compares against values up to 4294967295 and a wider literal
  fails closed as `A0-LEX-0001`.
- `inspect` no longer reports a minimum-age-shaped `threshold_u8`. It reports
  `first_literal=<value>:<type>` when the kernel has one, and both boundaries
  now read `alpha-decision`.
- The C projection keeps a declaration table rather than one record and one
  variant. A module may declare any number of records and variants; each record
  becomes a struct in canonical order, and the kernel signature selects the
  declarations it uses by reading their positions rather than assuming a
  layout. Exports and the derivation order follow the declaration count.
- `Bytes[N]` and `Digest[sha256, 32]` record fields project to octet arrays,
  and identity equality projects to a comparison whose running time does not
  depend on where the first differing octet lies. These values are
  authenticated evidence and artifact identities, so an early-exit comparison
  would leak how much of a candidate identity an attacker had guessed. Ordered
  comparison on an octet array has no C operator form and is rejected by the
  checker as `A0-CHECK-0004` before the projection is asked to print one. A
  two-digest kernel derives `(9,1536,5,0)`, which the independent checker
  reproduces, and its generated comparison is verified against every
  single-bit difference across all 32 octets.
- Short-circuit Boolean operators are connected end to end. `&&` binds tighter
  than `||`, both associate to the left, and the printed C groups explicitly
  rather than relying on the reader to recall C precedence. Their cost follows
  the algebra's short-circuit rule: both operands are charged steps because the
  bound is worst case, but the left result is released before the right is
  evaluated, so the live peak is their maximum rather than their sum. A
  three-field kernel derives `(18,56,7,0)`, which the independent checker
  reproduces, and its generated C agrees with the stated policy on 692,224
  sampled input triples.
- Alias and nominal declarations now reach C. A nominal becomes a typedef over
  its representation, and declarations are emitted in the module's own type
  dependency order rather than canonical name order, so a typedef always
  precedes its use. The typed core's derivation bundle supplies that order
  directly.
- Nominal types are not substitutable even when they share a representation:
  two distinct nominals over `Digest[sha256, 32]` do not compare, which is the
  property a handoff needs from distinct evidence identities. The checker
  already enforced this; it now survives to C.
- An octet array reached through a nominal is still an octet array. Comparing
  two of them with a C operator would have compared addresses, always differed,
  and rejected every input while compiling without a warning. Type resolution
  follows alias and nominal declarations before choosing a C form, and a
  regression case asserts the constant-time helper is used rather than `!=`.
- `require C else: V::Case.` is connected end to end as `KernelRequire`. It
  states one premise and the rejection that reports its failure, then
  continues, which is the form a decision with several premises in declared
  precedence order actually wants. A three-premise kernel derives
  `(18,176,7,0)`, which the independent checker reproduces, and its generated
  C agrees with the stated precedence on 6,400 input combinations. The printed
  C nests rather than returning early, so the function keeps one exit.
- Field projection no longer decides what is a selector by a list of excluded
  keywords. The grammar spells it `ValueIdent !Colon`, so the parser now looks
  ahead for the colon. The list had already failed once: `else` was being eaten
  as a field name. A keyword added later cannot be silently absorbed now.
- Immutable bindings are connected end to end as `KernelLet`. `name := expr.`
  binds one fresh local whose scope is the rest of the body, and a binding that
  shadows a visible local is rejected as `A0-CHECK-0019`. The checker now
  resolves every value name through a real scope chain rather than the
  parameter list, using the typed core's own innermost-first slot convention.
  Binding names are erased by the encoding, so the projection spells each by
  the order it was introduced and resolves references by slot. A two-binding
  kernel derives `(17,49,7,0)`, which the independent checker reproduces, and
  its generated C agrees with the stated policy on all 65,536 input pairs.
- The C projection no longer re-derives exact resource bounds with a
  shape-specific formula. It checks that stored bounds are well formed and
  within the declared ceiling, and leaves exact-bound equality to admission,
  which owns the canonical cost algebra. A second, weaker derivation inside the
  projection would have been a checker that silently disagrees.

- The E0 Lean proof is now enforced by the build. `lean-toolchain` pins
  `leanprover/lean4:v4.30.0`, elan resolves a bare `lean` to it, and
  `check-lean-proof` verifies that the installed binary reports the upstream
  commit the foundation lock records before running the proof. Nine theorems
  check with no `sorry` and no `axiom`. The check reports a skip when Lean is
  absent, so the portfolio still runs in the pinned Node container.
- `decodeExactProgram_eq` is discharged by `native_decide`, which evaluates
  compiled Lean rather than checking a term in the kernel, and every theorem
  about the decoded program rests on it. Lean's compiler and runtime are
  therefore trusted premises. The check asserts that exactly one
  `native_decide` exists, so widening that trusted base is a visible change.
- Lean needed no agreement, appointment, or clean-room build: it is Apache-2.0
  and was already installed at the locked commit. Rocq is LGPL-2.1 and
  CompCert's own license permits this project's noncommercial use, so the same
  applies to both. The remaining formal work is installing them and writing
  proofs, not obtaining permission.

## Active work

`E0-VS1` is complete experimentally. A0-02 is active: extract its program-shaped
C code into a reusable compiler core and general `sekic` CLI. F0 remains open;
the Grit Stage 1 publication decision remains the selected independent case.
External field validation begins only after internal release-candidate
certification. All current alpha work is replaceable and cannot freeze
conformance.

## Next unblocked tasks

1. A0-02 — extract the reusable compiler core and `sekic` CLI.
2. A0-03 — implement and test the fixed alpha subset.
3. A0-04 — add the runnable Grit publication kernel.
4. A0-05/A0-06 — produce deterministic bundles and the consumer quickstart.

## Open decisions and blockers

| Item | Effect |
| --- | --- |
| Grit field-validator identity and acceptance absent | Expected during development; F0 and live eligibility remain open until post-candidate field validation. |
| SCB-0 field/tag ledger and vectors incomplete | Canonical bytes, verified decoding, and operational lock digests cannot freeze. |
| Reconstruction witness rules unproved | Digest-bearing derivations cannot freeze. |
| No lawful qualified CompCert installation selected | F4/F5 cannot execute or qualify. |
| Locked foundation sources not clean-room built | Formal results cannot qualify. |
| Several surface forms remain provisional | Parser work may experiment but cannot freeze conformance. |
| E0 has no Clight refinement | Its Lean proof does not prove generated C or native behavior. |

## Verification commands

```sh
make check              # includes the Lean proof when Lean is installed
make check-lean-proof   # verifies the toolchain identity, then the proof
make check-encoding-vectors
make check-foundation-lock
make check-e0-frontend
make check-e0-backend
make check-e0-manifest
```

## Last verification

Local and pinned Linux/amd64 seed, status, bootstrap-closure, JSON,
encoding-vector, semantic-coverage, strict-C11, sanitizer, and whitespace checks
passed on 2026-09-20, including the E0 Lean proof under the pinned toolchain.
The alpha compiler additionally passed 4,400 source and 4,900 typed-core
mutation cases across the minimum-age, nested three-premise, wide-integer,
four-declaration, two-digest, short-circuit Boolean, nominal-identity,
require-premise, and binding kernels under AddressSanitizer and UndefinedBehaviorSanitizer with no finding,
after the two stack-exhaustion defects that earlier sweeps found were fixed. The container run used the mounted working tree and carries
no formal qualification authority; clean-checkout reproduction is delegated to
the exact pinned CI workflow.
