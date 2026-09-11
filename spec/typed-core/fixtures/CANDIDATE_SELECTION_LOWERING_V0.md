# Candidate-selection canonical lowering v0

- Status: complete experimental structural lowering and SCB-0 vector
- Source: `../../language/examples/candidate_selection.seki`
- Target: typed-core revision 0.3 and SCB-0 draft

## 1. Canonical module identity

```text
identity: seki::examples::candidate_selection @ 1
semantic_profile: c11_bounded @ 1
imports: []
```

The source's omitted module ceiling expands to the explicit ceiling in
`../../profiles/C11_BOUNDED_V0_DRAFT.md`.

## 2. Canonical declaration indices

```text
domains:
  0 CandidateIdentity

types:
  0 Candidate    = record(enabled: Bool, epoch: Declared[2], id: Declared[1])
  1 CandidateId  = nominal Identity[Domain[0], 16]
  2 Epoch        = nominal U64
  3 Input        = record(candidates: Array[Declared[0], 32],
                          currentEpoch: Declared[2], wanted: Declared[1])
  4 Rejection    = variant(1 Missing, 2 Duplicate, 3 Stale, 4 Disabled)

functions: []
kernels:
  0 select labels [input]
```

Names and fields above are in canonical ASCII order. The canonical constructive
orders are:

```text
type_dependency_order: [1, 2, 0, 3, 4]
function_dependency_order: []
```

After indices 1 and 2 are available, index 0 becomes the least eligible type;
index 3 then becomes eligible before independent index 4. This distinguishes the
canonical order from either table order or an arbitrary valid topological order.

## 3. Kernel signature and references

```text
parameters: [Declared(LocalTypeRef[3])]
result: Decision(Declared(LocalTypeRef[0]), Declared(LocalTypeRef[4]))
rejection_order:
  [VariantRef(LocalTypeRef[4], 1), VariantRef(LocalTypeRef[4], 2),
   VariantRef(LocalTypeRef[4], 3), VariantRef(LocalTypeRef[4], 4)]

declared_ceiling: { steps: 2048, live: 32768, depth: 64, workspace: 4096 }
exact_derived_bounds: { steps: 212, live: 19361, depth: 8, workspace: 201 }
publication_eligible: false
```

The outer `Result` match table is encoded in constructor-tag order `Ok(0),
Error(1)`, even though the explanatory fixture previously displayed the error arm
first. The nested `Option` table is `None(0), Some(1)`.

Canonical field references are:

```text
Candidate.enabled       = FieldRef(RecordType(LocalTypeRef[0]), 0)
Candidate.epoch         = FieldRef(RecordType(LocalTypeRef[0]), 1)
Candidate.id            = FieldRef(RecordType(LocalTypeRef[0]), 2)
Input.candidates        = FieldRef(RecordType(LocalTypeRef[3]), 0)
Input.currentEpoch      = FieldRef(RecordType(LocalTypeRef[3]), 1)
Input.wanted            = FieldRef(RecordType(LocalTypeRef[3]), 2)
```

## 4. De Bruijn environments

```text
kernel entry:                    [input]
after KernelLet:                 [selection, input]
Result::Error arm:               [unit_error, selection, input]
Result::Ok arm:                  [option, selection, input]
Option::Some arm:                [candidate, option, selection, input]
```

Consequently the innermost epoch comparison uses `Local[0]` for `candidate` and
`Local[3]` for `input`. No source display name enters the core.

## 5. Step derivation

The predicate body has five steps:

```text
Equal(Project(Local[0], Candidate.id), Project(Local[1], Input.wanted))
= 1 + (1 + 1) + (1 + 1) = 5
```

At static length 32:

```text
ArrayFindUnique = 1 + 2 + 32 * (1 + 5) = 195
outer KernelMatch = 15
KernelLet = 1 + 195 + 15 = 211
callable root = 1 + 211 = 212
```

## 6. Live-value peak

Relevant semantic widths are:

```text
Candidate = 193
Array[Candidate,32] = 6176
Input = 6368
CandidateId = 128
ArrayFindUnique result = 195
```

The peak occurs in the predicate while its left identity result is retained and
the right projection constructs a fresh identity result from a fresh local read:

```text
enclosing input environment                         6368
retained ArrayFindUnique array                      6176
block parameter Candidate                            193
retained left CandidateId                            128
fresh Local read of Input                           6368
fresh right CandidateId                              128
                                                   -----
                                                   19361 bits
```

This demonstrates why the original `liveBits: 4096` declaration was invalid even
before encoding: the input alone is 6368 bits. The source ceiling is now 32768.

## 7. Other exact conclusions

The deepest path has the callable, `KernelLet`, outer match, inner match, stale
requirement, disabled requirement, accept node, and accepted local expression:

```text
maximum_control_depth = 8
```

`ArrayFindUnique` is the only intrinsic workspace owner:

```text
counter_bits(32) + 2 + value_bits(Candidate) = 6 + 2 + 193 = 201
```

## 8. Experimental vector

Independent C11 and JavaScript fixture emitters agree on the complete module:

```text
envelope bytes: 1021
payload bytes:  1008 (0x000003f0)
module digest:  ebb22139f834cbf94913b9b7df3436340ef91827d26188284568a69f22dd0168
```

Node and OpenSSL independently agree on the domain-separated SHA-256 digest. The
machine vector is `../../encoding/vectors/candidate-selection-v0.json`, and
`make check-encoding-vectors` reproduces it.

The vector remains experimental. The recurrence is specified but not mechanized
or proved, the profile identity is not frozen, and no admission decoder has yet
accepted these bytes.
