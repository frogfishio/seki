# Seki canonical typed core v0 draft

- Status: bootstrap semantic model; non-normative; encoding not selected
- Draft revision: 0.2
- Language identity: `io.frogfish.seki/language@0`
- Target work package: F1-A01/F1-A02 draft

## 1. Role

The canonical serialized typed-core module is Seki's future semantic authority
root. This document defines its abstract value model before choosing serialized
bytes. Surface source, parser ASTs, source locations, comments, formatting, and
diagnostic names are not part of this model unless explicitly retained below.

A surface parser and elaborator propose a typed-core module plus witnesses. The
admission checker independently reopens the proposal. A claimed type, reference,
bound, or witness is evidence to check, never a trusted fact.

This draft carries no F1 implementation or proof authority while global F0 is
open.

## 2. Model notation

The definitions use this specification notation:

```text
Name ::= ASCII identifier bytes
Nat  ::= mathematical natural number bounded by the selected profile
Bool ::= false | true
Bytes ::= finite sequence of octets
MathematicalInteger ::= an integer value, independent of machine encoding
IntegerType ::= U8 | U16 | U32 | U64 | I8 | I16 | I32 | I64
Vec[T] ::= finite ordered sequence of T
Table[K, V] ::= finite ordered (key, value) entries with unique keys in
                canonical key order
Option[T] ::= none | some(T)
```

This notation is not Seki surface syntax and does not select JSON, CBOR, or any
binary encoding.

## 3. Identity and versioning

```text
LanguageId ::= "io.frogfish.seki/language@0"

ModuleId ::= {
  path: Vec[Name],       ;; nonempty lowercase components
  version: Nat
}

ProfileId ::= {
  name: Name,
  version: Nat
}

DigestId ::= {
  algorithm: DigestAlgorithm,
  bytes: Bytes
}

DigestAlgorithm ::= sha256
```

V0 admits SHA-256 as the seed digest algorithm. Adding an algorithm requires a
profile/version decision. Path spelling is case-sensitive ASCII. Empty components,
`.`/`..`, alternate separators, Unicode normalization, and version ranges do not
exist in typed core.

Every reference crossing a module boundary includes the exact `ModuleId` and
module digest. Ambient resolution is impossible.

## 4. Module

```text
Module ::= {
  schema_version: Nat,
  language: LanguageId,
  identity: ModuleId,
  semantic_profile: ProfileId,
  imports: Table[ModuleId, ImportBody],
  domains: Table[Name, DomainBody],
  types: Table[Name, TypeDeclBody],
  functions: Table[FunctionKey, FunctionBody],
  kernels: Table[FunctionKey, KernelBody],
  exports: ExportSet,
  required_theorems: Vec[TheoremRequirement],
  claim_ceiling: Vec[ClaimKind],
  declared_module_ceiling: ModuleBounds,
  derivations: DerivationBundle
}

ImportBody ::= {
  digest: DigestId,
  expected_profile: ProfileId
}

ExportSet ::= {
  domains: Vec[LocalDomainRef],
  types: Vec[LocalTypeRef],
  functions: Vec[LocalFunctionRef],
  kernels: Vec[LocalKernelRef]
}

TheoremRequirement ::= type_well_formed
                     | totality
                     | determinism
                     | resource_bounds
                     | rejection_precedence
                     | representation
                     | publication_equivalence

ClaimKind ::= semantic_evaluation
            | lean_projection
            | representation_correspondence
            | restricted_c_source
            | clight_refinement
            | certified_lean_equivalence
            | installed_binary
            | publication
```

Tables impose unique keys and canonical key order. Declaration bodies do not
repeat the surrounding table key. Surface declaration order does not enter
semantic identity. Imports form a finite acyclic digest-bound graph.

Export vectors contain unique local references in canonical index order. Theorem
requirements and claims are closed, unique, canonically ordered sets. A claim not
listed in `claim_ceiling` is withheld. Listing a claim requests or permits that
kind of evidence; it does not establish the claim.

`DerivationBundle` carries proposed type, totality, import, and bound witnesses.
It participates in the canonical module digest as required by the governing
seed. Its proof-object shape must therefore have one canonical normal form; that
shape remains open. Every witness is reopened by the admission checker.

## 5. Names and references

Public declarations retain names because names participate in module APIs,
imports, manifests, and generated symbols. Local display names do not participate
in semantic identity.

```text
TypeRef ::= LocalTypeRef(type_index)
          | ImportedTypeRef(module, digest, type_index)

FunctionRef ::= LocalFunctionRef(function_index)
              | ImportedFunctionRef(module, digest, function_index)

KernelRef ::= LocalKernelRef(kernel_index)
            | ImportedKernelRef(module, digest, kernel_index)

DomainRef ::= LocalDomainRef(domain_index)
            | ImportedDomainRef(module, digest, domain_index)

FieldOwnerRef ::= RecordType(type: TypeRef)
                | VariantPayloadOwner(case: VariantRef)

FieldRef ::= {
  owner: FieldOwnerRef,
  field_index: Nat
}

VariantRef ::= {
  owner: TypeRef,
  stable_tag: Nat
}

SumTypeRef ::= DeclaredVariant(type: TypeRef)
             | IntrinsicOption(item: Type)
             | IntrinsicResult(ok: Type, error: Type)
             | IntrinsicDecision(accepted: Type, rejection: Type)
             | IntrinsicArithmeticError

ConstructorRef ::= {
  owner: SumTypeRef,
  stable_tag: Nat
}
```

Indices address the canonically sorted declaration tables, never surface order.
Admission verifies that each index is in range and that the indexed declaration
has the expected kind.

Declared constructor tags come from the referenced variant declaration. Intrinsic
sum tags are frozen as:

```text
Option:   None = 0, Some = 1
Result:   Ok = 0, Error = 1
Decision: Accept = 0, Reject = 1
ArithmeticError: Overflow = 0, DivideByZero = 1,
                 InvalidShift = 2, OutOfRange = 3
```

An intrinsic constructor reference includes its fully instantiated owner type;
`Some` without the corresponding `Option[T]` is not a typed-core reference.

Local values use zero-based de Bruijn indices:

```text
LocalRef ::= Nat       ;; 0 is the nearest enclosing binder
```

Surface elaboration resolves names to indices. Renaming a local cannot change the
typed-core module or digest. Surface Seki prohibits shadowing to keep diagnostics
simple even though de Bruijn representation is unambiguous.

## 6. Domains and types

```text
DomainBody ::= unit

Type ::= Unit
       | Bool
       | U8 | U16 | U32 | U64
       | I8 | I16 | I32 | I64
       | ArithmeticError
       | Bytes(length: Nat)
       | Identity(domain: DomainRef, length: Nat)
       | Digest(algorithm: DigestAlgorithm, length: Nat)
       | Index(bound: Nat)
       | Option(item: Type)
       | Result(ok: Type, error: Type)
       | Tuple(items: Vec[Type])
       | Array(item: Type, length: Nat)
       | BoundedVec(item: Type, capacity: Nat)
       | Decision(accepted: Type, rejection: Type)
       | VariantPayload(case: VariantRef)
       | Declared(reference: TypeRef)
```

All natural parameters must fit the selected profile and participate in type
identity. `Index[0]` is invalid. Empty byte strings, arrays, tuples, and bounded
vectors remain profile decisions; they are not inferred from host behavior.
`VariantPayload` is an internal type for the canonical field record carried by
one declared variant case; it cannot be named in surface signatures. A case with
no payload has no `VariantPayload` value. `Declared` cannot reference an alias;
aliases are expanded during elaboration and admission rechecks that normalization.
Admission permits `VariantPayload` only where it is synthesized for a matching
arm and its local projections; it cannot appear in declarations or public APIs.

```text
TypeDeclBody ::= AliasBody | NominalBody | RecordBody | VariantBody

AliasBody ::= {
  target: Type
}

NominalBody ::= {
  representation: Type
}

RecordBody ::= {
  fields: Table[Name, FieldBody]
}

FieldBody ::= {
  type: Type
}

VariantBody ::= {
  cases: Table[Nat, VariantCaseBody]
}

VariantCaseBody ::= {
  name: Name,
  payload: Option[PayloadBody]
}

PayloadBody ::= {
  fields: Table[Name, FieldBody]
}
```

Aliases are transparent and create no identity. Nominals, records, and variants
are distinct by declaration reference. Nominal construction/destruction is only
available through admitted constructors or representation adapters; equal physical
bytes do not cross nominal declarations or identity domains.

Records use canonical field-label order. A surface record literal may write fields
in any order, but elaboration produces the canonical table and typed-core evaluation
uses canonical field order. This prevents source field order from changing a
module's digest or failure selection.

Variants require unique stable tags within their declaration and unique case
names. Zero is a valid tag unless a representation profile explicitly reserves it.
Source position is irrelevant. Unknown tags never construct a value.

Recursive and mutually recursive types are excluded from v0.

## 7. Functions and kernels

```text
FunctionKey ::= {
  base: Name,
  labels: Vec[Name]
}

FunctionBody ::= {
  parameter_types: Vec[Type],
  result: Type,
  body: Expr,
  declared_ceiling: ResourceBounds,
  exact_derived_bounds: ResourceBounds
}

KernelBody ::= {
  parameter_types: Vec[Type],
  result: Decision(accepted: Type, rejection: Type),
  rejection_order: Vec[VariantRef],
  body: KernelExpr,
  declared_ceiling: ResourceBounds,
  exact_derived_bounds: ResourceBounds,
  publication_eligible: Bool
}

ArithmeticPolicy ::= checked | wrapping | saturating
```

Arithmetic defaults are surface elaboration only. Every arithmetic typed-core
node carries its effective policy, so inheritance cannot affect evaluation after
elaboration.

Function keys are unique across functions and kernels in one module. Overloading
by parameter or result type is excluded. The key's label count equals the body
parameter-type count. Both sequences use source pattern order, which is semantic
call/evaluation order; labels are not repeated inside the body.

Parameter values are pushed into the local environment from left to right. The
last declared parameter is therefore local index 0, and the first parameter of an
N-parameter function is local index N-1. Block parameters use the same convention.
Zero-parameter bodies inherit the surrounding environment unchanged.

The call graph must be acyclic. User recursion, mutual recursion, and indirect
calls do not exist. Functions and blocks are not runtime values.

Each kernel freezes a complete rejection-constructor order. Every constructor of
the kernel's rejection variant must appear exactly once. A v0 kernel rejection
type must resolve to one declared `VariantBody`; intrinsic and structurally
composed rejection types are not admitted. Imported variants remain exact
digest-bound declarations.

`publication_eligible` is a declaration of intended use, not permission to
publish. It is valid only when `publication` is in the module claim ceiling and
`publication_equivalence` is required. Publication still requires the later
certificate and host protocol.

Every function and kernel carries an explicit effective resource ceiling in
typed core. A surface declaration that omits `bounded` inherits the selected
profile's per-function ceiling during elaboration; no implicit inheritance
remains after elaboration.

## 8. Typed expressions

```text
Expr ::= {
  claimed_type: Type,
  term: Term
}
```

Admission recomputes the type of every expression and the exact bounds of each
function/kernel body. Per-expression bound claims are omitted so an elaborator
cannot create distinct authority roots by choosing arbitrary conservative claims.
Each child sequence below is evaluated from left to right unless a node gives a
more specific rule.

`Expr` is pure value-producing syntax. Kernel acceptance, rejection, and ordered
requirements are deliberately absent from `Term`; they inhabit the tail-formed
`KernelExpr` grammar in section 8.7.

### 8.1 Values and bindings

```text
Term ::= UnitLit
       | BoolLit(value: Bool)
       | IntLit(type: IntegerType, value: MathematicalInteger)
       | BytesLit(length: Nat, bytes: Bytes)
       | Local(reference: LocalRef)
       | Let(value: Expr, body: Expr)
```

`Let` evaluates `value`, then evaluates `body` with that immutable result at local
index 0. Existing locals shift outward by one. There is no assignment node.

Integer literals carry an exact integer type and mathematical value. Surface
literal elaboration must reject out-of-range values; admission rechecks. Bit and
byte representation belong to the later canonical-encoding and representation
profiles, not this abstract model.

### 8.2 Construction and elimination

```text
Term ::= Record(type: TypeRef, fields: Table[FieldRef, Expr])
       | Project(record: Expr, field: FieldRef)
       | Variant(case: VariantRef, fields: Table[Name, Expr])
       | Tuple(items: Vec[Expr])
       | OptionNone(item_type: Type)
       | OptionSome(value: Expr)
       | ResultOk(error_type: Type, value: Expr)
       | ResultError(ok_type: Type, error: Expr)
```

Construction requires every field exactly once and no unknown field. Record and
payload fields evaluate in canonical field-label order. Tuple items evaluate in
index order.

### 8.3 Equality, Boolean logic, and comparison

```text
Term ::= Equal(left: Expr, right: Expr)
       | NotEqual(left: Expr, right: Expr)
       | Not(value: Expr)
       | AndThen(left: Expr, right: Expr)
       | OrElse(left: Expr, right: Expr)
       | Compare(op: CompareOp, left: Expr, right: Expr)

CompareOp ::= less | less_equal | greater | greater_equal
```

Equality operands must have the same equality-admitting type. Nominal declarations
and identity domains must match exactly. Functions, blocks, derivations, and
opaque host values are not comparable.

`AndThen` evaluates its right child only when the left child is true. `OrElse`
evaluates its right child only when the left child is false. Conditions are exactly
`Bool`.

### 8.4 Arithmetic and conversion

```text
Term ::= IntBinary(policy, op, left, right)
       | IntUnary(policy, op, value)
       | IntConvert(policy, target, value)

IntBinaryOp ::= add | subtract | multiply | divide | remainder
              | shift_left | shift_right
IntUnaryOp  ::= negate

ArithmeticError ::= Overflow @ 0
                  | DivideByZero @ 1
                  | InvalidShift @ 2
                  | OutOfRange @ 3
```

Operands have one explicit integer type; there are no promotions. The stable
intrinsic `ArithmeticError` tags above are part of language v0.

Result types are exact:

| Operation | checked | wrapping | saturating |
| --- | --- | --- | --- |
| add, subtract, multiply | `Result[T, ArithmeticError]` | `T` modulo 2^N | `T` clamped to its bound |
| signed negate | `Result[T, ArithmeticError]` | `T` modulo 2^N | `T` clamped to its bound |
| conversion | `Result[T, ArithmeticError]` | `T` modulo 2^N | `T` clamped to its bound |
| divide, remainder | `Result[T, ArithmeticError]` | `Result[T, ArithmeticError]` | `Result[T, ArithmeticError]` |
| shift left/right | `Result[T, ArithmeticError]` | `Result[T, ArithmeticError]` | `Result[T, ArithmeticError]` |

Division or remainder by zero produces `DivideByZero` under every policy. Signed
minimum divided by -1 produces `Overflow` when checked, the signed minimum when
wrapping, and the signed maximum when saturating. A shift count outside
`0 <= count < N` produces `InvalidShift` under every policy. For a valid count,
left-shift overflow follows the selected policy; right shift is logical for
unsigned values and sign-extending for signed values. Failed checked conversion
produces `OutOfRange`.

Surface propagation syntax remains to be frozen. Admission rejects any claimed
result inconsistent with the effective node policy and operation.

### 8.5 Static control

```text
Term ::= If(condition: Expr, when_true: Expr, when_false: Expr)
       | Match(scrutinee: Expr, arms: Table[ConstructorRef, MatchArm])

MatchArm ::= {
  body: Expr
}
```

`If` evaluates one branch only. Both branches have the same type. `Match` evaluates
the scrutinee and exactly one arm. Arms cover every possible constructor exactly
once and use stable-tag canonical order in the typed core. Constructor shape,
not a producer-supplied flag, determines whether an arm receives a payload.

Options, results, and decisions use equivalent intrinsic constructor identities
for exhaustiveness even when their surface sugar differs.

Payload binding is fixed by constructor kind:

| Constructor | Arm binding |
| --- | --- |
| declared nullary case | none |
| declared payload case | one `VariantPayload(case)` value |
| `Option::None` | none |
| `Option::Some` | one item value |
| `Result::Ok` | one success value |
| `Result::Error` | one error value |
| `Decision::Accept` | one accepted value |
| `Decision::Reject` | one rejection value |
| any `ArithmeticError` case | none |

Each match arm binds at most one value: the complete payload of the selected
constructor. For a record-payload variant, that binding is the payload record and
has type `VariantPayload(case)`; fields are projected through payload-owned
`FieldRef` values. Constructors nested inside a payload require a nested `Match`;
one surface pattern cannot introduce an implicit stack of binders. When present,
the payload binding is local index 0 in the arm body.

### 8.6 Static calls

```text
Term ::= Call(function: FunctionRef, arguments: Vec[Expr])
```

Calls resolve to one exact local or digest-bound imported function. Arguments
match labels and types exactly and evaluate in declared order. Kernels cannot be
called as functions in v0.

### 8.7 Tail-formed kernel control and rejection sequence

```text
KernelExpr ::= KernelAccept(value: Expr)
             | KernelReject(reason: Expr, precedence_index: Nat)
             | KernelRequire(
  condition: Expr,
  rejection: Expr,
  precedence_index: Nat,
  continuation: KernelExpr
)
             | KernelLet(value: Expr, body: KernelExpr)
             | KernelIf(
                 condition: Expr,
                 when_true: KernelExpr,
                 when_false: KernelExpr
               )
             | KernelMatch(
                 scrutinee: Expr,
                 arms: Table[ConstructorRef, KernelMatchArm]
               )

KernelMatchArm ::= {
  body: KernelExpr
}
```

Every `KernelExpr` is checked in the enclosing kernel's `Decision[A, R]` context.
`KernelAccept` evaluates an `A`; `KernelReject` evaluates an `R`.
`KernelRequire` evaluates its Boolean condition. False evaluates its rejection
expression and returns `Decision::Reject`; true evaluates its continuation.

`KernelLet` evaluates a pure value and binds it at local index 0 for its body.
`KernelIf` and `KernelMatch` evaluate exactly one tail branch. `KernelMatch` uses
the same exhaustiveness, canonical arm ordering, and constructor-determined
single-payload binder rule as pure `Match`.

Kernel control is tail-formed by construction. A pure expression cannot hide a
rejection inside an arithmetic operand, record field, call argument, collection
block, or other value-producing position. Every kernel execution reaches exactly
one terminal `KernelAccept` or `KernelReject`.

Every rejection site carries the zero-based index of its reason constructor in
the kernel's declared rejection order. Multiple sites may use the same index.
Admission verifies the reason type, constructor, and index correspondence. The
order vector itself contains every rejection constructor exactly once without
gaps or duplicates.

The reason expression at a rejection site has one statically known outer
constructor; its payload may be computed. Precedence is checked by
`check_order(kernel_expr, floor)`, initially with `floor = 0`:

```text
KernelAccept                 succeeds
KernelReject(_, i)           requires i >= floor
KernelRequire(_, _, i, k)    requires i >= floor;
                              checks k with floor = i + 1
KernelLet(_, k)              checks k with the same floor
KernelIf(_, yes, no)         checks both branches with the same floor
KernelMatch(_, arms)         checks every arm with the same floor
```

The `i + 1` calculation is checked and cannot overflow the selected profile.
Thus rejection indices strictly increase along every sequentially reachable
continuation, including through intervening lets, conditionals, and matches.
Mutually exclusive branches may begin at unrelated indices because only one
executes. More permissive semantic analysis is not part of v0 admission.

This node makes rejection precedence structural rather than an incidental property
of generated control flow.

### 8.8 Bounded collection operations

```text
Term ::= ArrayGet(collection, index)
       | VecLength(collection)
       | VecGet(collection, index)
       | Fold(collection, initial, step_block)
       | FindUnique(collection, predicate_block)
       | All(collection, predicate_block)
       | Any(collection, predicate_block)
       | MapBounded(collection, map_block)
       | FilterBounded(collection, predicate_block)

Block ::= {
  parameters: Vec[Type],
  result: Type,
  body: Expr
}
```

Blocks are embedded syntax, not values. Captures are de Bruijn references to
immutable enclosing locals. A block cannot escape, be stored, compared, exported,
or called except by its owning intrinsic.

Traversal count derives from the static array length or bounded-vector capacity.
There is no early exit unless the intrinsic semantics explicitly define it and
the bound derivation still accounts for the worst case.

`FindUnique[T]` scans the complete logical collection and returns:

```text
Result[Option[T], Unit]
```

- `Ok(None)` means no matching element;
- `Ok(Some(value))` means exactly one matching element; and
- `Error(Unit)` means at least two matching elements.

Scanning the full collection prevents discovery order from incorrectly reporting
one match before a later duplicate.

`ArrayGet` and `VecGet` return `Option[T]`; unchecked indexing does not exist.

## 9. Bounds

```text
ResourceBounds ::= {
  logical_steps: Nat,
  maximum_live_value_bits: Nat,
  maximum_control_depth: Nat,
  workspace_bits: Nat
}

ModuleBounds ::= {
  maximum_input_bytes: Nat,
  maximum_typed_core_bytes: Nat,
  maximum_imports: Nat,
  maximum_declarations: Nat,
  maximum_expression_nodes: Nat,
  maximum_nesting: Nat,
  maximum_call_depth: Nat,
  maximum_resource_bounds: ResourceBounds
}
```

The selected profile and module supply hard ceilings. Admission derives the exact
`ResourceBounds` of each function and kernel compositionally, checks the stored
exact result and derivation, and then checks it against the declared ceiling.
Integer overflow while calculating a bound rejects admission.

F1 measurements are semantic and representation-independent: logical steps,
maximum simultaneously live value bits, maximum evaluator-control depth, and
abstract workspace bits. Control depth includes expression, block, intrinsic,
and function-call frames; it is not a claim about native stack layout. F2/F3 must
prove how those values map to concrete C objects, alignment, stack bytes, and
caller-owned workspace bytes. A backend may consume more physical bytes than the
packed semantic bit count, but never more than its separately proved generated
bound.

The function-call contribution to control depth derives from the acyclic call
graph; expression nesting and intrinsic/block frames contribute as well.
Traversal costs use static capacities, not runtime lengths. Hidden heap,
recursive call stacks, or host callbacks are impossible in admitted expressions.

## 10. Evaluation result

For an admitted function or kernel and well-typed argument values, evaluation is
total:

```text
evaluate : AdmittedCallable × Values -> Value
```

Semantic rejection is a `Decision::Reject` result. Checked arithmetic failures are
ordinary `ResultError` values that the program must handle. Malformed input,
authentication failure, cancellation, host failure, and allocation failure occur
outside pure typed-core evaluation and cannot be disguised as semantic acceptance.

Admitted evaluation cannot exceed its proved resource bounds. Exhaustion by a
conforming evaluator is therefore an implementation/profile failure and publishes
nothing, not an alternate semantic result.

## 11. Canonical-model invariants

An admitted module satisfies at least:

1. exact language, schema, module, profile, and import identity;
2. unique canonically ordered table keys;
3. valid in-range canonical references;
4. acyclic imports, types, and calls where required;
5. exact nominal-domain separation;
6. complete construction and exhaustive elimination;
7. one recomputed type for every expression;
8. deterministic evaluation and rejection precedence;
9. only closed, versioned bounded intrinsics;
10. proved finite resource ceilings within the profile;
11. no unsupported backend or proof-profile construct; and
12. no source metadata in semantic identity.

## 12. Diagnostic sidecar

The untrusted frontend may emit a non-authoritative sidecar:

```text
DiagnosticSidecar ::= {
  typed_core_digest: DigestId,
  source_digest: DigestId,
  local_display_names: Table[NodePath, Name],
  source_ranges: Table[NodePath, SourceRange],
  comments: Option[diagnostic-only data]
}
```

The sidecar must bind the exact typed-core digest. It may improve errors but cannot
change admission, evaluation, generated code, proofs, or publication.

## 13. Encoding questions deliberately deferred

The abstract model does not decide:

- binary, canonical JSON, or canonical CBOR representation;
- integer and length prefix encodings;
- whether canonical tables serialize as sorted pairs or schema-positioned arrays;
- exact derivation witness representation;
- schema evolution fields and extension rejection; or
- diagnostic-sidecar wire format.

The encoding decision must preserve every invariant above and minimize the size
of the verified decoder.
