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
- B0-13 pinned bootstrap CI to an immutable Linux/amd64 Node 22 Bookworm image
  manifest and an exact `actions/checkout` commit. The lock explicitly carried
  no formal-foundation or qualification authority.
- The complete bootstrap portfolio passed inside that pinned Linux/amd64 image
  on 2026-09-19, against a mounted working tree.
- The hosted workflow has since been removed. That observation stands as a
  record of what happened on that date; nothing re-checks it, and no
  clean-checkout reproduction is performed after a commit. The portfolio is run
  locally. `toolchains/CLEAN_ROOM.json` still records the image and checkout
  identities that were used, but those fields no longer pin anything.
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
- Acceptance can carry a value. The decision result holds the kernel's accepted
  type, and `Unit` still carries no representation, so a Unit-accepting kernel
  keeps exactly the established two-octet shape and the minimum-age C is
  unchanged. A bare accepted octet array is rejected with a diagnostic that
  says to wrap it in a record, since C cannot assign one.
- Record construction is connected end to end. `Type { field: value, ... }`
  builds a value whose fields the checker requires to be supplied exactly once
  with matching types. Constructor fields are keyed by `FieldRef` and must be
  strictly increasing, so the literal's own field order is free and emission
  is canonical. A permit-issuing kernel derives `(17,121,7,0)`, which the
  independent checker reproduces, and the generated C carries exactly the
  inputs the kernel granted across every tested case.
- A defect found by compiling a kernel that used every implemented form: the
  emitter referenced type aliases as declared types. An alias is a transparent
  synonym and typed-core formation rejects a `Declared` reference to one, so
  `build` was producing modules the admission checker refuses while reporting
  success. Aliases are now expanded at use sites and nominals are left opaque,
  which is also the correct typing rule: an alias is interchangeable with its
  representation and a nominal is not.
- Two further defects from compiling the generated C rather than trusting it.
  C has no array assignment, so an octet binding now names the octets with a
  pointer instead of copying them, and an octet record field is written with a
  copy helper rather than inside a compound literal. Both previously produced C
  that did not compile.
- `spec/language/examples/access_permit.seki` is now the worked example: two
  nominals over the same digest representation, an alias, an eight-field
  record, four ordered rejections, bindings, three `require` premises, a
  short-circuit condition, and a permit carrying the identity it granted. It
  derives `(38,2640,11,0)`, the independent checker accepts it, its C compiles
  strictly, and its decisions match the stated policy on every tested case.
- The generated decision carries a stable ABI, at the request of the Grit
  consumer, who needs a shadow oracle to compare more than accept against
  reject. It is `abi_revision`, `disposition` (1 accepted, 2 rejected),
  `rejection_tag` and `premise_tag`, all `uint32_t`, followed by the accepted
  value. Disposition zero is never written, so an all-zero decision is
  recognisably uninitialised. The whole decision is zeroed before any field is
  set. That makes padding and inactive union bytes zero on the toolchains
  tested, but C does not guarantee they stay zero once a member is stored
  (C11 §6.2.6.1), so a portable comparison uses the defined fields; see the
  corrected host-boundary contract below.
- `premise_tag` reports which premise failed as its one-based precedence
  position, which is exactly what structural `check_order` already guarantees
  to be deterministic.
- The E0 naming compatibility case is gone. It existed only to hold one byte
  regression that this ABI supersedes, and it made one program's C differ from
  every other's. The alpha now records its own regression artifact under
  `tests/alpha/regression/`; the E0 experiment's artifacts stay frozen as its
  evidence. The typed core is unchanged and still byte-identical to E0's 417
  bytes: the semantic root did not move, only the C projection.
- Rejections can carry a typed payload, so a decision reports which value
  failed and against what rather than only that a premise failed. Construction
  mirrors declaration: declarations spell a payload in parentheses, so
  construction does too, exactly as records use braces in both positions. The
  surface draft lists payload construction syntax as an open question, so this
  resolves a spelling rather than adding a form: the subset already admits
  variant construction and single-payload cases.
- Each payload-bearing case becomes a C struct and the decision holds a union
  of them. Only one is ever live and the whole decision is zeroed first. The
  consumer asked for inactive members to be byte-comparable; C does not
  guarantee that, and the host-boundary contract now says so.
  The ABI is revision 2.
- Emitting a payload found that declared payload fields were written in source
  order. They are keyed by name and must be strictly increasing, so a case
  declared `(limit, actual)` now emits `actual, limit`. Nothing had exercised a
  payload table before, so this had never been reachable.
- Exhaustive `match` over a declared variant is connected end to end. Arms must
  cover every case exactly once, so a missing arm and a repeated one are the
  same failure, and the generated `switch` needs no default because no admitted
  value can carry a tag outside the declaration. A three-case kernel derives
  `(11,28,5,0)`, which the independent checker reproduces.
- This needed variant values to exist in C first, and that exposed a defect: a
  record field of variant type named a C type the projection never defined, so
  `build` reported success while emitting source that did not compile. A
  variant value is now its stable tag plus, where any case carries one, a union
  of payloads. The rejection variant is still projected into the decision
  result instead and needs no type of its own.
- Matching a payload-bearing case is rejected as `A0-CHECK-0028` rather than
  silently dropping the binder. The surface spells a binder as a block
  parameter and this revision does not implement one; failing closed keeps the
  gap visible.
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

- The host-boundary contract is written and frozen at revision 1:
  `docs/alpha/HOST_BOUNDARY_CONTRACT.md`. Its headline is the assertion the
  Grit consumer asked for explicitly: a kernel consumes already-authenticated
  identities and never authenticates anything itself. It cannot verify a
  signature, recompute a digest, read a file, consult a clock, or observe
  anything outside its one parameter value. Authority for authentication rests
  entirely with the host; Seki narrows what a decision means and does not widen
  what the host established.
- The contract also states the Boolean rule: nominal identity types carry
  evidence, a `Bool` input does not. A kernel whose decision turns on a `Bool`
  parameter has delegated the decision back to its caller. That is a contract
  on the host, not yet a compiler check, and the contract says so.
- `check-host-boundary` verifies every mechanical claim in the contract against
  what the compiler emits: the ABI revision, the decision's leading fields and
  their order, the zeroing guarantee, parameter passing, canonical field order
  in every emitted struct, authored stable tags, and that a failed build writes
  neither output. The contract cannot drift from the compiler without `make
  check` failing. The prose assertions about what Seki does not do are
  deliberately not machine-checked: no test establishes them, and the checker
  says so rather than implying coverage it does not have.

- `sekic build` can now emit a public header beside the implementation:
  `--header OUT.h` writes the declarations a consumer integrates against, and
  the translation unit includes it by a module-derived name so nothing depends
  on where either file is written. Both forms come from one emitter, so the
  declarations cannot drift between them. Without `--header` the translation
  unit stays self-contained exactly as before.
- `make bundle KERNEL=...` assembles a consumer bundle: the exact compiler
  sources that produced the artifacts, the kernel source, typed core, generated
  C and public header, the tag dictionary, the frozen host-boundary contract,
  and a manifest binding every file by SHA-256. The compiler binary is
  deliberately absent because it is platform specific.
- Each bundle carries `VERIFY.sh`, which checks every digest, rebuilds the
  compiler from the carried sources, confirms that rebuild reproduces the
  artifacts byte for byte, and compiles the generated kernel. It leaves the
  bundle as it found it, so it can be run repeatedly.
- `check-bundle` verifies the three properties that make it a bundle rather
  than a directory: it verifies itself, it detects tampering with any carried
  file, and assembling it twice under a different locale and timezone produces
  the same manifest digest.
- The manifest states its own ceiling: the generated C is not proved to
  preserve the kernel's semantics, and the bundle carries no implementation,
  proof, product or production authority.

- `docs/alpha/QUICKSTART.md` is written: build the compiler, write a kernel,
  compile it, call it from C, read the diagnostics, ship a bundle, and what is
  not established. It is one annotated worked example rather than a reference.
- `check-quickstart` extracts the kernel and the calling code from the document
  and runs them: the kernel checks and builds, the caller compiles against the
  generated header, every diagnostic the table names is one the compiler can
  actually emit, and the disclosure that the C is unproved is still present. A
  quickstart that does not compile is worse than none, because a reader trusts
  it before they trust the compiler.
- Writing it found a false claim in its own draft: it told the reader to read
  the exact derived cost from `sekic inspect`, which did not report it. Rather
  than weaken the sentence, `inspect` now reports `exact_bounds` and
  `declared_ceiling`, so the figure `A0-CHECK-0017` complains about can be read
  without rebuilding anything.

- The host-boundary contract is corrected to revision 2. Re-reading it before
  sending VISION.md to consumers found five statements stronger than what is
  true, all now corrected and each recorded in the contract's revision history:
  nominal distinctness is a guarantee about what a kernel does, not a C
  type-system property; a non-admitted value returns `disposition` `0`, which
  revision 1 said could not happen; decisions do not portably compare equal
  under `memcmp`, because C11 §6.2.6.1 leaves padding and inactive union bytes
  unspecified once a member is stored; the kernel is total over admitted values,
  not every value of its parameter type; and `premise_tag` is set only for
  rejections produced by `require`.
- The `memcmp` claim is worth recording for its shape. It rested on a simple
  model of C — zero the decision first and its bytes are deterministic — and a
  test on one compiler confirmed it. The standard does not. The Grit consumer
  asked for byte comparison, so this is a finding for them, not only a wording
  fix: portable byte comparison would need a layout with no implicit padding
  and no union, which would be a new ABI revision.
- No layout and no field meaning changed, so the decision ABI stays at revision
  2. The contract's rotation rule is decoupled accordingly: a correction to what
  the contract says rotates the contract; a change to the layout or a field's
  meaning also rotates the ABI. Coupling them would have told every consumer
  their decision had changed when it had not.
- `check-host-boundary` now runs a kernel to pin both new contract terms: an
  undeclared variant tag returns `disposition` `0`, and a rejection from
  `reject` has `premise_tag` `0` while one from `require` names its premise.

## Active work

`E0-VS1` is complete experimentally. A0-02 is active: extract its program-shaped
C code into a reusable compiler core and general `sekic` CLI. F0 remains open;
the Grit Stage 1 publication decision remains the selected independent case.
External field validation begins only after internal release-candidate
certification. All current alpha work is replaceable and cannot freeze
conformance.

## Next unblocked tasks

1. Grit applies the alpha to a real shadow kernel and reports back.
2. The generic typed-core to generated-C refinement proof, which is the
   consumer's stated production blocker and remains open.
3. Freezing the subset, encoding and C ABI together once that proof exists.

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
passed locally on 2026-09-21, including the E0 Lean proof under the pinned
toolchain. There is no hosted CI: `make check` is run by hand.
The alpha compiler additionally passed 4,400 source and 4,900 typed-core
mutation cases across the minimum-age, nested three-premise, wide-integer,
four-declaration, two-digest, short-circuit Boolean, nominal-identity,
require-premise, binding, permit-issuing, payload-rejection, and match kernels under AddressSanitizer and UndefinedBehaviorSanitizer with no finding,
after the two stack-exhaustion defects that earlier sweeps found were fixed.
