# F0 candidate: Grit Stage 1 handoff publication

- Status: candidate selected; field validation deferred until release candidate
- Consumer: Grit 3 Stage 1
- Reviewer role: Grit Stage 1 authority-chain maintainer
- Seki work package: future A0-08/F0 field validation; current material is a draft
- Date observed: 2026-09-19

## 1. Consequential decision

The proposed kernel decides whether one already-formed Grit Stage 1 semantic
handoff may cross its sole publication boundary.

```text
PublicationCandidate
  -> Accept(PublicationPermit)
   | Reject(PublicationRejection)
```

Acceptance means that the caller may publish exactly the identified canonical
semantic graph under exactly the identified CertifiedPack and semantic
vocabulary. Rejection means zero publication. The kernel does not parse Grit,
construct a graph, authenticate evidence, write files, or certify the compiler.
It coordinates already-authenticated bounded facts into one deterministic
publication decision.

This is grounded in Grit's existing rule that `grit3_publish_stage1_handoff` is
the sole public Stage 1 publication operation and that any failure leaves the
whole output byte-zero. It also reflects G3-PACK-008: admission produces exactly
one certified pack or diagnostics with no partial publication.

## 2. Why this consumer is materially different

The founding Kiku/Arena case selects or rejects a bounded domain candidate under
causal-provider rules. This case controls publication of a compiler-generated
semantic artifact under identity closure and independently authenticated
evidence.

It introduces different pressure:

- several nominally distinct evidence receipts must not be substitutable;
- multiple 256-bit artifact identities must agree exactly;
- rejection precedence reports which publication premise failed;
- acceptance produces a permit bound to exact identities, not a selected
  business object; and
- failure must publish nothing even though all input data is otherwise present.

No Grit constructor, grammar rule, source spelling, Lean declaration, or graph
node becomes a Seki core primitive.

## 3. Immutable input and result

The proposed input is a fixed record. `Digest256` is a fixed array of 32 bytes,
not a string. Every receipt type below is nominally distinct even if its fields
have the same representation.

```text
PublicationCandidate := {
  frameTag: U8,
  encodingRevision: U32,

  artifactIdentity: Digest256,
  recomputedArtifactIdentity: Digest256,
  certifiedPackIdentity: Digest256,
  boundPackIdentity: Digest256,
  semanticVocabularyIdentity: Digest256,
  boundVocabularyIdentity: Digest256,

  graphClosure: GraphClosureReceipt,
  ownership: OwnershipReceipt,
  references: ReferenceClosureReceipt,
  claimAuthority: ClaimAuthorityReceipt,
  hintSchemas: HintSchemaReceipt,
  provenance: ProvenanceReceipt,
  canonicalRebase: CanonicalRebaseReceipt,
  canonicalBytes: CanonicalBytesReceipt
}

Each Receipt := {
  subject: Digest256,
  disposition: EvidenceDisposition
}

EvidenceDisposition := Accepted | Rejected

PublicationPermit := {
  artifactIdentity: Digest256,
  certifiedPackIdentity: Digest256,
  semanticVocabularyIdentity: Digest256
}
```

The host boundary must authenticate each receipt and construct the correct
nominal type. The Seki kernel checks that every receipt is accepted and bound to
the candidate artifact. It does not turn a host-supplied Boolean into evidence.

## 4. Rejection inventory and precedence

The proposed first-failure order is:

1. `UnsupportedFrame`
2. `UnsupportedEncodingRevision`
3. `ArtifactIdentityMismatch`
4. `CertifiedPackIdentityMismatch`
5. `SemanticVocabularyIdentityMismatch`
6. `GraphNotClosed`
7. `OwnershipInvalid`
8. `ReferenceClosureInvalid`
9. `ClaimAuthorityInvalid`
10. `HintSchemaInvalid`
11. `ProvenanceInvalid`
12. `CanonicalRebaseInvalid`
13. `CanonicalBytesInvalid`

For each receipt failure, a rejected disposition and a subject other than the
candidate artifact both reject. Missing, duplicate, malformed, stale, unknown,
or cryptographically unauthenticated receipts do not cross the typed host
boundary; the adapter rejects them before invoking the kernel. The distinction
must remain explicit because Seki proves the bounded decision only for admitted
inputs, not the correctness of the adapter's authentication.

The Grit field validator must confirm the order during real use. Seki must not
infer it from source order, diagnostic order, or an implementation's current
`if` statements.

## 5. Proposed bounds

These are deliberately conservative candidate ceilings for charter review, not
derived frozen costs:

| Dimension | Candidate maximum |
| --- | ---: |
| Digest length | exactly 32 bytes |
| Evidence receipts | exactly 8 nominal fields |
| Variable-length collections | none |
| Collection traversal | none; fixed-value equality only |
| Semantic steps | 512 |
| Live semantic bits | 8,192 |
| Control depth | 32 |
| Semantic workspace bits | 0 |
| Recursion/call depth | 0 internal calls |
| Generated-kernel frames | one, subject to later ABI mapping |

F0-03 remains incomplete until Grit field validation confirms the input inventory
and the Seki cost algebra derives exact rather than ceiling values. Physical C
stack bytes are target/ABI facts and cannot be manufactured from semantic control
depth.

## 6. Required operations

The case needs only candidate v0 core operations:

- nominal record and variant construction;
- fixed `Array[U8,32]` values;
- exact equality over well-formed fixed values;
- fixed-width integer equality;
- Boolean conjunction or tail-formed conditional checks;
- deterministic rejection precedence; and
- `Decision[PublicationPermit, PublicationRejection]`.

It needs no generics, allocation, recursion, filesystem access, cryptography,
callbacks, dynamic dispatch, variable-length vector, map, registry, or ambient
module lookup. SHA-256 computation and receipt authentication remain host or
library responsibilities outside this kernel.

## 7. Core-independence check

The decision can be expressed without Kiku, Arena, GCIR, Grit, grammar, or Gnosis
primitives in the Seki core. The source module may use customer-owned nominal
names such as `CertifiedPackIdentity`, just as any customer module may define
domain types. Those names do not change the language's typing or evaluation
rules.

The case exercises only general concepts: fixed identities, nominal receipts,
accepted/rejected evidence, deterministic precedence, and an identity-bound
permit. That is the desired F0 pressure.

## 8. Prospective F7 vertical

If Grit accepts the charter, it could eventually supply a materially different
F7 vertical around this publication coordinator:

1. exact authenticated Stage 1 receipts and identities enter through a bounded
   Profile-C adapter;
2. a Seki kernel returns a publication permit or one rejection;
3. Lean states the atomic-publication policy over the exact invocation;
4. generated C is linked at the sole Stage 1 handoff boundary; and
5. hostile substituted, stale, rejected, or cross-subject receipts produce no
   permit and no publication.

That vertical would not claim that Seki proved graph closure or Grit's compiler.
It would prove only the coordinator's policy given authenticated input premises.

## 9. Evidence provenance

This candidate was prepared from the Grit checkout observed at Git HEAD
`d76f294f123f682d6f6d2b5e886b9a15e8d0064e`. The machine-readable candidate
record binds the exact observed file digests. The Grit worktree had unrelated
uncommitted changes; none of the source documents cited by this packet appeared
in the observed modified-file list. This is proposal provenance, not consumer
acceptance.

## 10. Future field-validation action

After Seki internally certifies a release candidate, an identified Grit Stage 1
authority-chain maintainer will exercise the exact candidate on this prospective
integration boundary. The field-validation record must:

1. confirm or correct the decision, fields, nominal distinctions, rejection
   order, and candidate bounds;
2. record the exact Seki compiler and generated-artifact bytes actually used;
3. confirm that this use needs no customer-specific Seki core primitive; and
4. return the exact acceptance token or a controlled finding.

No acceptance is recorded yet. This is expected during autonomous development:
a role is not a reviewer identity, silence is not acceptance, and no review is
requested until a release candidate exists.
