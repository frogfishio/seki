# Seki type-checking v0 draft

- Status: bootstrap proposal; non-normative
- Target: deliberately syntax-directed, monomorphic checking

## 1. Contexts

Checking uses only explicit finite contexts:

```text
Declarations ::= admitted local declarations plus exact admitted imports
Locals       ::= ordered concrete types; index 0 is the nearest binder
Expected     ::= optional concrete expected type
```

There are two judgments:

```text
infer(Declarations, Locals, Expr) -> Type or TypeError
check(Declarations, Locals, Expr, ExpectedType) -> success or TypeError
```

`check` calls `infer` and requires exact type equality except for contextual
integer literals and the explicitly specified construction forms. It does not
search for conversions or alternate interpretations.

## 2. Complexity ceiling

V0 excludes:

- type variables and user-written type parameters;
- generic type or function declarations;
- polymorphic values or let-generalization;
- overload sets or result-directed function lookup;
- subtyping, row polymorphism, traits, interfaces, and type classes;
- implicit numeric promotion or conversion;
- user-defined operator or message dispatch; and
- unification or constraint solving.

The specification metavariables `T`, `E`, `A`, `R`, `U`, and `N` describe closed
built-in schema rules. They never appear in admitted modules. For example,
`Option[U32]` is one concrete type checked directly; it is not an instantiation
of a user-visible generic declaration.

## 3. Syntax-directed rules

- Literal forms have their declared or unique contextual primitive type.
- A local has exactly the type stored at its de Bruijn index.
- Record and declared-variant constructors name one exact declaration and supply
  every required field once.
- Projection names one exact field of the inferred record or variant payload.
- Function calls name one exact local or digest-bound imported function and
  match its concrete parameter sequence exactly.
- Boolean, comparison, arithmetic, conversion, and collection nodes use the
  closed signatures in the typed-core specification.
- Conditional branches and match arms must have exactly equal result types.
- Match constructor ownership and payload binder type follow directly from the
  scrutinee type.
- Kernel control is checked against its one enclosing concrete `Decision[A,R]`.

Aliases are expanded and cycle-checked before equality. Nominals, identity
domains, records, and variants compare by exact declaration reference. Physical
representation equality never implies type equality.

## 4. Determinism

Each expression form selects one rule. Tables and child sequences are visited in
canonical order, and admission uses its fixed rejection-layer order. Therefore a
well-formed expression has at most one inferred type and malformed input has one
authoritative primary type error once stable error tags are assigned.

Local surface inference is an ergonomics feature only: a `:=` binding receives
the single recomputed type of its right side. It introduces no type variable or
generalization.
