# Seki surface language v0 draft

Status: bootstrap proposal; non-normative; syntax not frozen

Language identity: `io.frogfish.seki/language@0`

This document proposes a developer-facing surface syntax for Seki. It draws on
the message-oriented Zing lineage in `contrib/spec`, but all conclusions here
are Seki decisions. The canonical serialized typed core remains the semantic
authority root. Parse success is not admission.

Seki deliberately does not resemble C. Its compiler emits C, but Seki has no C
pointers, implicit promotions, mutable variables, general loops, or undefined
behavior. The distinct message-oriented surface prevents generated-backend
intuition from being mistaken for source semantics and makes Seki kernels
visibly identifiable during review.

## 1. Design rules

The v0 surface must make small total kernels easy to read while keeping
elaboration deterministic:

1. all names, calls, fields, and intrinsics resolve statically;
2. every parameter and result is explicitly typed;
3. locals are immutable and cannot shadow another visible local;
4. every traversal is a recognized bounded combinator;
5. evaluation is receiver first, then arguments from left to right;
6. conditions require `Bool`; there is no truthiness;
7. failure and rejection are values, never exceptions; and
8. unsupported or ambiguous forms are rejected rather than guessed.

## 2. Source and names

Source files are UTF-8. Structural tokens and identifiers are ASCII in v0;
comments may contain arbitrary valid Unicode. A line comment begins with `;;`
and continues through the next line ending or end of file. Block comments are
not supported.

Type and variant names begin with an uppercase ASCII letter. Module components,
values, fields, functions, labels, and binders begin with a lowercase ASCII
letter. Remaining identifier characters are ASCII letters, digits, and `_`.
Keywords cannot be identifiers.

Newlines are trivia. Top-level declarations and body statements end in `.`. A
final expression immediately before `]` has no trailing period and supplies the
body's value.

## 3. Modules and imports

Every source file begins with exactly one module declaration:

```seki
module frogfish::examples::candidate_selection @ 1
profile: c11_bounded @ 1
claims: semantic_evaluation
requires: type_well_formed, totality, determinism, resource_bounds,
  rejection_precedence.
```

The declared module identity consists of its path and semantic version. The
selected semantic profile has its own name and version; both enter the canonical
module and digest. `claims:` is the module's ceiling, not proof that the claims
hold. `requires:` lists theorem obligations which later stages must discharge.
The candidate closed set for this draft, in canonical order, is:

```text
claims: semantic_evaluation, lean_projection, representation_correspondence,
        restricted_c_source, clight_refinement, certified_lean_equivalence,
        installed_binary, publication

requires: type_well_formed, totality, determinism, resource_bounds,
          rejection_precedence, representation, publication_equivalence
```

Only the needed members are written and duplicates are invalid.
`publication: eligible` additionally requires the `publication` claim and
`publication_equivalence` theorem obligation.

A qualified import binds an exact version and digest:

```seki
use seki::bounded @ 1
profile: c11_bounded @ 1
digest: sha256:"0000000000000000000000000000000000000000000000000000000000000000".
```

Wildcard imports, version ranges, ambient search paths, cyclic imports, and
multiple modules per file are invalid. The concrete digest literal encoding
will be frozen with the typed-core wire encoding.

## 4. Types

The v0 primitive spellings follow the charter:

```text
Unit Bool
U8 U16 U32 U64
I8 I16 I32 I64
ArithmeticError
Bytes[N]
Identity[Domain, N]
Digest[Algorithm, N]
Index[Bound]
```

The composite forms are:

```text
Option[T]
Result[T, E]
Tuple[T1, ..., Tn]
Array[T, N]
BoundedVec[T, N]
Decision[Accepted, Rejection]
```

Primitive and composite constructor spellings are reserved built-ins and cannot
be redeclared. `ArithmeticError` is the intrinsic checked-operation error type;
its constructors and stable tags are defined by the typed core.

Aliases do not create identity. Nominal declarations do:

```seki
export domain CandidateIdentity.
export type Counter := U32.
export nominal CandidateId := Identity[CandidateIdentity, 16].
export nominal Epoch := U64.
```

Domain names and type names occupy distinct namespaces, but v0 rejects reuse of
one spelling across those namespaces to prevent visually ambiguous references.

Records and variants use Zing-derived delimiters:

```seki
export record Candidate {
  id: CandidateId,
  epoch: Epoch,
  enabled: Bool
}.

export variant Rejection [
  Missing @ 1.
  Duplicate @ 2.
  Stale @ 3.
  Disabled @ 4.
].
```

Variant tags are explicit stable natural numbers. Duplicate names, fields, or
tags are invalid. Records and variants are nominal. Recursive types are excluded
from v0.

## 5. Functions and kernels

A pure internal function and an exported kernel use typed message-pattern heads:

```seki
fn isCurrent candidate: Candidate epoch: Epoch
-> Bool
arithmetic: checked [
  (candidate epoch) == epoch
].

export kernel select input: Input
-> Decision[Candidate, Rejection]
arithmetic: checked
bounded steps: 2048 liveBits: 4096 controlDepth: 64 workspaceBits: 4096
rejects: Rejection::Missing, Rejection::Duplicate, Rejection::Stale,
  Rejection::Disabled
publication: none [
  ;; body
].
```

The external labels are part of function identity. Parameter locals use the
same names as their labels in v0; Zing's distinct external-label/local-name form
is not admitted. Overloading and user-defined receiver methods are excluded.
Functions cannot recurse directly or through an import cycle.

Every function has an explicit result type. A body returns its final expression;
`ret` does not exist. A kernel result is normally `Decision[A, R]`.

Every typed-core function has an explicit resource ceiling. If a surface
function omits `bounded`, elaboration inserts the selected profile's
per-function ceiling. Kernels spell their ceiling explicitly in v0.
`steps`, `liveBits`, `controlDepth`, and `workspaceBits` map respectively to the
typed-core ceiling fields `logical_steps`, `maximum_live_value_bits`,
`maximum_control_depth`, and `maximum_workspace_bits`. They are declared maxima;
the canonical structural derivation is stored and checked separately.

`rejects:` declares every rejection constructor once, from highest to lowest
precedence. Its type must be one declared variant, local or exact-digest imported.
`publication:` is `none` or `eligible`; eligibility is an intended profile use
and never grants publication authority.

## 6. Bindings and bodies

`:=` introduces one fresh immutable binding:

```seki
selection := input candidates findUnique: [ :candidate |
  (candidate id) == (input wanted)
].
```

The right side is evaluated before the binding becomes visible. Reusing a
visible name, assigning to a field, or assigning to `_` is invalid. Bindings do
not have a separate type annotation because their type is derived from the
admitted right side.

Expression statements whose value is discarded are not permitted in pure v0
kernel bodies. Each non-final statement must bind a value or be a `require`.

## 7. Fields, calls, and blocks

Field projection uses a unary selector:

```seki
candidate epoch
input candidates
```

A free function repeats its message-pattern labels:

```seki
isCurrent candidate: candidate epoch: (input currentEpoch)
```

Recognized operations on a value use keyword selectors:

```seki
input candidates findUnique: [ :candidate | predicate ]
```

Blocks are inline binders used only by conditionals, matches, and admitted
bounded combinators:

```seki
[ expression ]
[ :candidate | expression ]
[ :acc :item | expression ]
```

Blocks capture visible values immutably. They cannot be named, returned, stored,
compared, passed through generic functions, exported, or represented in the
canonical typed core as general closures.

## 8. Precedence and evaluation

Unlike historic Zing, binary operators do not share one flat precedence level.
From tightest to loosest, Seki parses:

1. primary expressions and grouping;
2. unary field projection;
3. unary `-`;
4. `*`, `/`, and `%`;
5. `+` and binary `-`;
6. `<`, `<=`, `>`, and `>=`;
7. `==` and `!=`;
8. `&&`;
9. `||`; and
10. keyword messages.

Arithmetic binary operators associate left. Comparisons do not chain. `&&` and
`||` short-circuit. Parentheses group exactly one expression.

Evaluation is deterministic: receiver before arguments and keyword arguments
from left to right. Record fields evaluate in canonical ASCII-label order, not
written order. Record field order therefore cannot affect the resulting value,
failure selection, or canonical serialization.

## 9. Arithmetic

Each function or kernel declares a default arithmetic policy: `checked`,
`wrapping`, or `saturating`. The first profile should require `checked` unless a
more permissive policy is explicitly justified.

An expression can override the inherited policy:

```seki
next := wrapping: [ counter + 1 ].
```

There are no implicit promotions. Mixed widths and signedness require an
explicit conversion operation. Unary `-` is admitted only for signed integers.
Decimal literal digits with an optional adjacent leading minus denote one
mathematical value: `-128` is a literal, not checked negation of `128`. A minus
separated from the literal or applied to another expression is policy-sensitive
unary negation. Elaboration uses the unique expected integer type and rejects a
literal when its type is ambiguous or its value is out of range.
`/` truncates signed quotients toward zero and `%` uses the corresponding
remainder. Division, remainder, and shifts return typed operational results
because zero divisors and invalid shift counts remain possible under every
policy. Exact conversion, shift, and result-propagation surface forms remain tied
to the typed-core error model and are not frozen by this draft.

## 10. Conditionals, matching, and rejection

A two-arm conditional is an expression and preserves the Zing message shape:

```seki
condition ifTrue: [ whenTrue ] ifFalse: [ whenFalse ]
```

Both branches must have the same type. One-arm conditionals and `whileTrue:` are
excluded.

Pattern matching is an expression:

```seki
match value [
  Some: [ :item | consume item ].
  None: [ fallback ].
]
```

Arms must be exhaustive, constructors cannot repeat, and every arm has the same
result type. A nullary constructor takes a zero-parameter block; a payload
constructor takes exactly one block parameter for its complete payload. Nested
destructuring requires a nested `match`. The precise declared-payload field
pattern syntax remains provisional.

A kernel may enforce ordered semantic rejection with `require`:

```seki
require count != 0 else: Rejection::Missing.
require count == 1 else: Rejection::Duplicate.
```

`require condition else: reason` is legal only in a kernel returning
`Decision[A, R]`; false immediately produces `Decision::Reject { reason: reason }`.
Its position on each sequential control path determines rejection precedence.
Bindings, conditionals, and matches cannot reset that order. The final accepted
value is explicit:

```seki
accept candidate
```

`accept` is legal only as the final expression of such a kernel. It constructs
the accepting `Decision` value; it does not publish authority.

A match arm or conditional branch may instead end with:

```seki
reject Rejection::Missing
```

The elaborator assigns the constructor's index from `rejects:`. Direct rejection
and failed `require` produce the same `Decision::Reject` semantic result.

Kernel decision control is tail-only. `accept`, `reject`, and `require` cannot be
used as record fields, call arguments, arithmetic operands, collection-block
results, or stored values. Surface bindings elaborate to `KernelLet`; a final
conditional or match elaborates to `KernelIf` or `KernelMatch`. This makes every
kernel path end in exactly one acceptance or rejection.

## 11. Bounded collections

The admitted traversal selector set is closed and versioned:

```text
collection fold: initial with: [ :acc :item | ... ]
collection findUnique: [ :item | ... ]
collection all: [ :item | ... ]
collection any: [ :item | ... ]
collection mapBounded: [ :item | ... ]
collection filterBounded: [ :item | ... ]
```

These selectors elaborate to dedicated typed-core operations. They are not
ordinary dispatch and cannot be redefined. Their iteration bound comes from the
collection's static capacity, not from an unchecked runtime value.

General loops, recursion, `break`, `continue`, `goto`, and labels do not exist.

## 12. Complete illustrative module

```seki
module seki::examples::candidate_selection @ 1
profile: c11_bounded @ 1
claims: semantic_evaluation
requires: type_well_formed, totality, determinism, resource_bounds,
  rejection_precedence.

export domain CandidateIdentity.
export nominal CandidateId := Identity[CandidateIdentity, 16].
export nominal Epoch := U64.

export record Candidate {
  id: CandidateId,
  epoch: Epoch,
  enabled: Bool
}.

export record Input {
  wanted: CandidateId,
  currentEpoch: Epoch,
  candidates: BoundedVec[Candidate, 32]
}.

export variant Rejection [
  Missing @ 1.
  Duplicate @ 2.
  Stale @ 3.
  Disabled @ 4.
].

export kernel select input: Input
-> Decision[Candidate, Rejection]
arithmetic: checked
bounded steps: 2048 liveBits: 4096 controlDepth: 64 workspaceBits: 4096
rejects: Rejection::Missing, Rejection::Duplicate, Rejection::Stale,
  Rejection::Disabled
publication: none [
  selection := input candidates findUnique: [ :candidate |
    (candidate id) == (input wanted)
  ].

  match selection [
    Error: [ :duplicate |
      reject Rejection::Duplicate
    ].
    Ok: [ :option |
      match option [
        None: [
          reject Rejection::Missing
        ].
        Some: [ :candidate |
          require (candidate epoch) == (input currentEpoch)
            else: Rejection::Stale.
          require candidate enabled else: Rejection::Disabled.
          accept candidate
        ].
      ]
    ].
  ]
].
```

`findUnique:` returns `Result[Option[T], Unit]`: error means duplicate, none means
missing, and some carries the unique value. The complete collection is scanned so
a later duplicate cannot be hidden by discovery order.

## 13. Deliberately open surface questions

The draft does not yet freeze:

- canonical module and digest literal spelling;
- byte and identity literals;
- tuple construction and projection;
- declared-variant payload construction and pattern details;
- checked arithmetic and conversion result syntax;
- whether `countWhere:` should be added to the minimal combinator set;
- generic function declarations, if any;
- formatting width and canonical source formatting; or
- diagnostics and source-location conventions.

These questions must follow typed-core decisions. They are not resolved by the
contributed Zing parser accepting a convenient form.
