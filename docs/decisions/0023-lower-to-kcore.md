# ADR 0023: Lower Seki to KCore instead of emitting C ourselves

- Status: accepted as the project's direction
- Date: 2026-09-26
- Supersedes: the compiler-proof and C-backend parts of `VISION.md` §§3, 8, 9
  and 17 as first written

## Context

Seki has changed course on how the generated C gets its assurance several
times. The alpha emits restricted C from an untrusted C backend, and nothing
proves that C preserves the typed core's meaning. `VISION.md` then planned a
`compile` function defined in Lean, proved correct against a C semantics we
would have to write or borrow, with the working compiler checked against it.
That plan is sound, but it makes Seki carry a C semantics and a C boundary
alone.

Meanwhile Krisis, the implementation of the Semantic Algebra Kernel, could not
wait for Seki and could not have used it: SAK needs loops, a heap, allocation
failure and cancellation, which Seki deliberately excludes. Krisis built KCore
instead (`../krisis`, `docs/engineering/KCORE_SEMANTICS.md`,
`KCORE_C11_SUBSET.md`):

- a small imperative core defined in Lean: unsigned integers, structs, loops,
  first-order non-recursive functions, a heap of pointer-free blocks, and
  allocation failure and cancellation as environment events;
- language-level theorems proved once: evaluator and big-step semantics agree,
  determinism, type soundness, every operational failure is witnessed, and a
  failed run releases everything and publishes nothing;
- per-program Lean proofs of refinement, progress and no-leak, with a reusable
  proof kit;
- a Lean printer to a closed, row-by-row C11 subset, and an independent checker
  that parses the emitted text, rebuilds the program it denotes and compares it
  with the proved program;
- an axiom policy gate that forbids `sorry`, `native_decide`, `partial` and
  user axioms.

Its claim ceiling is: KCore refinement, safety and progress proved; emitted C
qualified by the checker and tests; printer, clang and libc trusted. Its one
expensive part is the per-program proof, at roughly 5 to 10 lines of Lean per
program line, written by a Lean expert.

The two projects are complementary. KCore can express the systems work Seki
excludes, but every program costs a hand-written proof. Seki cannot express that
work, but its kernels are total and bounded by construction, which is exactly
what makes a per-program proof mechanical.

## Decision

Seki lowers its canonical typed core to KCore. It does not maintain a C
semantics or a C boundary of its own.

```text
Seki source ── sekic front end (untrusted) ──► SCB-0 typed core (the authority)
                                                   │
                                   Lean admission: re-checks the core,
                                   trusts nothing sekic produced
                                                   │
      Lean requirement ── policy proof ──►  Seki semantics (pure evaluator)
      (per kernel)                                 │
                                   lower : SekiCore → KCore.Program
                                   proved correct once, for every admitted kernel
                                                   │
                                   KCore program, its KCore obligations
                                   discharged by that one theorem
                                                   │
                                   KCore printer → restricted C11 → KCore checker
                                                   │
                                   Seki decision header and bundle
```

The assurance becomes three pieces instead of two:

| Piece | Scope | Owner |
|---|---|---|
| Policy proof: the kernel satisfies its requirement | per kernel, over Seki semantics | the kernel's project |
| Lowering proof: `lower` preserves Seki semantics into KCore | once | Seki |
| KCore language theorems, printer and checker | once, shared | Krisis |

The per-kernel work that remains is the proof that matters to a customer. It is
stated over a pure evaluator with no heap and no pointers.

## What this gives beyond either project alone

1. **No per-program safety proof for decision kernels.** Termination, progress,
   no-leak and refinement come from the lowering theorem.
2. **Kernels that cannot fail.** Seki kernels have static workspace, so the
   lowering emits no allocation and no cancellation checkpoint. The KCore run is
   then `ok` for every environment, which KCore cannot promise of programs in
   general.
3. **Costs known in advance.** Seki's derived exact step, live-bit,
   control-depth and workspace bounds carry over. KCore has budgets, not stated
   costs.
4. **Authors who do not write Lean.** The kernel author writes Seki; the
   requirement author writes Lean; neither writes KCore.
5. **A consumer contract KCore does not define.** Authored stable rejection
   tags, compile-time rejection precedence, nominal identities, the Boolean
   rule, the decision header and self-verifying bundles.
6. **A cheaper compiler proof.** Seki semantics to KCore semantics is a proof
   between two Lean definitions, not a proof against the C standard.
7. **One C boundary for both projects.** Any future proof of the KCore printer,
   for example against CompCert's Clight semantics, serves Seki as well.
8. **Byte-comparable decisions.** KCore has no unions and statically asserts
   every size, alignment and offset it relies on. A union-free decision layout
   with an asserted absence of padding makes whole-decision `memcmp` sound,
   which the current ABI cannot promise.

## What does not change

- The typed core is the authority, and its digest is the kernel's identity.
- The language surface in `docs/alpha/A0_SCOPE.md` stays fixed. KCore's
  expressiveness is not a reason to widen Seki.
- Independent authorship, falsifiable requirements, borrowed or earned trust,
  and nothing self-certified (`VISION.md` §§5–7).
- What the host-boundary contract guarantees: Seki consumes
  already-authenticated identities and never authenticates anything.
- The alpha keeps serving Grit until the KCore path produces a kernel it can
  integrate. Nothing already delivered is withdrawn before its replacement
  works.

## Costs and constraints accepted

- **Dependency.** The C boundary belongs to Krisis. Seki pins an exact KCore
  revision and follows Krisis's review of it. KCore changes when SAK needs it
  to.
- **Targets.** KCore asserts 8-bit bytes, a 64-bit `size_t` and a 32-bit `int`.
  Targets outside that need a KCore target layout for them.
- **Encodings.** KCore structs hold scalars only and it has no unions and no
  signed integers. `Bytes[N]` and `Digest` become structs of scalar fields;
  payload variants become tag-plus-fields structs; the typed core's signed
  types have no lowering until KCore has one. Each encoding is part of the
  lowering proof.
- **ABI.** The union-free layout is a new decision ABI revision, announced to
  consumers before it ships.
- **Retirement.** `src/alpha/seki_c_backend.c` is retired once the KCore path
  reproduces what consumers integrate against.

## Prerequisites

- **Agreement with Krisis** that Seki may depend on KCore, and how: a pinned
  path or package dependency on the KCore core alone, without Krisis's
  SAK-specific programs and the frozen SAK reference they require.
- **A licence on KCore** compatible with Seki's `GPL-3.0-or-later`. Krisis
  currently carries no licence file.

## Order of work

1. **Hand spike.** Lower the quickstart `gate` kernel to KCore by hand, prove it
   with KCore's proof kit, emit it through KCore's printer and checker, and call
   it through a Seki-style header. This settles the encodings and measures one
   real kernel.
2. **Lean evaluator and admission for any kernel.** Seki semantics must exist in
   Lean for every admitted kernel before anything can be lowered from it. This
   was already first in `VISION.md` §17.
3. **Lowering theorem for a fragment:** field projection, comparison,
   `require`, `reject`, `accept`. Proved once, for every kernel written in the
   fragment.
4. **Extend the fragment** to the whole agreed surface: `let`, conditionals,
   `&&` and `||`, match, record literals, rejection payloads, octet identity.
5. **Adopt KCore's policy gate** for Seki's Lean: no `sorry`, `native_decide`,
   `partial` or user axioms, with every constant audited.
6. **Switch consumers** to the KCore path with the new ABI revision, and retire
   the alpha C backend.

## How this direction would be revisited

The direction is decided; the lowering proof is not yet shown to be
affordable. The test is stated now, so that any later change is a finding and
not a wobble:

- **The direction holds** if, for the step 3 fragment, the lowering theorem is
  proved once and a new kernel written in that fragment needs no KCore proof
  work of its own.
- **The direction is revisited** if the lowering theorem needs per-kernel help
  (invariants, measures or glue written per kernel), because that is KCore's
  per-program cost in disguise and removes the reason for lowering at all.
- **The direction is revisited** if Krisis declines the dependency, in which
  case the same design with a Seki-owned copy of the KCore core is the first
  alternative to weigh, not a return to our own C backend.
