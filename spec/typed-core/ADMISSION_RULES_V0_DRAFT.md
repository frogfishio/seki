# Seki typed-core admission rules v0 draft

- Status: bootstrap proposal; non-normative
- Companion model: `SEKI_TYPED_CORE_V0_DRAFT.md`

## 1. Admission result

Admission is total over every byte sequence within the selected input-size ceiling:

```text
admit : CandidateBytes -> AdmissionResult

AdmissionResult ::= Admitted(Module)
                  | Rejected(AdmissionReason, DiagnosticPath)
```

Inputs exceeding the byte ceiling are rejected before allocation or structural
decoding. No rejected input yields an executable semantic module.

## 2. Layered checks

Checks run in this fixed precedence. A layer completes before the next begins.
Within a layer, the first error is the least canonical structural path after
table entries have been canonically ordered.

| Order | Layer | Representative rejection |
| --- | --- | --- |
| 0 | Envelope | oversized, truncated, malformed encoding |
| 1 | Canonical form | noncanonical integer/length, duplicate key, wrong key order |
| 2 | Identity | wrong schema, language, module, or semantic profile |
| 3 | Shape | unknown/missing field, wrong value kind, profile count exceeded |
| 4 | Imports | bad digest, duplicate identity, unavailable exact import, cycle |
| 5 | Declarations | invalid/duplicate name, table disorder, invalid stable tag, bad export |
| 6 | Type formation | invalid bound, recursive type, unsupported type |
| 7 | References | out-of-range or wrong-kind declaration/local reference |
| 8 | Static typing | operand, argument, field, branch, match, or result mismatch |
| 9 | Totality | recursion, escaping block, unsupported call/intrinsic |
| 10 | Module/kernel rules | invalid theorem/claim ceiling, decision type, rejection order, require index, publication declaration |
| 11 | Bounds | overflow, incorrect derivation, profile ceiling exceeded |
| 12 | Backend/profile | construct unavailable in selected qualified projection |
| 13 | Witness closure | missing, mismatched, or incomplete derivation witness |

The concrete stable `AdmissionReason` tags will be assigned with the encoding
schema. Implementations may collect additional diagnostics, but the authoritative
primary rejection is determined only by this table and canonical path order.

## 3. Structural paths

A diagnostic path addresses canonical structure, not source text:

```text
module/types/3/record/fields/1/type
module/kernels/0/body/kernelRequire/continuation
```

Source locations are recovered only through a digest-bound diagnostic sidecar.
Absence or compromise of that sidecar cannot change the rejection.

## 4. Required hostile classes

Each layer requires at least one positive boundary vector and negative vectors for:

- empty, one-byte, truncated, and trailing-byte inputs;
- maximum and maximum-plus-one lengths/counts/nesting;
- duplicate, missing, unknown, reordered, and wrong-kind fields;
- invalid UTF-8 wherever text is admitted;
- noncanonical integer, length, tag, and identifier encodings;
- substituted module, import, domain, type, function, field, and variant references;
- alias cycles, recursive records/variants, and call cycles;
- local references at every binder-depth boundary;
- nominally distinct but representation-equal values;
- incomplete records and non-exhaustive or duplicate match arms;
- mixed-width arithmetic, unsigned negation, non-`U32` shift counts, invalid
  intrinsic constructor references, and incorrect operation/policy result types;
- every integer-width boundary for overflow, conversion, zero division,
  `min / -1`, `min % -1`, and shift counts `N-1`/`N`;
- invalid collection capacities and block signatures;
- rejection-order omissions, duplicate constructors, bad site indices, and
  reason/index mismatches;
- kernel-control nodes smuggled into pure value positions;
- non-increasing rejection indices through lets, conditionals, matches, and
  requirements along one continuation path;
- wrong binder arity for nullary and payload-bearing match constructors;
- mismatched exact steps, live-value bits, control depth, or maximum workspace
  bits, including imported-call and nested-intrinsic costs;
- arithmetic overflow in bound calculation; and
- valid core constructs unavailable in the selected backend profile.

## 5. Checker independence

The checker does not trust:

- parser or elaborator success;
- ordering performed by the producer;
- claimed expression types or bounds;
- imported names without exact digest reopening;
- a Boolean acceptance from another checker;
- source locations or human diagnostics; or
- successful execution of generated or handwritten C.

An admitted result binds the exact canonical module digest and checker/profile
identity needed by later stages.
