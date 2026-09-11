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
profile: c11_bounded_v1.
```

The module identity consists of its path, semantic version, and selected
semantic profile. A qualified import binds an exact version and digest:

```seki
use seki::bounded @ 1
digest: sha256:"0123456789abcdef...".
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

Aliases do not create identity. Nominal declarations do:

```seki
export type Counter := U32.
export nominal CandidateId := Identity[Candidate, 16].
export nominal Epoch := U64.
```

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
bounded steps: 2048 stack: 512 workspace: 4096 [
  ;; body
].
```

The external labels are part of function identity. Parameter locals use the
same names as their labels in v0; Zing's distinct external-label/local-name form
is not admitted. Overloading and user-defined receiver methods are excluded.
Functions cannot recurse directly or through an import cycle.

Every function has an explicit result type. A body returns its final expression;
`ret` does not exist. A kernel result is normally `Decision[A, R]`.

## 6. Bindings and bodies

`:=` introduces one fresh immutable binding:

```seki
matches := input candidates countWhere: [ :candidate |
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
input candidates countWhere: [ :candidate | predicate ]
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
3. `*` and `/`;
4. `+` and `-`;
5. `<`, `<=`, `>`, and `>=`;
6. `==` and `!=`;
7. `&&`;
8. `||`; and
9. keyword messages.

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
explicit checked conversion operation. Division by zero and failed checked
operations produce typed operational results; exact surface forms remain tied
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
  Some value: [ :item | use item ].
  None: [ fallback ].
]
```

Arms must be exhaustive, constructors cannot repeat, and every arm has the same
result type. The exact payload-pattern grammar is still provisional.

A kernel may enforce ordered semantic rejection with `require`:

```seki
require count != 0 else: Rejection::Missing.
require count == 1 else: Rejection::Duplicate.
```

`require condition else: reason` is legal only in a kernel returning
`Decision[A, R]`; false immediately produces `Decision::Reject { reason: reason }`.
Its written position determines rejection precedence. The final accepted value
is explicit:

```seki
accept candidate
```

`accept` is legal only as the final expression of such a kernel. It constructs
the accepting `Decision` value; it does not publish authority.

## 11. Bounded collections

The admitted traversal selector set is closed and versioned:

```text
collection fold: initial with: [ :acc :item | ... ]
collection findUnique: [ :item | ... ]
collection all: [ :item | ... ]
collection any: [ :item | ... ]
collection mapBounded: [ :item | ... ]
collection filterBounded: [ :item | ... ]
collection countWhere: [ :item | ... ]
```

These selectors elaborate to dedicated typed-core operations. They are not
ordinary dispatch and cannot be redefined. Their iteration bound comes from the
collection's static capacity, not from an unchecked runtime value.

General loops, recursion, `break`, `continue`, `goto`, and labels do not exist.

## 12. Complete illustrative module

```seki
module seki::examples::candidate_selection @ 1
profile: c11_bounded_v1.

export nominal CandidateId := Identity[Candidate, 16].
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
bounded steps: 2048 stack: 512 workspace: 4096 [
  matches := input candidates countWhere: [ :candidate |
    (candidate id) == (input wanted)
  ].

  require matches != 0 else: Rejection::Missing.
  require matches == 1 else: Rejection::Duplicate.

  selected := input candidates findUnique: [ :candidate |
    (candidate id) == (input wanted)
  ].

  candidate := selected requireSome: Rejection::Missing.

  require (candidate epoch) == (input currentEpoch)
    else: Rejection::Stale.
  require candidate enabled else: Rejection::Disabled.

  accept candidate
].
```

The repeated missing case above is intentional: `findUnique:` returns an option
or result rather than an unchecked value, and the admission checker does not use
earlier facts unless a proof-producing refinement pass supplies the connection.
The exact `findUnique:` result and `requireSome:` signatures remain to be frozen.

## 13. Deliberately open surface questions

The draft does not yet freeze:

- canonical module and digest literal spelling;
- byte and identity literals;
- tuple construction and projection;
- variant payload construction and pattern details;
- checked arithmetic and conversion result syntax;
- the exact result of `findUnique:`;
- whether `countWhere:` belongs in the minimal combinator set;
- generic function declarations, if any;
- formatting width and canonical source formatting; or
- diagnostics and source-location conventions.

These questions must follow typed-core decisions. They are not resolved by the
contributed Zing parser accepting a convenient form.
