# Kernel conditional lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/kernel_if.seki`
- Emitter: `tools/encoding/emit_kernel_if_scb0.mjs`

This fixture closes positive node coverage for the six-element kernel-control
sum. Its `KernelIf` evaluates a Boolean parameter, accepts a `U32` on the true
branch, and rejects the sole declared rejection constructor on the false branch.

The checker reconstructs `{steps: 5, live: 98, depth: 4, workspace: 0}`. The
condition is released before either branch. Each branch is checked in the same
`Decision[U32, Rejection]` context and at the same rejection-precedence floor.

The emitted module is 354 bytes and has domain-separated module digest
`574928ff49c7d4d082232b9bf3318ed06cb076a441bf86850bfd0ce6fc898360`.
