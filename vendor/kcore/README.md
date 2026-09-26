# Vendored KCore core

KCore is the small verified core that Seki lowers every kernel to (ADR 0023).
It was built by the Krisis project. This directory holds an exact copy of its
core, pinned to one Krisis commit, until KCore is spun off as a separately
versioned product that both projects depend on.

Both projects have the same copyright holder, and both are released under
`GPL-3.0-or-later`.

## What is here

Only the language core, with none of Krisis's own verified programs:

- `formal/kcore/KCore/`: syntax, semantics, well-formedness, the big-step
  relation and its agreement with the evaluator, type soundness, the language
  theorems, target-layout facts, the program logic, the proof kit, the
  canonical encoding, and the C11 subset AST, printer and independent checker;
- `implementation/kcore-c/kc_rt.{c,h}`: the C support component that emitted
  code reaches the C library through;
- `docs/engineering/`: KCore's semantics and C11 subset documents, as reference.

Left behind in Krisis: `KCore/Verified/` (SHA-256, `applyRelation`, and the
frozen SAK reference they are proved against), Krisis's emit drivers and its
C shell.

## Rules

1. **Upstream files are read-only.** Every file listed under `upstream_files`
   in `UPSTREAM.json` is byte-identical to that path at the pinned commit.
   `make check-kcore-vendor` fails otherwise.
2. **A change we need is a numbered patch.** It is recorded in `PATCHES.md`,
   listed in `UPSTREAM.json` with the file's new digest, and committed on its
   own, never mixed with Seki code. At sync time the two sides are then two
   known sets of changes, and every patch is already a candidate for the
   spun-off product.
3. **Seki's glue is listed as local.** `lakefile.toml`, `lake-manifest.json`
   and `Audit/Axioms.lean` are Seki-authored, because upstream's build pulls in
   the SAK reference for Krisis's programs. They are named in `local_files`.
4. **The copy must still check where we build it.** `make check-kcore-vendor`
   also applies KCore's source policy (no `sorry`, `admit`, user axioms,
   `partial` or `unsafe` definitions, `native_decide` or FFI attributes), and,
   when Lean is installed, builds the core and runs the axiom audit over every
   `KCore` constant.

## Claim ceiling, inherited

As of the pinned commit, KCore's own statement: KCore refinement, safety and
progress are proved; emitted C is qualified by the independent checker and by
tests; the printer, the C compiler and libc are trusted.

## Syncing

Krisis is working towards SAK v0.3, which may change KCore. When Seki's end
works, sync once: diff upstream's core at its new commit against the pinned
one, reapply `PATCHES.md`, rebuild, and let the Lean build show exactly which of
Seki's proofs depend on anything that changed. Then update the pin.
