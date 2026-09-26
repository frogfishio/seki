# Spike: the quickstart `gate` kernel lowered to KCore

ADR 0023, order of work step 1. The quickstart kernel
(`docs/alpha/QUICKSTART.md` §2) is lowered to KCore by hand, proved, emitted
through KCore's printer, accepted by KCore's independent checker, and called
from C through a Seki-style header.

This is an experiment. It carries no authority, and its hand-written parts are
exactly what the real lowering has to generate and prove once.

## Run it

```sh
experiments/kcore-gate/run.sh        # check everything below
experiments/kcore-gate/run.sh emit   # regenerate gen/ from the proved program
```

`make check-kcore-gate` runs the first form when Lean is installed.

## What it establishes

| Step | Result |
|---|---|
| Theorem | `SekiSpike.Gate.gate_run`: for **every** admitted request and **every** KCore environment, with enough fuel, `run` returns exactly the encoded Seki decision, with the input heap unchanged, an empty trace and nothing owned |
| Axioms | `propext`, `Classical.choice`, `Quot.sound` only; no `sorry`, `native_decide` or user axiom |
| Emission | `gen/kc_u0.{h,c}` equal a fresh printer run |
| Independent checker | KCore's checker accepts the emitted C as denoting the proved program |
| Compile | emitted C under KCore's subset flags; Seki's adapter and harness under Seki's strict flags |
| Differential | 4,241 vectors whose expected decisions come from the Lean statement of the kernel, not from KCore or the C: every premise boundary, every single-octet account difference, and a pseudo-random sweep. Plain and under AddressSanitizer and UndefinedBehaviorSanitizer |
| Negative controls | changing `18` to `17` in the emitted C: the checker rejects it ("does not denote the proved program"). Reading `premise_tag` from the wrong field in the adapter: the differential test fails on the first affected case |

The theorem is stronger than KCore can state of its programs in general. The
kernel has no allocation and no checkpoint, so no environment can make it fail:
the result is `ok` for every environment, not "`ok` or operational".

## The decision layout: ABI revision 3

```c
typedef struct {
  uint32_t abi_revision;       /* 3 */
  uint32_t disposition;
  uint32_t rejection_tag;
  uint32_t premise_tag;
  uint16_t tiertoolow_limit;   /* every payload field of every case */
  uint16_t tiertoolow_actual;  /* has its own member */
} seki_a0_gate_decision;
_Static_assert(sizeof(seki_a0_gate_decision) == 20, "decision has no padding");
```

KCore has no unions, so the decision is union-free by construction. With the
absence of padding asserted, every byte belongs to a named member, and the
harness compares decisions with `memcmp`. That is what the Grit consumer asked
for and what ABI revision 2 cannot promise.

## Size and cost

| Item | Size |
|---|---|
| Seki kernel body | 6 lines |
| KCore program | about 40 lines |
| Kernel-specific proof (`gate_body`, request and decision conformance, `gate_run`) | about 110 lines |
| Reusable lemmas (octet identity, byte-string conformance, literal and field evaluation, decision construction) | about 150 lines |
| Check time | about 3 s |
| Emitted C | 192 lines + 62-line header; adapter 89 lines + 29-line header |

The kernel-specific ~110 lines are what the lowering theorem must remove. The
reusable ~150 are its first building blocks: they are already stated for any
list of octets, any field index and any rejection.

## Findings

1. **The chain works, and the proof was routine.** A loop-free kernel is
   discharged by symbolic execution: one case split per premise, each branch
   closed by rewriting with precomputed facts about its condition and its
   result. Nothing needed an invariant or a measure. That is the shape a
   generic lowering proof can follow by induction over the kernel's tail form.

2. **Octet identity lowers to a branch-free expression, but the fold must be a
   tree.** `(a0 ^ b0) | … | (a31 ^ b31)` is emitted as a left fold. With the
   casts KCore's promotion rule adds at `u8`, the emitted condition nests
   parentheses 102 levels deep. C11 guarantees only 63 (§5.2.4.1), so this
   kernel already relies on the compiler exceeding the standard's minimum;
   clang does, a conforming compiler need not. The real lowering should fold
   as a balanced tree, depth 5 for 32 octets. This is a Seki lowering choice,
   not a KCore change, and `run.sh` should gain a nesting check once it is
   made.

3. **The Seki-facing adapter is new trusted glue.** KCore structs hold scalars
   only, so `Digest[sha256, 32]` becomes 32 `u8` fields named `f0 … f31`. A
   consumer should see `uint8_t account[32]` and Seki's field names, so an
   adapter copies between the two. KCore's checker does not cover it; the
   differential test does, but only on the inputs it runs. Two ways to close
   it: fixed-length arrays inside KCore structs (a KCore change, to raise at
   the sync), or a checker for the adapter's small, regular shape.

4. **An event-free unit still links the runtime.** The printer always emits the
   failure epilogue, which calls `kc_rt_release_all`, so the kernel links
   `kc_rt.c` and through it `malloc` and `free`. The call is unreachable
   (`gate_run` proves `KC_OK` on every input), but Seki's promise that a kernel
   needs no C library does not survive linking. A candidate KCore patch: omit
   the epilogue for a program with no allocation, call or checkpoint.

5. **Admission is carried by C types here, but will not always be.** The
   theorem requires an admitted request: 32-octet accounts, `age < 256`,
   `tier < 65536`. The C types `uint8_t[32]`, `uint8_t` and `uint16_t`
   guarantee all of it, so the adapter needs no check. A variant field's tag is
   not guaranteed by its C type, so for kernels with variant inputs the adapter
   must check admission and return disposition `0`, as ABI revision 2 does.

6. **The Seki meaning is still hand-transcribed.** `Spec.authorise` is written
   by hand from the Seki source. The real pipeline replaces it with `Seki.eval`
   of the decoded typed core (ADR 0023 step 2), and the theorem then relates
   `lower P` to `Seki.eval P` for every admitted `P`, not one hand-written
   pair.
