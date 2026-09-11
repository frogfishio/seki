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
  sha256 e04360ea115d3ba3ae96bf1bb33cfe27618edc7651750d86b7d84769f09ee6d0
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
base module:      293 bytes
base digest:      e04360ea115d3ba3ae96bf1bb33cfe27618edc7651750d86b7d84769f09ee6d0
consumer module:  514 bytes
consumer digest:  320f6f4305e294773b0c4128e875d3b4bb3fc731886ae64765b2805801fe5246
bundle:           864 bytes
bundle SHA-256:   42dcbdc9eb3a14b1fcb1d86a3b51d33625869a4dbbb789a633f64ae3242765e3
```

The last hash is only an experimental transport fingerprint. It is not a
semantic bundle identity rule. Module digests use the SCB-0 module domain.

## Authority limit

The emitter and structural decoder agree on this bundle. The decoder validates
identity closure, profiles, cycles, module digests, exported imported references,
and both dependency schedules. It does not yet recompute full static types or
resource bounds, so this is not an admitted bundle.
