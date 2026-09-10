# Contributing to Seki

Seki welcomes design feedback, formalization work, implementation work, tests,
and consumer use cases.

## Current project boundary

Global F0 is open. Scaffolding, toolchain qualification, experiments, and
charter review may proceed, but contributions must not claim that F1 has
started or that implementation, proof, native-binary, product, or production
authority has been granted.

Run these checks before submitting a change:

```sh
./SEKI_V0_3_PROJECT_SEED/VERIFY.sh
node tools/check_project_status.mjs
```

## Design discipline

- Keep the language core independent of Gnosis, Kiku, and other customers.
- Treat the canonical serialized typed core as the future semantic authority
  root; surface syntax is a developer interface.
- State proof scope and trusted premises explicitly.
- Prefer small, reviewable changes with hostile and boundary cases.
- Record decisions that alter semantics, proof boundaries, wire formats,
  dependencies, or qualification claims under `docs/decisions/`.

Contributions are accepted under GPL-3.0-or-later. By contributing, you confirm
that you have the right to submit the work under that license.

