# Candidate-selection abstract typed-core fixture

- Status: semantic fixture draft; not canonical bytes
- Purpose: exercise the first fixture-independent kernel

This document uses names in comments for readability. The typed core uses sorted
declaration references and de Bruijn local indices as defined by the model.

## Declarations

```text
domain CandidateIdentity

nominal CandidateId = Identity[CandidateIdentity, 16]
nominal Epoch       = U64

record Candidate {
  enabled : Bool
  epoch   : Epoch
  id      : CandidateId
}

record Input {
  candidates   : Array[Candidate, 32]
  currentEpoch : Epoch
  wanted       : CandidateId
}

variant Rejection {
  Missing   @ 1
  Duplicate @ 2
  Stale     @ 3
  Disabled  @ 4
}
```

Fields above are shown in canonical ASCII-label order, not surface declaration
order.

## Kernel signature

```text
select input: Input
  -> Decision[Candidate, Rejection]

rejection order = [Missing, Duplicate, Stale, Disabled]
arithmetic policy = checked
publication eligible = false
claim ceiling = [semantic_evaluation]
required theorems = [type_well_formed, totality, determinism,
                     resource_bounds, rejection_precedence]
```

## Abstract body

```text
KernelLet(
  value = ArrayFindUnique(
    collection = Project(Local[0 /* input */], Input.candidates),
    predicate = Block(Candidate -> Bool,
      Equal(
        Project(Local[0 /* candidate */], Candidate.id),
        Project(Local[1 /* input */], Input.wanted)
      )
    )
  ),
  body = KernelMatch(Local[0 /* unique result */], [
    Error(Unit) =>
      KernelReject(Rejection.Duplicate, precedence_index = 1),

    Ok(option) =>
      KernelMatch(Local[0 /* option */], [
        None =>
          KernelReject(Rejection.Missing, precedence_index = 0),

        Some(candidate) =>
          KernelRequire(
            precedence_index = 2,
            condition = Equal(
              Project(Local[0 /* candidate */], Candidate.epoch),
              Project(Local[3 /* input */], Input.currentEpoch)
            ),
            rejection = Rejection.Stale,
            continuation = KernelRequire(
              precedence_index = 3,
              condition = Project(Local[0 /* candidate */], Candidate.enabled),
              rejection = Rejection.Disabled,
              continuation = KernelAccept(Local[0 /* candidate */])
            )
          )
      ])
  ])
)
```

`Error`, `Ok`, `None`, and `Some` above abbreviate fully instantiated intrinsic
`ConstructorRef` values. They are not declared `VariantRef` values.

The first two rejection cases arise from mutually exclusive `ArrayFindUnique` result
constructors rather than `KernelRequire` nodes. Every `KernelReject` and every
`KernelRequire` carries the corresponding index in the declared total order.

## Required semantic cases

| Case | Expected decision |
| --- | --- |
| One matching current enabled candidate | `Decision::Accept(candidate)` |
| No matching identity | `Decision::Reject(Missing)` |
| Two or more matching identities | `Decision::Reject(Duplicate)` |
| One matching candidate with wrong epoch | `Decision::Reject(Stale)` |
| One matching current disabled candidate | `Decision::Reject(Disabled)` |
| Byte-equal identity from another nominal domain | admission/type rejection before evaluation |
| Input contains exactly 32 candidate slots | defined decision within derived bounds |
| Input has type `Array[Candidate, 33]` | admission/type rejection before evaluation |

## Binder rule exercised

Each selected match arm introduces at most one payload binding at local index 0.
The nested `Ok(option)` and `Some(candidate)` matches therefore introduce two
distinct lexical levels. At the innermost validation body, the environment is
`candidate`, `option`, `unique result`, `input`, making the input `Local[3]`.
