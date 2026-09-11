# Seki modules and lockfile v0 draft

- Status: bootstrap proposal; non-normative
- Target: exact, qualified modules one step beyond textual inclusion

## 1. Source model

A source file declares one module and imports exact versions under explicit local
aliases:

```seki
module acme::policy @ 1
profile: c11_bounded @ 1
claims: semantic_evaluation
requires: type_well_formed, totality, determinism, resource_bounds.

use seki::bounded @ 1 as bounded.
```

The alias and imported `ModuleId` are each unique within the file. The alias is
used for every imported reference, such as `bounded::Counter` or
`bounded::increment value: counter`. Nothing is introduced unqualified. An alias
is source-only and disappears during elaboration.

Imports name exact natural-number versions. V0 has no ranges, compatibility
selection, fallback, re-export, conditional import, implicit prelude, or module
initializer.

## 2. Lock model

Humans do not write content digests in `.seki` files. Tooling generates and
commits one `seki.lock` for the root build closure. Its abstract content is:

```text
LockFile ::= {
  schema: "io.frogfish.seki/lock@0",
  root: ModuleId,
  dependencies: Table[ModuleId, DigestId]
}
```

Each digest covers the dependency's complete canonical typed-core module,
including its own exact imports and derivations. The proposed concrete lockfile
is restricted canonical JSON as specified in
`../encoding/SEKI_LOCK_JSON_V0_DRAFT.md`. It is deliberately distinct from the
SCB-0 authority format.

The lockfile contains no semantic source path, registry URL, mirror, or search
order. Development tooling receives module files or directories explicitly and
may retain locations in a diagnostic-only project file or sidecar.

Lock generation is explicit and never an incidental side effect of building:

```text
sekic lock root.seki --module bounded.seki
sekic build --locked root.seki --bundle modules/
```

The command spelling is illustrative until the CLI exists. A missing or stale
lock causes a locked build to stop and tell the user to regenerate it; dependency
bytes are never silently substituted or upgraded.

## 3. Admission bundle

Admission is given the root canonical module bytes and a finite collection of
dependency module bytes. It does not resolve locations. It:

1. applies profile ceilings for total bytes, module count, import-edge count, and
   dependency depth before or during bounded allocation;
2. decodes every supplied module canonically;
3. requires unique exact `ModuleId` values;
4. recomputes every canonical module digest;
5. requires every import identity and digest to match exactly one supplied module;
6. rejects unused supplied modules, missing modules, substitutions, and profile
   mismatches;
7. requires one semantic profile across the v0 bundle;
8. rejects cycles; and
9. admits modules in deterministic dependency order, then admits the root.

The lockfile is useful build evidence but is not trusted by itself. Authority
comes from reopening the actual bundled module bytes and their digests.

## 4. Qualified lookup

An imported typed-core reference contains exact module identity, digest, and
canonical declaration index. Admission verifies that:

- the module is a direct declared import;
- the digest matches both the import and supplied module;
- the referenced declaration is exported and has the expected kind; and
- its concrete type/signature matches the use site exactly.

Transitive dependencies are not automatically visible. Re-export is absent in
v0. Data declarations are exported explicitly; pure functions are private unless
declared `export fn`. Kernels cannot be called through imports.

## 5. Proof shape

The dependency relation is a finite acyclic graph under explicit profile limits
for module count, total bytes, edge count, and depth. Admission proves each leaf
independently and proceeds in canonical `ModuleId` tie-broken topological order. A
module may rely on the admitted definitions and function semantics of a direct
import, but v0 has no source-level theorem import or proof-search system.
