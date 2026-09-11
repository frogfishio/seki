# Seki derivation-witness normal form v0 draft

- Status: bootstrap proposal; non-normative
- Companion: `SEKI_TYPED_CORE_V0_DRAFT.md` revision 0.3
- Principle: canonical reconstruction, not producer-selected proof trees

## 1. Decision

V0 does not serialize a second tree of inference-rule applications. Typing,
totality, import validation, and resource calculation are deterministic functions
of the canonical typed core and closed dependency bundle. Serializing their full
proof trees would duplicate the AST and permit irrelevant proof-shape choices.

Instead, the canonical core itself carries the conclusions needed for replay:

- every `Expr` carries its proposed concrete type;
- every callable carries its concrete signature, declared ceiling, and one exact
  derived resource tuple;
- every imported use carries exact module identity and digest;
- every rejection site carries its exact precedence index; and
- all rule selection follows from closed node discriminants.

`DerivationBundle` adds only the constructive schedules needed to reopen local
acyclic definitions without search-order ambiguity:

```text
DerivationBundle ::= {
  schema_version: Nat,  ;; exactly 0 in v0
  type_dependency_order: Vec[LocalTypeRef],
  function_dependency_order: Vec[LocalFunctionRef]
}
```

This is a compressed proof term. Admission reconstructs every omitted premise
and requires exact equality with every stored conclusion. Successful
reconstruction is the complete derivation; producer assertions alone prove
nothing.

## 2. Canonical dependency order

Both vectors are unique lexicographically least topological orders over canonical
table indices. Use Kahn's algorithm with this fixed choice: repeatedly select the
smallest canonical index whose local dependencies have already appeared. The
vector contains every node exactly once. Failure to select a node before the
vector ends is a cycle and rejects.

`type_dependency_order` contains every local type declaration. A declaration
depends on every local `Declared` type reachable through its alias target,
nominal representation, record fields, variant payload fields, and nested
intrinsic type parameters. Imported types and domains are already leaves for this
local order.

`function_dependency_order` contains every local pure function. A function
depends on every local function reached by a `Call` anywhere in its body,
including inside blocks. Imported functions are leaves. Kernels are not callable
in v0 and therefore cannot participate in a call cycle; their bodies are checked
after the function schedule.

An empty table has an empty order. An order with a duplicate, omission,
out-of-range index, dependency appearing later, or non-minimal eligible choice is
noncanonical and rejects.

## 3. Reconstructed derivations

### Type derivation

Admission visits callable bodies in their canonical schedules and traverses each
body in schema child order. At every `Expr`, it computes the unique result type
from the term rule and local environment, then requires equality with
`claimed_type`. Block parameter and result types, match payload binders, function
signatures, imported signatures, and kernel decision contexts supply all typing
premises.

No type-rule identifier is serialized: the term discriminant selects exactly one
rule. No local environment is serialized: de Bruijn scope reconstructs it
uniquely.

### Totality derivation

Totality is reconstructed from the closed node inventory, bounded intrinsic
capacities, the canonical function dependency order, and the absence of
recursion, indirect calls, escaping blocks, or effects. It has no additional
payload.

### Import derivation

The module import table and every cross-module reference carry the exact identity
and digest premises. Admission reopens the complete finite bundle, computes the
unique lexicographically least module topological order, recomputes all module
digests, and checks exports and signatures. The computed bundle order is not
serialized inside individual modules because it depends on the selected root
closure; storing it would make one module acquire context-dependent bytes.

### Bound derivation

Admission applies the one structural resource-cost algebra in canonical child
order. It requires the resulting tuple to equal `exact_derived_bounds`, then
checks it against the callable, module, and profile ceilings. The AST is the
derivation tree and the stored tuple is its proposed conclusion; intermediate
tuples are not serialized because each is a unique function of its subtree and
context.

### Rejection-precedence derivation

Admission applies `check_order` structurally to the tail-formed `KernelExpr` and
requires every stored site index to name the reason's constructor in the complete
kernel rejection order. No separate precedence proof is serialized.

## 4. Digest and proof-artifact boundary

All reconstruction inputs, including `DerivationBundle`, claimed expression
types, exact bounds, imports, and rejection indices, are in the canonical module
bytes and therefore in its digest.

This normal form is an admission certificate for a module. It is distinct from
SSDC-1, the later per-invocation semantic derivation containing intermediate
runtime values and the final decision. Removing redundant static proof-tree bytes
from the module does not weaken SSDC-1.

## 5. Remaining freeze obligations

- formalize each dependency-edge extraction function;
- finish the resource recurrence for canonical context-sensitive live values;
- prove reconstruction sound and complete for the admitted model;
- assign final SCB-0 fields and tags; and
- add hostile vectors for every malformed dependency order and mismatched stored
  conclusion.

