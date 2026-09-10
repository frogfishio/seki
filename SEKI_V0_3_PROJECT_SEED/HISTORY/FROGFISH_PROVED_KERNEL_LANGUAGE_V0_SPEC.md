# Frogfish Proved Kernel Language v0

Status: v0.1 design revision responding to Kiku review; F0 remains open; no
implementation or proof authority granted

Working identity: `FROGFISH-PROVED-KERNEL-LANGUAGE-V0`

Working abbreviation: `FPKL`. The product name is provisional.

First qualification vertical: Kiku Arena causal-provider decision

Required second vertical: a materially different kernel from Kiku, SIRCC,
Tenkan or another consumer

Revision v0.1 resolves four architectural boundaries identified by Kiku:

1. generated C semantics are anchored to CompCert Clight rather than an
   independently invented C-like evaluator;
2. the canonical serialized typed-core AST is the semantic authority root;
3. Profile C removes ordinary host C from authority-bearing semantic
   extraction unless a separately machine-checked adapter covers it; and
4. publication is governed by a formal single-use state machine.

This revision also adds proved space bounds, deterministic rejection
precedence, bounded graph traversal as a proved library, the initial native
toolchain trust ceiling and the Kiku checked-unit closure requirements.

## 1. Mission

The Frogfish Proved Kernel Language exists to make small, critical decisions
portable, executable and machine-checked.

An FPKL module is written once and deterministically produces:

```text
typed FPKL source
├── executable Lean definition
├── Lean semantic and refinement theorems
├── portable C11 source and header
├── C-to-Lean representation manifest
├── theorem dependency and trust report
└── checksum-closed build manifest
```

For every admitted input, the principal product claim is:

```text
generated_C_decision(input) = FPKL_semantics(input)
                            = generated_Lean_decision(input)
```

If a module defines publication eligibility, the additional claim is:

```text
generated_C_publishes(input) ↔ FPKL_semantics_publishes(input)
```

FPKL is intended for authority decisions, validators, normalizers, bounded
protocol transitions and other compact semantic kernels embedded in ordinary
systems. It is not intended to replace Kiku, C, Lean, SIR, LLVM or a general
application language.

## 2. Opportunity and motivating boundary

Gnosis and its customers increasingly have exact Lean specifications and
production C implementations, but lack a machine-checked connection between
them. Tests can show agreement on selected inputs. They cannot prove that the
actual C implementation agrees with the Lean decision for every admitted
input.

The Kiku Arena causal-provider request makes this gap concrete. Kiku supplied
an executable Lean predicate with soundness, completeness, publication
equivalence and hostile rejection theorems. Gnosis can implement the same
field-level decision in C and model that decision in Lean. Without a proved
source-generation bridge, however, the C implementation and Lean model remain
two independently maintained programs.

FPKL removes that duplication. The authoritative implementation is the FPKL
program. C and Lean are generated projections of the same typed semantic
object.

The wider opportunity is reusable across Frogfish projects:

- Gnosis can implement authority-granting decision kernels.
- Kiku can implement compiler checks and consume generated C kernels.
- SIRCC can implement target-neutral validation and legalization-entry gates.
- Tenkan can implement bounded source/target correspondence judgments.
- Other systems can embed proved decisions without adopting Lean as their
  implementation language or runtime.

## 3. Scope ceiling

FPKL v0 may claim correctness only for generated artifacts produced from an
accepted FPKL module under the exact pinned toolchain and profile.

FPKL v0 may support claims about:

- parsing and typechecking FPKL source;
- total and deterministic evaluation;
- absence of unbounded execution in admitted programs;
- explicit fixed-width arithmetic semantics;
- semantic preservation by the supported C11 generator;
- semantic equality of the generated Lean definition;
- representation correspondence between admitted C values and Lean values;
- exact accept/reject results;
- exact publication eligibility;
- zero semantic publication on rejection;
- deterministic source generation; and
- binding of source, proofs, manifests and toolchain identities.

FPKL v0 does not, merely by existing, prove:

- arbitrary handwritten C;
- arbitrary Kiku, SIR, C++, Rust or other source programs;
- a complete compiler or language implementation;
- correctness of an external C compiler, assembler, linker, operating system
  or processor;
- memory safety of a host application;
- authentication of host evidence not decoded by the FPKL kernel;
- correctness of external cryptographic primitives;
- ABI lowering outside the frozen generated interface;
- concurrency, scheduling or distributed-system correctness; or
- customer acceptance without the installed customer vertical.

Every release must state which compiler and runtime components remain in its
trusted computing base.

## 4. Non-goals

FPKL v0 is not:

- a general-purpose programming language;
- a theorem-prover replacement;
- an unrestricted systems language;
- a language for user interfaces, networking or application orchestration;
- an object-oriented language;
- a macro or metaprogramming platform;
- an arbitrary C verifier;
- a vehicle for silently importing host-language assumptions; or
- a Gnosis-, Kiku-, Arena- or GCIR-specific DSL.

Domain concepts such as resources, obligations, loans, compiler nodes and
pointer permissions belong in versioned libraries written on top of the core.

## 5. Governing design principles

### 5.1 One semantic source

The FPKL typed module is the unique semantic implementation. Generated C and
Lean files are outputs, not separately editable implementations.

### 5.2 Pure decisions before effects

An FPKL kernel receives immutable decoded inputs and returns an immutable
result. Authentication, allocation, cancellation polling and publication are
explicit boundary operations and cannot be hidden inside pure evaluation.

### 5.3 Totality by construction

Every admitted function terminates. General recursion and unbounded loops are
forbidden. Iteration is expressed through statically bounded combinators.

### 5.4 Semantic portability

Integer overflow, equality, ordering, absence, enumeration tags and collection
bounds have FPKL-defined meanings. They may not depend on C undefined,
unspecified or implementation-defined behaviour.

### 5.5 Nominal identity domains

Byte-identical values from different identity domains are not interchangeable.
Resource identity, place identity, epoch identity and type identity must be
distinct nominal types unless an explicit proved correspondence relates them.

### 5.6 Rejection is atomic

Failure, ambiguity, cancellation, exhaustion or malformed input produces no
authority-bearing output. Candidate construction occurs before host
publication.

### 5.7 Proofs do not silently cross boundaries

A model theorem is not a representation theorem. A representation theorem is
not an installed-binary theorem. An installed-binary theorem is not customer
acceptance.

## 6. Compilation architecture

The semantic authority root for v0 is:

```text
canonical serialized typed-core AST
```

Textual FPKL source is a developer interface, not the semantic authority root.
The initial surface parser and elaborator may be untrusted proof producers.
They must emit the canonical typed-core object plus complete type, import,
totality and bound derivations. A small verified admission checker reopens
those derivations and either admits the typed core or rejects it.

The normative pipeline is:

```text
FPKL UTF-8 source
  ↓ initially untrusted parser and elaborator
surface AST
  ↓ typed-core construction plus derivation witnesses
canonical serialized typed-core AST
  ↓ verified admission checker
admitted semantic module authority root
  ├── Lean projection and proofs
  ├── CompCert-Clight-compatible restricted C projection
  ├── representation schema
  ├── source correspondence portfolio
  └── deterministic build manifest
```

Canonical serialization must be injective over admitted typed-core values,
reject duplicate field labels and impose deterministic field ordering. The
admission checker must verify types, bounds, totality, imported module digests,
derivation witnesses and semantic-profile identity.

Surface parser or elaborator compromise may cause rejection or produce a
different proposed typed core. It must not cause the verified checker to admit
an ill-typed, unbounded or falsely derived module.

The compiler must reject rather than approximate any construct unavailable in
the selected backend or proof profile.

## 7. Core data model

### 7.1 Primitive types

FPKL v0 provides:

```text
Unit
Bool
U8 U16 U32 U64
I8 I16 I32 I64
Bytes[N]
Identity[Domain, N]
Digest[Algorithm, N]
Index[Bound]
```

`N` and `Bound` are compile-time natural numbers within the implementation
profile ceiling.

Floating point, platform-sized integers, native pointers, character locale
semantics and arbitrary-precision integers are excluded from v0 kernel code.
They may be considered later only with explicit semantics and backend proofs.

### 7.2 Composite types

FPKL v0 provides:

```text
record
variant
Option[T]
Result[T, E]
Tuple[T1, ... Tn]
Array[T, N]
BoundedVec[T, N]
```

Records have declaration-order-independent semantic equality. Generated C
layout order is frozen in the representation manifest but never defines FPKL
semantic equality.

Variants have explicit stable tags. Unknown tags fail decoding and cannot be
coerced to a known case.

### 7.3 Nominal types

Type aliases do not create authority. A nominal declaration creates a distinct
type:

```text
nominal ResourceId = Identity[Resource, 16]
nominal PlaceId    = Identity[Place, 16]
nominal EpochId    = Identity[Epoch, 16]
```

No implicit conversion exists between nominal domains, even when their wire
representations are identical.

### 7.4 Absence

Absence is represented by `Option[T]`, not by a distinguished all-zero value,
unless the schema explicitly defines zero as the canonical absent encoding.
The representation manifest must distinguish semantic absence from a present
zero value.

## 8. Expressions and control flow

FPKL v0 expressions include:

- literals;
- immutable local bindings;
- record and variant construction;
- field projection;
- nominally typed equality and inequality;
- boolean operators with defined short-circuit semantics;
- fixed-width arithmetic with an explicit overflow policy;
- comparison;
- pattern matching;
- pure function calls;
- bounded collection access returning `Option` or `Result`; and
- bounded folds, maps, filters and unique-selection operations.

Conditionals and matches are expressions. Every branch must produce the same
type.

Mutable variables, exceptions, `goto`, fall-through switches and implicit
control transfer are excluded.

## 9. Arithmetic

Every arithmetic expression declares or inherits one of these policies:

```text
checked     overflow returns an explicit error
wrapping    modulo 2^N
saturating  clamps to the type bound
```

Implicit integer promotion is forbidden. Mixed-width operations require an
explicit checked conversion. Division by zero, invalid shift counts and failed
conversions return typed rejection values; they never invoke backend undefined
behaviour.

## 10. Collections, bounds and totality

Every collection has a static maximum. Runtime length is checked against that
maximum during decoding.

Permitted iteration forms are:

```text
fold(array, initial, step)
findUnique(array, predicate)
all(array, predicate)
any(array, predicate)
mapBounded(array, function)
filterBounded(array, predicate)
```

The generated evaluator must consume at most a statically derived number of
logical steps. It must also have proved maximum live-value, temporary-storage,
caller-owned workspace and generated-stack bounds. A module manifest records
all ceilings and the derivation used to obtain them. Hidden generated stack
growth is forbidden; caller-owned bounded workspace is preferred when a
kernel requires material scratch storage.

User-defined recursion is excluded from v0. Library combinators are admitted
only with a proved termination and bound theorem.

Bounded graph traversal is a proved standard-library facility, not an
unrestricted core control construct. Its graph-size, edge-count, worklist,
visited-set, iteration, space and stack ceilings are explicit type or module
parameters. Exhaustion is a typed operational result and publishes nothing.

## 11. Results and rejection

Kernel entry points return a declared result type, normally:

```text
variant Decision[Accepted, Rejection] {
  accept(Accepted),
  reject(Rejection),
}
```

Rejection is data, not an exception. A rejection schema must provide stable
status and reason values and may include non-authorizing diagnostics.

Operational outcomes are distinct from semantic rejection:

```text
semantic rejection
malformed input
unauthenticated input
ambiguous evidence
configured limit
cancelled
allocation failure
host failure
```

The host wrapper may map these classes to project-specific statuses, but the
mapping must be versioned and proved complete.

Every exported kernel freezes a total rejection-precedence order. When several
conditions fail, every backend must select the same highest-precedence result.
Evaluation order, collection order and host discovery order cannot change the
reported status or reason. The generated portfolio includes a theorem that
the precedence relation is total, deterministic and respected by the emitted
Lean and C projections.

## 12. Effects and host boundary

FPKL v0 kernel evaluation has no ambient effects. It cannot:

- allocate through an unbounded heap;
- mutate host memory;
- publish authority;
- read clocks, randomness, files, environment variables or network state;
- call arbitrary foreign functions; or
- inspect pointer addresses.

The host interaction is stratified:

```text
host supplies opaque authenticated handles
→ generated FPKL or proved adapter reopens every semantic view
→ checked decoder constructs FPKL input
→ pure FPKL kernel returns candidate decision
→ generated transaction constructs complete candidate and receipt material
→ confined host primitive commits atomically
```

For Profile C, ordinary host C may not choose, rewrite or populate an
authority-bearing semantic field. Every such field is decoded and verified by
generated FPKL code or by a minimal adapter with its own machine-checked
refinement proof. Authentication of an opaque handle does not authenticate a
semantic view extracted from it.

Publication remains an explicit host commit point governed by the formal
protocol in section 20.

Cancellation does not occur through an arbitrary callback inside a pure
kernel. In v0 it is sampled only at generated transaction boundaries:

1. before authenticated decoding;
2. after decoding and before pure evaluation;
3. after private candidate construction and before commit.

The cancellation observation is an explicit driver input. Cancellation at any
boundary before commit leaves publication state unchanged. Adding finer
checkpoints requires a new effect-aware profile and proof.

No Boolean returned by an unauthenticated caller can grant authority.

## 13. Module system

An FPKL module declares:

- module identity and semantic version;
- imported module identities and exact digests;
- nominal identity domains;
- public data schemas;
- pure functions;
- exported kernels;
- selected backend profile;
- maximum input and execution bounds;
- required theorems; and
- claim ceiling.

Imports are checksum-bound and acyclic. Wildcard imports, mutable package
resolution and ambient search paths are forbidden in qualified builds.

The canonical module serialization sorts field-labelled semantic records by
their canonical labels and rejects duplicate labels. Source declaration order
does not affect semantics. Import identities, typed declarations, derivations,
bounds and selected semantic profile are all included in the canonical
typed-core digest.

An import may expose definitions and proved theorems. Importing a theorem does
not expand the importing module's claim beyond the theorem's declared premise
and trust closure.

## 14. Illustrative syntax

Syntax is provisional; semantics take precedence over surface form.

```text
module frogfish.examples.arena_provider@1

nominal ResourceId = Identity[resource, 16]
nominal PlaceId = Identity[place, 16]
nominal EpochId = Identity[epoch, 16]

record Installation {
  ownerResource: ResourceId,
  ownerPlace: PlaceId,
  ownerEpoch: EpochId,
  backing: Backing,
}

record ArenaProviderInput {
  adoption: OwnerPreservingAdoptionInput,
  dependency: RegionDependencyInput,
}

kernel verifyArenaProvider(input: ArenaProviderInput)
    -> Decision[CausalArenaAuthority, ArenaRejection]
    bounded steps <= 4096 {
  require verifyOwnerPreserving(input.adoption)
    else reject(ownerPreservationFailed)

  require verifyRegionDependency(input.dependency)
    else reject(regionDependencyFailed)

  require input.dependency.installation == input.adoption.installation
    else reject(installationMismatch)

  accept(CausalArenaAuthority {
    adoption: input.adoption.authority,
    dependency: input.dependency.authority,
  })
}
```

The example does not grant Gnosis authority by itself. A selected Gnosis
adapter must authenticate and decode every input before invoking the generated
kernel and must publish only after complete candidate construction.

## 15. Lean projection

The Lean backend must emit:

- one Lean type for every admitted FPKL type;
- an executable Lean definition for every function and kernel;
- an evaluator correspondence theorem;
- totality and determinism theorems;
- bound theorems;
- serialization/representation theorems where selected;
- exact publication-equivalence theorems for publication kernels;
- a theorem dependency graph;
- an axiom audit; and
- exact Lean toolchain and dependency identities.

Generated theorem declarations must be classified as:

1. model-internal;
2. representation-correspondence;
3. implementation-refinement;
4. evidence-authority; or
5. product-closure.

No `sorry`, `admit`, project-local axiom, unsafe proof escape or silent gap
erasure is permitted in a qualified portfolio.

An unsupported proof obligation becomes an explicit typed gap and prevents the
corresponding claim.

## 16. Restricted C11 backend

The C backend emits a frozen subset of C11:

- fixed-width `<stdint.h>` integers;
- `_Bool`/`bool` with explicit conversion;
- plain records with generated field access;
- explicit enum tags using frozen integer widths;
- bounded `for` loops whose upper bounds were proved;
- generated field-wise equality functions;
- explicit checked arithmetic helpers;
- `const` input pointers and caller-owned output storage;
- no variable-length arrays;
- no recursion;
- no pointer arithmetic except generated bounded array indexing;
- no type-punning, unions or strict-aliasing dependence;
- no structure-wide byte comparison;
- no reads of padding bytes;
- no signed overflow;
- no uninitialized reads;
- no hidden allocation; and
- no undefined or implementation-defined decision semantics.

The C generator must emit static assertions for selected width, tag and layout
properties. A representation manifest states which layout facts are semantic
and which remain ABI assumptions.

Generated C files carry a non-editable banner and embed:

- FPKL module identity;
- typed-core digest;
- generator identity;
- semantic profile identity; and
- representation-manifest digest.

## 17. C semantic-refinement obligation

The core proof obligation is not satisfied by comparing finite traces.

FPKL v0 selects the mechanized CompCert Clight semantics as its recognized
formal C foundation. Clight is a simplified C language with pure expressions
and a mechanized operational semantics, and is an input language of the
CompCert verified compiler. The normative references are the official
[Clight semantics](https://compcert.org/doc/html/compcert.cfrontend.Clight.html)
and [CompCert documentation](https://compcert.org/doc/).

The v0 C surface remains portable C11-compatible source, but qualified modules
are restricted to the subset for which FPKL proves an exact embedding into the
pinned Clight AST and semantics. This is not a claim about arbitrary ISO C11.

The required chain is:

```text
canonical FPKL typed-core semantics
= restricted-C AST semantics
= embedded CompCert Clight semantics
= verified parse of the exact emitted C bytes
```

FPKL must prove that generation preserves evaluation under the selected
Clight semantics. The proof shape is conceptually:

```lean
theorem cGenerationPreservesEvaluation
    (m : AdmittedModule) (input : m.Input) :
    evalClight (embedRestrictedC (generateC m)) (encodeInput input) =
      encodeResult (evalFPKL m input)
```

The exact emitted bytes are not authenticated by a generator digest alone.
The restricted backend must provide:

1. a verified canonical pretty-printer;
2. a verified parser for the emitted restricted-C grammar;
3. `parse(print(ast)) = ast` for every admitted backend AST;
4. rejection of noncanonical or out-of-profile source;
5. a proved embedding from the parsed AST into pinned CompCert Clight; and
6. a semantic-preservation theorem between that embedding and the canonical
   typed-core evaluator.

The initial proof portfolio may span Lean and Rocq because CompCert is
mechanized in Rocq. Both sides must consume the same canonical serialized
typed-core authority root through verified admission checkers. The release
must bind both proof-assistant versions, both theorem closures and the exact
cross-foundation representation mapping. Matching definition names, generated
test vectors or independent handwritten models do not establish the bridge.

A separately handwritten C-like Lean function remains insufficient.

The initial implementation may treat the external C compiler as part of the
declared trusted computing base. It may not claim that the native binary is
proved correct unless a verified compilation or translation-validation stage
establishes that additional relation.

## 18. Representation correspondence

For each exported kernel, a machine-readable manifest maps:

```text
FPKL type and field
↔ Lean type and projection
↔ C type and field
↔ wire encoding, if any
```

The manifest records:

- nominal domain;
- width and signedness;
- presence/absence representation;
- variant tag;
- bounds;
- equality rule;
- normalization rule;
- endianness where serialized;
- source theorem;
- generated C symbol; and
- whether the field is authoritative, diagnostic or reserved.

CI fails when an authoritative field exists in only one representation or when
two nominal domains are mapped to the same semantic type without an explicit
correspondence theorem.

## 19. Authentication and authority ceiling

FPKL proves decisions over admitted semantic inputs. It does not automatically
authenticate the origin of those inputs.

Every integration must declare one of these profiles:

### Profile A: decoded decision

The host authenticates and decodes inputs. FPKL proves only the decision over
the decoded value. Host decoding remains in the trusted base.

### Profile B: checked decoding

Generated code validates a public bounded representation and constructs the
semantic input. FPKL proves decoding determinism, completeness and rejection.
The host must still authenticate any opaque provider handles.

### Profile C: authority transaction

Generated code consumes opaque authenticated handles through a frozen minimal
adapter, independently verifies every authority-bearing semantic view,
performs checked decoding and decision, constructs a candidate authority and
returns an opaque commit token. The host may publish only that complete token.

An adapter participating in Profile C must have a machine-checked refinement
proof covering every extracted semantic field and relation. An ordinary C
accessor, authenticated handle, successful provider status or caller-supplied
Boolean is not sufficient. Host code may transport handles and storage, but
may not select candidates, invent correspondences, rewrite identities or
construct semantic authority input.

The Kiku Arena production vertical ultimately requires Profile C. Profile A is
useful for developing the language but cannot close the current Q3-to-Q5
boundary by itself. Its complete eleven mapping groups—obligations and
witnesses, backing, installation, structural owner, two adoption endpoints,
selected outcome and subject, returned Region, two dependency-effect
reconstructions and exact installation composition—must be inside generated
FPKL or separately proved minimal adapters.

## 20. Publication and receipt protocol

A qualified authority kernel must distinguish:

```text
decision result
candidate authority
publication commit
receipt
receipt verification
```

The generated decision cannot mutate publication state. The wrapper must:

1. validate the request and selected package;
2. authenticate every opaque prerequisite;
3. decode the complete FPKL input;
4. evaluate the proved kernel;
5. construct the authority and receipt privately;
6. commit all outputs atomically; and
7. release all private candidates on any failure.

Receipt verification must reopen the exact normalized input identity and
decision without creating new authority.

### 20.1 Formal publication machine

FPKL v0 defines a versioned publication state machine:

```text
Idle
  ├── reject/fail/cancel/exhaust → Idle
  └── accepted complete input   → Candidate

Candidate(inputDigest, candidateDigest, privateCandidate)
  ├── reject/fail/cancel        → Idle
  └── consume exact token       → Committed

Committed(inputDigest, authorityDigest, receiptDigest)
  └── verify receipt            → Committed
```

The corresponding abstract types are distinct and noninterchangeable:

```text
CandidateAuthority[Input, Authority]
CommitToken[InputDigest, CandidateDigest]
PublishedAuthority[AuthorityDigest]
Receipt[InputDigest, AuthorityDigest, VerifierIdentity]
```

The commit token is opaque, exact-input-bound and single-use. In the formal
semantics, commit consumes it linearly. In the generated C wrapper, its private
state includes an unforgeable transaction identity and a consumed marker; the
host receives no writable semantic view.

### 20.2 Mandatory publication theorems

Every Profile C module proves:

- only an accepted complete candidate can construct a commit token;
- a token can commit at most once;
- a token cannot commit a different candidate or input;
- host mutation cannot change candidate semantics;
- no alternate exported host function can publish equivalent authority;
- rejection, cancellation, limit exhaustion and failure before commit leave
  publication state unchanged;
- allocation failure during private construction or commit publishes nothing;
- successful commit publishes exactly one complete authority and receipt;
- receipt verification preserves the committed state and grants no new
  authority; and
- release of a candidate or receipt cannot publish authority.

The installed symbol inventory is part of the confinement proof. Exporting an
unproved alternate publication entry point invalidates the profile.

### 20.3 Host-wrapper refinement

The minimal host wrapper requires its own source-refinement obligation. It may
perform bounded storage management, transport opaque handles, sample explicit
cancellation inputs and invoke the generated commit primitive. It may not
inspect or reconstruct candidate semantics. The proof must show that every
host-visible transition refines one transition of the formal publication
machine.

## 21. Determinism and reproducibility

Qualified builds require:

- canonical parsing and elaboration;
- deterministic name and identity derivation;
- deterministic ordering of generated definitions and fields;
- stable formatting;
- normalized archive metadata;
- byte-identical repeated assembly;
- checksum closure;
- exact source and toolchain manifests; and
- clean-extraction verification.

Host paths, timestamps, locale, process identifiers and allocation addresses
must not affect semantic or artifact identities.

## 22. Security and hostile requirements

Every exported kernel must include generated hostile cases covering applicable
classes:

- malformed and truncated input;
- unknown schema or variant;
- missing evidence;
- duplicate or ambiguous candidates;
- stale, foreign or substituted identities;
- nominal-domain substitution with identical bytes;
- reordered inventories;
- configured-bound exhaustion;
- cancellation at each permitted checkpoint;
- allocation failure in the host wrapper;
- receipt tampering;
- compiler/profile/toolchain substitution; and
- partial-publication attempts.

Property-based testing and fuzzing are required supporting evidence but do not
replace the universal generator proof.

## 23. Qualification ladder

### F0 — Charter freeze

Freeze mission, scope, canonical typed-core authority root, syntax subset,
CompCert Clight semantic foundation, dual-proof-foundation mapping, trust
ceiling, publication machine and forbidden claims.

### F1 — Lean semantic core

Implement the canonical typed-core schema, verified admission checker,
evaluator, totality, determinism, rejection-precedence, logical-step, space and
stack-bound proofs.

### F2 — Representation model

Implement C and Lean value representations, nominal-domain preservation,
canonical typed-core serialization, encoding/decoding, duplicate-label
rejection and injectivity proofs.

### F3 — Restricted C generator

Generate the Clight-compatible C11 subset; implement the verified canonical
printer and parser; prove exact emitted-byte-to-AST correspondence.

### F4 — Generator refinement

Prove generated restricted-C evaluation equals FPKL evaluation for every
admitted module and input under the pinned CompCert Clight semantics. Close the
Lean/Rocq canonical typed-core representation bridge without theorem-by-name or
finite-vector trust.

### F5 — Toolchain and artifact closure

Produce deterministic compiler artifacts, installed C11/C++17 consumers,
manifests and exact trust reports. Bind compiler, assembler, linker, flags,
target, runtime, headers, ABI, platform, objects, archives and final binaries.
The initial claim remains source-proved/native-toolchain-trusted.

### F6 — Arena reference vertical

Implement the complete owner-preserving backing adoption, Region dependency
and exact-installation composition under Profile C, including all eleven
authority-bearing decode groups and the formal single-use publication machine.
Pass the frozen Kiku semantic and hostile matrix without numbering a Gnosis API
prematurely.

### F7 — Independent second vertical

Implement a materially different kernel. It must exercise different data and
control-flow features and come from a different consumer or domain.

### F8 — Product freeze

Freeze v1 only after both verticals, clean-room reproduction, threat review,
performance bounds and claim-ceiling audit pass.

## 24. First reference vertical: Arena causal provider

The first vertical is the exact Kiku predicate:

```text
owner-preserving backing adoption
+ later Arena→Region dependency
+ exact retained installation equality
→ causal Arena provider decision
```

The vertical must preserve independently:

- original obligation owner resource, place, storage and epoch;
- inner adoption call, subject and coordinate;
- Structural Storage root and destination;
- returned Region resource and coordinate;
- complete obligation kind and holder;
- exact backing payload and producer event; and
- exact dependency identity and invalidation rule.

It must not reinterpret API 131, equate coordinate domains, select by array
order or place equality, or treat successful customer execution as authority.

Passing the decoded decision is only an F1/F2 milestone. Production closure
requires checked decoding, atomic publication, installed receipt replay and
the unchanged before/after-release Kiku vertical.

## 25. Required second vertical

FPKL must not become Kiku's or Gnosis's private checker. Before v1, a second
vertical must demonstrate reuse.

Good candidates include:

- SIRCC Checked Core Pointer Authority terminal disposition;
- a target-neutral SIR legalizer-entry validator;
- Tenkan source-to-generated-Kiku correspondence selection; or
- a bounded Kiku compiler semantic-inventory consistency check unrelated to
  Arena resources.

The second vertical must introduce at least two capabilities not trivialized by
the Arena implementation, such as nested variants, bounded graph traversal,
multi-error normalization or a different nominal identity family.

## 26. Kiku integration

Kiku may interact with FPKL in four distinct roles:

1. consumer of generated C kernels;
2. producer of authenticated semantic inputs;
3. frontend emitting FPKL modules for selected Kiku declarations; or
4. future native backend for FPKL typed core.

These roles grant different authority. In particular:

- Kiku compilation success is not an FPKL proof;
- a Kiku-emitted Lean sidecar is not correspondence authority by itself;
- FPKL cannot reuse Kiku's GCIR adapter receipt;
- Lean acceptance does not prove the Kiku-to-FPKL translation; and
- a future FPKL-to-Kiku backend needs its own generator-refinement theorem.

The first Kiku source-to-FPKL correspondence input is reserved as:

```text
KikuResourceProtocolInventoryV1
```

It is product-neutral and contains nominal resources and state families,
transitions, produce/preserve/consume/dependency effects, obligation creation
and discharge, dependency invalidation, coordinate-domain declarations, exact
source-occurrence anchors, bounds and completeness commitments.

Kiku's initial translation into this inventory is an untrusted proof producer.
A separate correspondence checker must prove that it matches the checked Kiku
declaration before the inventory can carry authority.

An FPKL result entering a Kiku checked unit must bind and allow reopening of:

- canonical typed-core digest;
- language and semantic-profile versions;
- generated-kernel identity;
- representation-manifest digest;
- complete authenticated-input digest;
- selected package and capability identity;
- producer sessions and completed-unit identities;
- decision and candidate digests;
- single-use commit-token identity;
- exact authority/fact publication digest;
- receipt and verifier identity;
- exact native source, object and archive identities; and
- complete theorem and trust closure.

A Boolean success flag cannot substitute for reopening this closure.

## 27. Relationship to Gnosis

Gnosis should use FPKL for compact authority-bearing decisions while retaining
ordinary orchestration around them.

Initially:

```text
Gnosis C shell
├── opaque package/session handle transport
├── memory and operational controls
├── generated FPKL or separately proved semantic adapters
├── generated FPKL Profile-C transaction
└── confined atomic commit primitive
```

For Profile C, the shell owns no semantic discretion. All authority-bearing
decoding and candidate construction is generated FPKL or a separately proved
minimal adapter. Opaque package/session authentication may remain host-owned
only when the semantic view exposed from the authenticated handle is itself
proof-carrying or covered by that adapter proof.

There is no requirement to rewrite nonsemantic Gnosis infrastructure.

FPKL is a separate project and must not inherit Gnosis authority merely because
Gnosis is its first customer.

## 28. Relationship to Lean

Lean is the initial semantic and proof foundation, not the end-user execution
environment.

The FPKL release must pin:

- exact Lean version;
- imported package identities;
- theorem closure;
- axiom audit;
- generator proof identities; and
- any native Lean compiler/runtime assumptions.

FPKL should minimize reliance on noncomputable definitions and classical
choice in executable paths. Any accepted classical reasoning must be declared
and must not obscure executable witness construction.

## 29. Relationship to C and native code

Generated Clight-compatible C11 is the initial portable deployment format.
Source-level generator refinement is measured against the pinned CompCert
Clight semantics. Native binary correctness is a separate claim.

The initial practical product may place the C compiler and linker in the
trusted computing base while binding the exact compiler, assembler, linker,
flags, target, runtime, headers, ABI, platform, objects, archives and final
binary identities. Its exact claim is:

> Source-level semantics are proved; native behavior is correct relative to
> the declared native-toolchain trusted base.

A later profile may compile through CompCert or use an independently accepted
translation validator to reduce that trust.

No product may describe generated native code as proved merely because the
FPKL source and generated Lean theorem are proved.

## 30. Versioning and compatibility

FPKL versions four independent surfaces:

1. source-language version;
2. typed-core semantic version;
3. backend profile version; and
4. representation/ABI version.

A change to arithmetic, equality, evaluation order, bounds, normalization or
failure precedence is a semantic version change.

A new backend may be added without changing core semantics, but it requires an
independent refinement portfolio.

Generated artifacts must reject unsupported newer semantic or representation
versions rather than attempting best-effort interpretation.

## 31. Required deliverables for an implementation project

The spun-off project must ultimately provide:

- language reference;
- grammar and canonical formatter;
- canonical serialized typed-core schema and verified admission checker;
- reference interpreter;
- Lean evaluator and proofs;
- pinned CompCert/Rocq foundation;
- Clight-compatible restricted C11 AST and proved embedding;
- verified canonical restricted-C printer and parser;
- exact emitted-byte-to-AST proof;
- deterministic C11 generator;
- generator-refinement proof;
- representation-manifest generator;
- formal single-use publication state machine and confinement proofs;
- Profile-C checked adapter framework;
- theorem and trust-report generator;
- command-line compiler;
- C11 and C++17 installed SDK;
- one-command clean-room verifier;
- Arena reference module and customer adapter;
- independent second vertical;
- hostile corpus and fuzz targets;
- deterministic release builder; and
- explicit supported-platform statement.

An illustrative command line is:

```text
fpkl build ArenaProvider.fpkl \
  --emit-c out/c \
  --emit-lean out/lean \
  --emit-manifest out/portfolio \
  --profile c11-bounded-v1

fpkl verify out/portfolio
```

## 32. Kiku v0.1 review resolution

Kiku's first review is incorporated normatively as follows:

1. Generated restricted C satisfies Q3 only when exact emitted bytes are
   proved to correspond to the backend AST and execution is related to the
   selected recognized formal C semantics. Section 17 selects CompCert
   Clight and forbids a standalone C-like evaluator claim.
2. The native compiler, assembler and linker may remain in the initial trusted
   base under the exact source-proved/native-toolchain-trusted claim. Sections
   21, 23 and 29 bind the complete native closure.
3. All eleven Arena authority-bearing semantic mapping groups are inside
   generated FPKL or separately proved adapters in Profile C.
4. Decision, candidate, commit and receipt are retained and now governed by
   the formal confinement protocol in section 20.
5. Record equality is nominal, field-labelled and declaration-order
   independent. Canonical serialization sorts labels and rejects duplicates;
   C layout remains separate.
6. The first kernels retain fixed-width values, bounded collections and no
   general recursion, now with proved space/stack bounds, deterministic error
   precedence and bounded graph traversal as a proved library.
7. `KikuResourceProtocolInventoryV1` is reserved as Kiku's first
   source-to-FPKL correspondence inventory.
8. The complete checked-unit binding inventory requested by Kiku is frozen in
   section 26.
9. Kiku initially consumes FPKL as a proved library language and may later emit
   canonical FPKL typed core only after an independent Kiku-to-FPKL refinement
   theorem.
10. Kiku checked-unit authority-closure verification is reserved as a credible
    third witness. F7 remains independently owned by SIRCC, Tenkan or another
    consumer.

Kiku should now confirm or return a controlled finding against one of these
specific v0.1 paths:

- `section-6/typed-core-authority-root`;
- `section-17/compcert-clight-refinement`;
- `section-19/profile-c-semantic-confinement`;
- `section-20/publication-state-machine`;
- `section-23/qualification-ladder`; or
- `section-26/kiku-integration`.

## 33. Review questions for SIRCC and Tenkan

SIRCC should identify whether its pointer-authority or managed-CFG terminal
decisions fit the pure bounded model, and which graph operations must exist in
the core rather than a domain library.

Tenkan should identify the minimum operations needed for permutation-invariant
source/target correspondence selection while preserving separate frontend and
cross-language authority identities.

Neither project should begin implementation until the core semantics and
generator-refinement claim are frozen.

## 34. Open design decisions

The following remain deliberately unresolved pending review:

- final product and language name;
- concrete surface syntax;
- whether checked allocation into caller-provided arenas belongs in v0;
- whether each Profile C opaque view uses a generated adapter, a proved stable
  wire representation or another separately refined minimal interface;
- the exact Lean/Rocq canonical typed-core bridge construction;
- the pinned CompCert, Rocq and Lean versions for F0;
- whether CompCert compilation is an optional stronger v0 profile or deferred;
- whether a Kiku backend belongs before or after F8; and
- selection of the independent second vertical.

## 35. Freeze rule

This document is a proposal, not an authority grant.

F0 may close only after Kiku and at least one materially different prospective
consumer accept:

- the scope and non-goals;
- the language's pure bounded execution model;
- the source-to-C refinement interpretation;
- the initial compiler/runtime trust ceiling;
- the representation and atomic-publication boundaries; and
- the two-vertical product qualification rule.

Until then, the correct disposition is:

```text
fpkl_v0_1_revision_ready_for_f0_review
```
