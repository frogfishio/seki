# Two-module import bundle lowering v0

- Status: complete experimental SCB-0 bundle
- Sources: `../../language/examples/import_bundle_base.seki` and
  `../../language/examples/import_bundle_consumer.seki`

## Dependency module

```text
identity: seki::fixtures::base @ 1
types[0]: Token = record(value: U32)
functions[0]: keep labels [value]
  (Token) -> Token
  body: Local[0]
  exact bounds: { steps: 2, live: 64, depth: 2, workspace: 0 }
exports: types [0], functions [0]
type_dependency_order: [0]
function_dependency_order: [0]
```

## Consumer module

The import table has one entry at index zero:

```text
imports[0]: seki::fixtures::base @ 1
  sha256 b2575e4967c7d52fe4249e843b45d343d6304e70c8cfae7c36581a2e65fd51f7
```

Every imported `Token` type is `ImportedTypeRef(0, 0)`. The call to `keep` is
`ImportedFunctionRef(0, 0)`.

```text
functions[0]: forward labels [value]
  (ImportedTypeRef[0,0]) -> ImportedTypeRef[0,0]
  body: Call(ImportedFunctionRef[0,0], [Local[0]])
  exact bounds: { steps: 5, live: 96, depth: 4, workspace: 0 }

functions[1]: twice labels [value]
  body: Call(LocalFunctionRef[0],
             [Call(LocalFunctionRef[0], [Local[0]])])
  exact bounds: { steps: 14, live: 128, depth: 7, workspace: 0 }

function_dependency_order: [0, 1]
```

## Bundle bytes

Modules are encoded in identity order `base`, then `consumer`; the designated
root is `consumer`.

```text
base module:      297 bytes
base digest:      b2575e4967c7d52fe4249e843b45d343d6304e70c8cfae7c36581a2e65fd51f7
consumer module:  518 bytes
consumer digest:  67ec57e4a41fbd7f28c0e7608b2612d62af64c4e293be20f015a1fd425026395
bundle:           872 bytes
bundle SHA-256:   d4a0357ef1060c9d3d27b9b18ccc6389bab0dd0cb8d7ddd148996fa5eb8d015d
```

The last hash is only an experimental transport fingerprint. It is not a
semantic bundle identity rule. Module digests use the SCB-0 module domain.

## Authority limit

The emitter and structural decoder agree on this bundle. The decoder validates
identity closure, profiles, cycles, module digests, exported imported references,
and both dependency schedules. It does not yet recompute full static types or
resource bounds, so this is not an admitted bundle.

