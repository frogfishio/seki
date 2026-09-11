# ADR 0010: Canonical semantic resource-cost algebra

- Status: accepted for bootstrap; not a language freeze
- Date: 2026-09-11

## Decision

Every admitted function and kernel has one structurally derived resource tuple:

```text
(logical_steps, maximum_live_value_bits,
 maximum_control_depth, maximum_workspace_bits)
```

The calculation uses a fixed abstract evaluation schedule, semantic type widths,
static collection capacities, and checked natural-number arithmetic. “Exact”
means exact output of this canonical algebra, not an optimizer-dependent estimate
or the least bound obtainable from semantic path-feasibility analysis.

Logical steps count semantic nodes, callable entries, and block invocations.
Live-value bits use a conservative typed-slot machine. Control depth counts
abstract evaluator frames. Workspace counts closed, per-intrinsic state. None is
a C byte-layout or native stack claim.

## Consequences

- A producer cannot choose among several conservative resource claims.
- Both larger and smaller claims than the recomputed tuple reject admission.
- Short-circuit and branching costs use the worst executable branch.
- Array traversal is charged to static length even when early termination would
  execute fewer iterations.
- F2/F3 must separately prove how semantic slots, frames, and workspace map to C
  objects and concrete byte bounds.
- Admission/proof-checker and host-tool resources require separate profiles.

The detailed draft algebra is maintained in
`spec/typed-core/RESOURCE_COST_ALGEBRA_V0_DRAFT.md`.
