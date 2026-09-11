# Kernel conditional lowering v0

- Status: experimental; not frozen
- Surface fixture: `spec/language/examples/kernel_if.seki`
- Emitter: `tools/encoding/emit_kernel_if_scb0.mjs`

This fixture closes positive node coverage for the six-element kernel-control
sum. Its `KernelIf` evaluates a Boolean parameter, accepts a `U32` on the true
branch, and rejects the sole declared rejection constructor on the false branch.
It is the positive publication-coupling fixture: the kernel is marked eligible,
the module ceiling includes `publication`, and `publication_equivalence` is a
required theorem. This combination still grants no publication authority.

The checker reconstructs `{steps: 5, live: 98, depth: 4, workspace: 0}`. The
condition is released before either branch. Each branch is checked in the same
`Decision[U32, Rejection]` context and at the same rejection-precedence floor.

The emitted module is 352 bytes and has domain-separated module digest
`7b38e47acef214eddc9f8b583e7d71345bd7b4b063bbb1c296cff0e702ee4a1c`.
