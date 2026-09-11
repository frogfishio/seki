# Experimental SCB-0 decoder review

- Date: 2026-09-11
- Scope: independent structural reopening and first hostile vectors
- Disposition: useful bootstrap oracle; not an admission checker
- Authority: no canonical-byte, type-safety, resource, or proof claim

## Result

A new cursor-based decoder independently reopens the 149-byte minimal module and
the 1,025-byte candidate-selection module. It parses every current type, term,
kernel-control, reference, declaration, module, and resource field; checks
bounded lengths; enforces table and set order during traversal; and validates the
candidate's least type-dependency schedule.

Fifteen targeted hostile cases now cover envelope failures, schema identity,
unknown discriminants, invalid Boolean/option tags, table and set canonicality,
the type reconstruction schedule, and three competing-error precedence cases.

## Traversal finding

The first implementation checked table order only after reading the complete
table. That could allow a malformed later value to mask an earlier bad key. The
decoder now compares each key immediately after reading it and before reading its
value. Ordered sets use the same streaming rule. A combined mutation locks this
precedence behavior.

## Deliberate limits

- The decoder constructs an experimental JavaScript object, not a verified Lean
  value.
- It validates only the empty function dependency schedule exercised by current
  fixtures.
- It does not recompute expression types, resource tuples, imports, exports, or
  kernel precedence semantics.
- Mutation generation currently operates from recorded positive bytes rather
  than storing independent binary hostile artifacts.

## Next work

The next fixture should be a two-module bundle containing one exported type and
one imported pure function. That forces module-envelope nesting, digest reopening,
qualified imported references, export validation, import DAG ordering, and a
nonempty function dependency schedule before more local expression work is added.

