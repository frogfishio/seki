# `c11_bounded @ 1` semantic profile draft

- Status: bootstrap fixture profile; non-normative
- Purpose: make v0 elaboration and encoded fixtures numerically closed

## 1. Identity and scope

```text
ProfileId ::= { name: c11_bounded, version: 1 }
```

Despite its historical name, this is the semantic admission profile used by the
initial portable-C projection; it does not inherit C evaluation, layout, integer
overflow, stack, or ABI behavior. A later naming review should decide whether a
backend-neutral name is clearer before any profile identity freezes.

The profile admits exactly the v0 typed-core inventory. Backend-specific
qualification remains a later claim.

## 2. Hard profile ceilings

```text
maximum_bundle_bytes:          16777216
maximum_bundle_modules:              32
maximum_bundle_import_edges:          64
maximum_bundle_dependency_depth:       8

maximum_input_bytes:             1048576
maximum_typed_core_bytes:        1048576
maximum_imports:                      32
maximum_declarations:               4096
maximum_expression_nodes:          65536
maximum_nesting:                     256
maximum_call_depth:                   32

maximum_resource_bounds: {
  logical_steps:                 16777216,
  maximum_live_value_bits:        8388608,
  maximum_control_depth:              256,
  maximum_workspace_bits:         8388608
}
```

These are admission maxima, not recommendations and not preallocation sizes.
Every decoder checks the smaller declared module/callable bound before the
profile maximum where applicable.

## 3. Surface default

If a v0 source module omits a module-level ceiling declaration, elaboration
copies the complete profile ceilings above into `declared_module_ceiling`. This
is deterministic source elaboration only; the canonical typed core always
contains the explicit `ModuleBounds` value.

Callable `bounded` clauses remain mandatory in the candidate surface. Their
values must not exceed the module or profile resource tuple.

## 4. Open profile findings

- Decide whether to rename this semantic profile before identity freeze.
- Validate the ceilings against the first Gnosis and Kiku kernels.
- Separate semantic input bits from future encoded input-byte and C-layout bounds.
- Freeze the exact set of empty collection/type forms admitted by the profile.

