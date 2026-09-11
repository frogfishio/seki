# SCB-0 schema and discriminant ledger

- Status: provisional assignment ledger; non-normative; bytes not frozen
- Scope: authority-bearing typed-core modules

All discriminants below are one `U8` and are local to their named sum. Decimal
values are used for review; the encoded value is the corresponding single octet.
Unknown values reject. Removing or reusing an assigned case requires a new schema
version.

## 1. Primitive enumerations

```text
DigestAlgorithm: sha256=0
Bool: false=0, true=1
Option: none=0, some=1

IntegerType: U8=0, U16=1, U32=2, U64=3,
             I8=4, I16=5, I32=6, I64=7

ArithmeticPolicy: checked=0, wrapping=1, saturating=2
CompareOp: less=0, less_equal=1, greater=2, greater_equal=3
IntBinaryOp: add=0, subtract=1, multiply=2, divide=3, remainder=4
IntUnaryOp: negate=0
ShiftDirection: left=0, right=1
ArithmeticError: overflow=0, divide_by_zero=1, invalid_shift=2, out_of_range=3
```

Theorem and claim vectors are strictly increasing by these tags:

```text
TheoremRequirement:
  type_well_formed=0, totality=1, determinism=2, resource_bounds=3,
  rejection_precedence=4, representation=5, publication_equivalence=6

ClaimKind:
  semantic_evaluation=0, lean_projection=1,
  representation_correspondence=2, restricted_c_source=3,
  clight_refinement=4, certified_lean_equivalence=5,
  installed_binary=6, publication=7
```

## 2. Reference sums

```text
TypeRef: local=0, imported=1
FunctionRef: local=0, imported=1
DomainRef: local=0, imported=1
FieldOwnerRef: record_type=0, variant_payload_owner=1
SumTypeRef: declared_variant=0, intrinsic_option=1, intrinsic_result=2,
            intrinsic_decision=3, intrinsic_arithmetic_error=4
```

`KernelRef`, `FieldRef`, `VariantRef`, and `ConstructorRef` are positional records,
not tagged sums. Local indices are `U32`. Imported references encode `ModuleId`,
`DigestId`, then the `U32` declaration index. Intrinsic constructor stable tags
are the `U32` forms of their language tags.

## 3. Type and declaration sums

```text
Type:
   0 Unit                 1 Bool                  2 U8
   3 U16                  4 U32                   5 U64
   6 I8                   7 I16                   8 I32
   9 I64                 10 ArithmeticError      11 Bytes(length)
  12 Identity(domain,length)
  13 Digest(algorithm,length)
  14 Index(bound)        15 Option(item)         16 Result(ok,error)
  17 Tuple(items)        18 Array(item,length)   19 BoundedVec(item,capacity)
  20 Decision(accepted,rejection)
  21 VariantPayload(case)
  22 Declared(reference)

TypeDeclBody: alias=0, nominal=1, record=2, variant=3
```

Every parenthesized field is encoded immediately in the listed order. Leaf types
have no payload. `DomainBody` is zero bytes because its enclosing table entry
already establishes the declaration and v0 has only `unit`.

Declaration records use these fixed field orders:

```text
AliasBody: target
NominalBody: representation
RecordBody: fields
FieldBody: type
VariantBody: cases
VariantCaseBody: name, payload
PayloadBody: fields

FunctionKey: base, labels
FunctionBody: parameter_types, result, body, declared_ceiling,
              exact_derived_bounds
KernelBody: parameter_types, result, rejection_order, body, declared_ceiling,
            exact_derived_bounds, publication_eligible
```

## 4. Pure term sum

```text
Term:
   0 UnitLit
   1 BoolLit(value)
   2 IntLit(type,value)
   3 BytesLit(length,bytes)
   4 Local(reference)
   5 Let(value,body)
   6 Record(type,fields)
   7 Project(record,field)
   8 Variant(case,fields)
   9 Tuple(items)
  10 OptionNone(item_type)
  11 OptionSome(value)
  12 ResultOk(error_type,value)
  13 ResultError(ok_type,error)
  14 Equal(left,right)
  15 NotEqual(left,right)
  16 Not(value)
  17 AndThen(left,right)
  18 OrElse(left,right)
  19 Compare(op,left,right)
  20 IntBinary(policy,op,left,right)
  21 IntUnary(policy,op,value)
  22 IntShift(policy,direction,value,count)
  23 IntConvert(policy,target,value)
  24 If(condition,when_true,when_false)
  25 Match(scrutinee,arms)
  26 Call(function,arguments)
  27 ArrayGet(collection,index)
  28 VecLength(collection)
  29 VecGet(collection,index)
  30 Fold(collection,initial,step_block)
  31 FindUnique(collection,predicate_block)
  32 All(collection,predicate_block)
  33 Any(collection,predicate_block)
  34 MapBounded(collection,map_block)
  35 FilterBounded(collection,predicate_block)
```

`Expr` encodes `claimed_type, term`. `Block` encodes `parameters, result, body`.
`MatchArm` encodes only `body`. Tables and sequences use the SCB-0 definite
sequence encoding; table keys are explicit and must be strictly increasing.

The integer payload of `IntLit` has exactly the byte width named by its
`IntegerType`; there is no length prefix. `BytesLit` encodes its one `U32` length
followed by exactly that many raw octets, not a second nested `Bytes` length.
Admission rejects a mathematical integer that is not represented by its type's
exact bit pattern or a byte literal whose payload is truncated.

## 5. Kernel-control sum

```text
KernelExpr:
  0 KernelAccept(value)
  1 KernelReject(reason,precedence_index)
  2 KernelRequire(condition,rejection,precedence_index,continuation)
  3 KernelLet(value,body)
  4 KernelIf(condition,when_true,when_false)
  5 KernelMatch(scrutinee,arms)
```

`KernelMatchArm` encodes only `body`. The tail grammar distinguishes pure and
kernel control without a mode bit.

## 6. Positional authority records

```text
ModuleId: path, version
ProfileId: name, version
DigestId: algorithm, algorithm-defined exact digest octets
ImportBody: digest
ExportSet: domains, types, functions, kernels
TheoremRequirement: U8 tag
ClaimKind: U8 tag

Module:
  schema_version, language, identity, semantic_profile, imports, domains, types,
  functions, kernels, exports, required_theorems, claim_ceiling,
  declared_module_ceiling, derivations

ResourceBounds:
  logical_steps, maximum_live_value_bits, maximum_control_depth,
  maximum_workspace_bits

ModuleBounds:
  maximum_input_bytes, maximum_typed_core_bytes, maximum_imports,
  maximum_declarations, maximum_expression_nodes, maximum_nesting,
  maximum_call_depth, maximum_resource_bounds

DerivationBundle:
  schema_version, type_dependency_order, function_dependency_order
```

`LanguageId` has one value in v0 and therefore occupies zero payload octets in its
schema position, like `DomainBody::unit`. The envelope version and digest domain
select that exact language identity; there is no alternate spelling to decode.

## 7. Table key encodings

```text
imports: ModuleId
domains: Name
types: Name
functions: FunctionKey
kernels: FunctionKey
record/payload fields: Name
variant cases: U32 stable tag
record constructor fields: FieldRef
variant constructor fields: Name
match arms: ConstructorRef
kernel match arms: ConstructorRef
```

Canonical comparison is over typed key values, not raw encoded byte strings. The
recursive orders are specified in `SCB0_KEYS_ENVELOPE_AND_DIGEST.md`.

## 8. Remaining ledger work

- review the candidate envelope and typed canonical key comparisons;
- validate SHA-256 domain separation and digest payload handling with vectors;
- enforce the v0 `U32` ceiling in every `Nat` position;
- validate the provisional `AdmissionReason` registry with hostile vectors; and
- generate the first positive and hostile byte vectors.
