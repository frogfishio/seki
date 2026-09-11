# Canonical typed-core boundary

Status: bootstrap design target; not an F1 implementation claim

The canonical serialized typed-core module will be Seki's semantic authority
root. Surface `.seki` text will be a developer interface whose parser and
elaborator propose typed-core objects for admission.

## Initial semantic slice

The first slice should contain only what is needed for a fixture-independent,
bounded decision kernel:

- booleans and explicitly sized integers;
- nominal identities that cannot be compared across domains;
- records, variants, options, and results;
- fixed-capacity arrays with explicit logical length;
- pure expressions, local bindings, and non-recursive function calls;
- statically bounded traversal, search, and folds;
- explicit accept and reject results; and
- deterministic evaluation and rejection precedence.

The slice excludes general recursion, unbounded loops, ambient effects,
implicit allocation, exceptions, concurrency, host pointers, customer domain
types, and backend-specific operations.

## Admission obligations

An admitted root bundle must bind its language and single semantic-profile
identity, direct imports and their canonical-core digests, declarations, concrete
types, bounds, derivation witnesses, and exported kernels. The complete finite
dependency bundle is supplied to admission; the checker never resolves paths or
packages. Admission must reject unknown or duplicate fields, ill-typed terms,
nominal-domain mismatches, missing/extra/substituted/cyclic imports, unsupported
constructs, and missing or invalid bounds.

V0 typing is syntax-directed and monomorphic. Parameterized built-in types and
intrinsics are closed schema families, not user-defined generics. Human source
imports exact versions through aliases; generated `seki.lock` records digests.

## Serialization freeze criteria

The concrete wire encoding remains undecided. It may be frozen only after we
can state and test:

1. injectivity over admitted typed-core values;
2. one encoding for every admitted value;
3. deterministic field order and integer representation;
4. duplicate and unknown-field rejection;
5. explicit Unicode and byte-string rules;
6. version and semantic-profile binding; and
7. a feasible path to verified Lean decoding and encoding.

Surface syntax must not be frozen before this boundary.
