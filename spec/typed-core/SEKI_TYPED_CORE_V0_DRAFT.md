# Seki canonical typed core v0 draft

- Status: bootstrap semantic model; non-normative; encoding not selected
- Draft revision: 0.1
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
Vec[T] ::= finite ordered sequence of T
Map[K, V] ::= finite map with unique keys and canonical key order
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
  imports: Map[ModuleId, Import],
  domains: Map[Name, DomainDecl],
  types: Map[Name, TypeDecl],
  functions: Map[FunctionKey, FunctionDecl],
  kernels: Map[FunctionKey, KernelDecl],
  claimed_module_bounds: ModuleBounds,
  derivations: DerivationBundle
}

Import ::= {
  module: ModuleId,
  digest: DigestId,
  expected_profile: ProfileId
}
```

Maps impose unique keys and canonical key order. Surface declaration order does
not enter semantic identity. Imports form a finite acyclic digest-bound graph.

`DerivationBundle` carries proposed type, totality, import, and bound witnesses.
Its exact proof-object shape remains open, but every witness must be reopened by
the admission checker.

## 5. Names and references

Public declarations retain names because names participate in module APIs,
imports, manifests, and generated symbols. Local display names do not participate
in semantic identity.

```text
TypeRef ::= LocalTypeRef(type_index)
          | ImportedTypeRef(module, digest, type_index)

FunctionRef ::= LocalFunctionRef(function_index)
              | ImportedFunctionRef(module, digest, function_index)

DomainRef ::= LocalDomainRef(domain_index)
            | ImportedDomainRef(module, digest, domain_index)

FieldRef ::= {
  owner: TypeRef,
  field_index: Nat
}

VariantRef ::= {
  owner: TypeRef,
  stable_tag: Nat
}
```

Indices address the canonically sorted declaration tables, never surface order.
Admission verifies that each index is in range and that the indexed declaration
has the expected kind.

Local values use zero-based de Bruijn indices:

```text
LocalRef ::= Nat       ;; 0 is the nearest enclosing binder
```

Surface elaboration resolves names to indices. Renaming a local cannot change the
typed-core module or digest. Surface Seki prohibits shadowing to keep diagnostics
simple even though de Bruijn representation is unambiguous.

## 6. Domains and types

```text
DomainDecl ::= {
  name: Name
}

Type ::= Unit
       | Bool
       | U8 | U16 | U32 | U64
       | I8 | I16 | I32 | I64
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
       | Declared(reference: TypeRef)
```

All natural parameters must fit the selected profile and participate in type
identity. `Index[0]` is invalid. Empty byte strings, arrays, tuples, and bounded
vectors remain profile decisions; they are not inferred from host behavior.

```text
TypeDecl ::= AliasDecl | NominalDecl | RecordDecl | VariantDecl

AliasDecl ::= {
  name: Name,
  target: Type
}

NominalDecl ::= {
  name: Name,
  representation: Type
}

RecordDecl ::= {
  name: Name,
  fields: Map[Name, FieldDecl]
}

FieldDecl ::= {
  name: Name,
  type: Type
}

VariantDecl ::= {
  name: Name,
  cases: Map[Nat, VariantCase]
}

VariantCase ::= {
  name: Name,
  stable_tag: Nat,
  payload: Option[PayloadDecl]
}

PayloadDecl ::= {
  fields: Map[Name, FieldDecl]
}
```

Aliases are transparent and create no identity. Nominals, records, and variants
are distinct by declaration reference. Nominal construction/destruction is only
available through admitted constructors or representation adapters; equal physical
bytes do not cross nominal declarations or identity domains.

Records use canonical field-label order. A surface record literal may write fields
in any order, but elaboration produces the canonical map and typed-core evaluation
uses canonical field order. This prevents source field order from changing a
module's digest or failure selection.

Variants require unique nonzero stable tags within their declaration. Source
position is irrelevant. Unknown tags never construct a value.

Recursive and mutually recursive types are excluded from v0.

## 7. Functions and kernels

```text
FunctionKey ::= {
  base: Name,
  labels: Vec[Name]
}

Parameter ::= {
  label: Name,
  type: Type
}

FunctionDecl ::= {
  key: FunctionKey,
  parameters: Vec[Parameter],
  result: Type,
  arithmetic_policy: ArithmeticPolicy,
  body: Expr,
  claimed_bounds: ResourceBounds,
  derivation: FunctionDerivation
}

KernelDecl ::= {
  key: FunctionKey,
  parameters: Vec[Parameter],
  result: Decision(accepted, rejection),
  arithmetic_policy: ArithmeticPolicy,
  rejection_order: Vec[VariantRef],
  body: Expr,
  claimed_bounds: ResourceBounds,
  publication_eligible: Bool,
  derivation: KernelDerivation
}

ArithmeticPolicy ::= checked | wrapping | saturating
```

Function keys are unique across functions and kernels in one module. Overloading
by parameter or result type is excluded. Parameters are ordered by their labels in
the source function pattern; the order is semantic call/evaluation order.

The call graph must be acyclic. User recursion, mutual recursion, and indirect
calls do not exist. Functions and blocks are not runtime values.

Each kernel freezes a complete rejection-constructor order. Every constructor of
the kernel's rejection variant must appear exactly once unless the rejection type
has a separately proved total ordering imported by exact digest.

`publication_eligible` is a declaration of intended use, not permission to
publish. Publication still requires the later certificate and host protocol.

## 8. Typed expressions

```text
Expr ::= {
  claimed_type: Type,
  claimed_bounds: ResourceBounds,
  term: Term
}
```

Admission recomputes both type and bounds. Each child sequence below is evaluated
from left to right unless a node gives a more specific rule.

### 8.1 Values and bindings

```text
Term ::= UnitLit
       | BoolLit(value: Bool)
       | IntLit(type: IntegerType, canonical_bits: Bytes)
       | BytesLit(length: Nat, bytes: Bytes)
       | Local(reference: LocalRef)
       | Let(value: Expr, body: Expr)
```

`Let` evaluates `value`, then evaluates `body` with that immutable result at local
index 0. Existing locals shift outward by one. There is no assignment node.

Integer literals carry an exact integer type and canonical bit representation.
Surface literal elaboration must reject out-of-range values; admission rechecks.

### 8.2 Construction and elimination

```text
Term ::= Record(type: TypeRef, fields: Map[FieldRef, Expr])
       | Project(record: Expr, field: FieldRef)
       | Variant(case: VariantRef, fields: Map[Name, Expr])
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
```

Operands have one explicit integer type; there are no promotions. Wrapping and
saturating nodes return that integer type. Checked nodes return
`Result[IntegerType, ArithmeticError]`. Divide by zero, invalid shift count, and
failed checked conversion are explicit error cases, never stuck states or C
undefined behavior.

The exact stable `ArithmeticError` variant and surface propagation syntax remain
to be frozen. Admission rejects any claimed result inconsistent with the policy.

### 8.5 Static control

```text
Term ::= If(condition: Expr, when_true: Expr, when_false: Expr)
       | Match(scrutinee: Expr, arms: Map[VariantRef, MatchArm])

MatchArm ::= {
  bind_payload: Bool,
  body: Expr
}
```

`If` evaluates one branch only. Both branches have the same type. `Match` evaluates
the scrutinee and exactly one arm. Arms cover every possible constructor exactly
once and use stable-tag canonical order in the typed core. A bound payload is at
local index 0 in the arm body.

Options, results, and decisions use equivalent intrinsic constructor identities
for exhaustiveness even when their surface sugar differs.

Each match arm binds at most one value: the complete payload of the selected
constructor. For a record-payload variant, that binding is the payload record and
fields are projected explicitly. Constructors nested inside a payload require a
nested `Match`; one surface pattern cannot introduce an implicit stack of binders.
When present, the payload binding is local index 0 in the arm body.

### 8.6 Static calls

```text
Term ::= Call(function: FunctionRef, arguments: Vec[Expr])
```

Calls resolve to one exact local or digest-bound imported function. Arguments
match labels and types exactly and evaluate in declared order. Kernels cannot be
called as functions in v0.

### 8.7 Kernel rejection sequence

```text
Term ::= Require(
  condition: Expr,
  rejection: Expr,
  continuation: Expr,
  precedence_index: Nat
)
       | Accept(value: Expr)
       | Reject(reason: Expr, precedence_index: Nat)
```

`Require` is legal only within a kernel returning `Decision[A, R]`. It evaluates
its Boolean condition. False evaluates the rejection expression and produces
the same result as `Reject`; true evaluates the continuation. `Accept` and
`Reject` are likewise legal only within such a kernel and construct the
corresponding `Decision` value.

Every rejection site carries the zero-based index of its reason constructor in
the kernel's declared rejection order. Multiple sites may use the same index.
Admission verifies the reason type, constructor, and index correspondence. The
order vector itself contains every rejection constructor exactly once without
gaps or duplicates.

The reason expression at a rejection site has one statically known outer
constructor; its payload may be computed. Precedence uses a deliberately simple
syntactic rule: indices of nested `Require` nodes must strictly increase through
each continuation. Separate match arms may begin at unrelated indices because
only one arm executes. More permissive semantic analysis of mutually exclusive
requirements is not part of v0 admission.

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
  body: Expr,
  claimed_bounds: ResourceBounds
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
  live_values: Nat,
  stack_bytes: Nat,
  workspace_bytes: Nat
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

The selected profile supplies hard maxima. Each expression carries proposed
bounds; admission derives actual bounds compositionally and requires the claims
to be exact or conservative according to the future bound-witness rule. Integer
overflow while calculating a bound rejects admission.

Call depth derives from the acyclic call graph. Traversal costs use static
capacities, not runtime lengths. Hidden heap, recursive stack, or host callbacks
are impossible in admitted expressions.

## 10. Evaluation result

For an admitted function and well-typed values, evaluation is total:

```text
evaluate : AdmittedFunction × Values -> Value
```

Semantic rejection is a `Reject` result. Checked arithmetic failures are
ordinary `ResultError` values that the program must handle. Malformed input,
authentication failure, cancellation, host failure, and allocation failure occur
outside pure typed-core evaluation and cannot be disguised as semantic acceptance.

Admitted evaluation cannot exceed its proved resource bounds. Exhaustion by a
conforming evaluator is therefore an implementation/profile failure and publishes
nothing, not an alternate semantic result.

## 11. Canonical-model invariants

An admitted module satisfies at least:

1. exact language, schema, module, profile, and import identity;
2. unique canonically ordered map keys;
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
  local_display_names: Map[NodePath, Name],
  source_ranges: Map[NodePath, SourceRange],
  comments: Option[diagnostic-only data]
}
```

The sidecar must bind the exact typed-core digest. It may improve errors but cannot
change admission, evaluation, generated code, proofs, or publication.

## 13. Encoding questions deliberately deferred

The abstract model does not decide:

- binary, canonical JSON, or canonical CBOR representation;
- integer and length prefix encodings;
- whether canonical maps serialize as sorted pairs or schema-positioned arrays;
- exact derivation witness representation;
- schema evolution fields and extension rejection; or
- diagnostic-sidecar wire format.

The encoding decision must preserve every invariant above and minimize the size
of the verified decoder.
