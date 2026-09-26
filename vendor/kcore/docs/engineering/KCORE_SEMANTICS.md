# KCore — semantics design (M1 draft 1)

Status: **accepted as the M1 implementation baseline** (review disposition
`accepted_m1_step1_with_two_required_corrections`, 2026-09-24; the corrections
are incorporated here and in §9). It implements AR-1 §3 (amendments 2, 3
and 10) and is the specification for `formal/kcore/` in Lean.

## 0. Design principle: exclude, don't model

Every C hazard that KCore can make **unrepresentable** is excluded from the
language instead of modelled. Whatever can't be excluded is given a
semantics in which misuse is `stuck`. Every verified program is then proved
never to be stuck. The C11 table (`KCORE_C11_SUBSET.md`) then needs to cover
only constructs whose C meaning is local and unambiguous.

## 1. Types

```text
Int   ::= u8 | u16 | u32 | u64          -- unsigned only; no signed types exist
Ty    ::= Int | bool | ptr Ty | struct S
S     ::= a closed, non-recursive record of named fields of type Ty
```

- There are **no signed types**, so no signed overflow, sign extension or
  signed shifts.
- There are **no casts between types.** Width changes use the explicit
  operators `zext`, and `trunc`, which is defined as modulo 2^w (§3).
- There are **no unions, function pointers or `void*`.**
- **Target assumptions:** 8-bit bytes, 64-bit `size_t`, and a 32-bit `int`
  and `unsigned int`. Each is asserted exactly in emitted C
  (`KCORE_C11_SUBSET.md` §1); none is inferred from another.

## 2. Values, heap and objects (amendment 2)

```text
Val    ::= int(w, n)  with n < 2^w  | bool(b) | ptr(p) | struct(fields)
Ptr    ::= null | ⟨block, offset⟩             -- provenance = block identity
Block  ::= { ty : Ty, cells : Array Val, state : live | freed }
Heap   ::= finite map BlockId → Block;  BlockIds are never reused
```

| Requirement | KCore rule |
|---|---|
| Allocation | `p := alloc T n` is a **fallible event** (§5). On success it creates a fresh block of `n` cells, each holding the **typed zero value** of `T`: integers `0`, `bool` `false`, structs fieldwise. It also records the block as transaction-owned (§5a), and `p = ⟨b,0⟩`. `n = 0` is stuck. `n·sizeof(T)` overflowing `u64` is stuck. Initialization is semantic, not representational: no all-zero-bits assumption is made about any type. |
| Pointer placement | **Heap cells and serialized values are pointer-free.** A heap element type contains only integers, `bool` and structs of those. **Local variables, including local structs, may hold pointers.** Heap-resident structures refer to each other by **indices or handles** (integers), never by stored pointers. |
| Bounds | A pointer offset `o` is valid iff `0 ≤ o ≤ len`. `load` and `store` require `o < len`. Otherwise stuck. |
| Pointer arithmetic | `p +ₚ k` is stuck if the result leaves `[0, len]`. `null +ₚ k` is stuck. |
| Pointer comparison | `==`/`!=` is allowed on any pointers, including null. `<`/`≤` only within one block; otherwise stuck, as in C. |
| Provenance | A pointer's block never changes. There is no integer↔pointer conversion, so provenance can't be forged or lost. |
| Aliasing / effective type | Each block has one element type, fixed at allocation, and there are no casts. Every access therefore uses the block's own type, and C strict aliasing holds by construction. |
| Alignment | Every block comes from `malloc` (fundamentally aligned). Access is always at the element type. Misalignment is unrepresentable. |
| Byte representation | Integer and struct bytes are **never observable**. There's no `memcpy` of non-`u8` data, no struct↔bytes conversion and no punning. Byte encodings are explicit shifts and masks on integers. Struct padding therefore can't be observed. |
| Initialization | Heap cells hold their typed zero value from allocation. Locals must be definitely assigned before use; this is checked statically, and reads of unassigned locals are rejected at KCore well-formedness. |
| Object lifetime | `free p` requires `p = ⟨b,0⟩` with `b` live, and sets `b` to freed. Any access through a freed block, and any double free, is stuck. Freed ids are never reused, so there's no ABA. |
| Locals | Locals hold values only. **There is no address-of (`&x`)**, so no pointer into the stack exists and stack lifetime never interacts with the heap. |

## 3. Integer operations

- **Checked (default).** `+ - * / %` on `uN` produce the mathematical result.
  If it doesn't fit in `N` bits, or the divisor is 0, the evaluation is stuck.
  The proof obligation is to show no overflow.
- **Wrapping, explicit only.** `wadd`, `wsub` and `wmul` compute modulo 2^N.
  They're needed for hashing.
- **Shifts.** `shl` and `shr` require an amount below N, else stuck. `shl` is
  checked (no set bit may be lost) unless written as `wshl`.
- **Bitwise.** `& | ^ ~` are total.
- **Width changes.** `zext` is total. `trunc` is total and reduces modulo 2^M.
- **Comparisons** produce `bool`.

Both operand types must be identical; there's no implicit conversion.

## 4. Statements and functions

```text
e    ::= x | literal | e op e | not e | zext e | trunc e | e.f | {f := e, …}
s    ::= x := e
       | x := load p | store p e
       | x := p +ₚ e
       | p := alloc T e | free p
       | x := call F(e, …)
       | checkpoint
       | if e then s else s | while e invariant-free do s | s ; s
       | return e
```

- **Expressions are pure.** Memory access, calls, allocation and events are
  statements. C evaluation-order and sequence-point questions therefore don't
  arise (§C11 table).
- **Functions** are first-order, non-recursive (acyclic call graph, checked
  statically), and take and return values by value.
- **Termination.** `while` carries no annotation in the syntax. Termination is
  part of the per-program progress proof (§6, T1).

## 5. Outcomes and the event model (amendments 3 and 10)

Evaluation runs against an **environment**, a pure oracle that answers each
fallible event:

```text
Event   ::= allocEv(bytes) | cancelEv
Env     ::= Nat → Event → Bool          -- the k-th event succeeds or fails
Outcome ::= ok(v, heap, trace)
          | operational(f, trace)       f ∈ { allocationFailed, cancelled }
          | stuck
          | outOfFuel                    -- executable evaluator only; §6
```

- `alloc` asks the environment. On failure, evaluation terminates with
  `operational(allocationFailed)` **after transaction cleanup (§5a)**.
- `checkpoint` asks the environment. On `cancelEv = true`, evaluation
  terminates with `operational(cancelled)` **after transaction cleanup
  (§5a)**.
- **Programs cannot produce `operational` in any other way.** No statement
  returns it, and no statement can catch or inspect a failed event. Failure
  propagation is a language rule, not program code.

Semantic rejections (for example `CheckedCoreInvalid`) are ordinary data
inside `ok(v)`. They are never `operational`.

## 5a. Transaction scope and automatic cleanup (required correction 1)

This is **administrative semantics of KCore**, not a C convention:

- **Ownership.** Every block allocated during an evaluation is owned by the
  current **transaction**. The heap state carries the set `Owned` of
  transaction-owned block ids. `alloc` adds the new id; `free` removes it.
- **On `ok`.** Ownership may leave the transaction **only through the declared
  result.** The entry function declares which result components own blocks,
  and at `ok` the live owned set must equal exactly the blocks reachable from
  those components. That's a per-program proof obligation (T6), so a
  successful run can't leak.
- **On `operational` and `stuck`.** Every live block in `Owned` is released
  by the semantics itself, as part of producing the outcome. No program code
  runs, and none is needed. Outcomes are:

  ```text
  operational(f, trace, heap')   where every b ∈ Owned is freed in heap'
  stuck(heap')                   same release rule
  ```

- **Output.** Nothing public exists before `ok`. The declared result is
  returned only in `ok` (T5).

Consequence for C (`KCORE_C11_SUBSET.md` §4): every operational edge jumps to
one generated epilogue. The epilogue releases every transaction-owned live
block through the named allocation support component, and no public output
is written before `KC_OK`.

## 6. Semantics style and the five theorems

- **Two semantics, proved to agree:**
  - an **inductive big-step relation**, used for proofs;
  - a **fuel-indexed functional evaluator**, used for execution and
    differential testing against the printed C.

  `outOfFuel` exists only in the evaluator, and a lemma states that if the
  relation derives outcome `o`, some fuel yields `o`.
- **The AR-1 amendment 10 theorems split into two kinds:**

  | # | Statement | Kind |
  |---|---|---|
  | T1 | `sufficient(env, P, input) → ∃ v, eval P input env = ok(v)` | per program |
  | T2 | `eval P input env = ok(v) → v = L2(input)` | per program |
  | T3 | `eval P input env = operational(f) → witnessed(f, trace)` | **language-level, proved once** (§5) |
  | T4 | `eval P input env ≠ stuck` for every `env` | per program |
  | T5 | outcome ≠ ok → no output value exists **and** every transaction-owned block is freed | **language-level, proved once** (§5a) |
  | T6 | `eval P input env = ok(v)` → live owned blocks = blocks owned by the declared result | per program (no leak on success) |

- **`sufficient(env, P, input)`:** every event the program issues on that
  input succeeds. The progress theorem T1 therefore also proves termination.
- **Resource accounting:** `allocEv` carries its byte count, so a finite
  budget can be stated as a predicate on the environment. The v0.3 KF-004
  cost semantics lives in L1/L2, not here. KCore resource bounds are
  implementation budgets.
- **Qualification of T5/T6 in C.** M1 injects failure at **every**
  allocation and **every** checkpoint, and checks the emitted C for leaks
  (allocation-support counters plus a leak checker) and for absent output.
  ASan's leak detector is unavailable on macOS arm64, so leak evidence uses
  the support counters and the platform `leaks` tool until the Linux lane
  exists.
- **Honest scope of T5.** Within KCore, a non-`ok` outcome carries no
  result, so there's nothing to publish. Publication itself happens in the
  hand-written C shell (AR-1 §6), which commits only on `ok`. That half is
  TCB and qualified by the WP1 hostile matrix; it isn't proved.

## 7. Program logic (to be decided in M1)

Proving T1, T2 and T4 for real programs needs a verification-condition
generator over KCore statements, plus heap assertions. Options, from
`M1_PRIOR_ART.md`:

- **(a)** A minimal separation-logic layer of our own: points-to over
  blocks, the frame rule, and loop invariants supplied in proofs.
- **(b)** Build on SLean or iris-lean.

M1 measures (a) first because it adds no dependency, and falls back to (b) if
(a) becomes a project of its own. A framework such as SLean or iris-lean is a
**dependency and an audit input, not automatically a TCB component.** Every
theorem that depends on it passes the same axiom audit (`propext`,
`Classical.choice` and `Quot.sound` only), and its exact version is pinned.
Soundness rests on the Lean kernel.

## 8. Explicitly out of KCore (M1)

Signed integers; floats; casts; unions; function pointers; recursion;
source-level address-of; pointers stored in heap cells or serialized values;
variable-length arrays; any library call except through the named support
components (AR-1 §5); I/O; threads; `setjmp`; `goto` (source-level).

## 9. Review record (M1 step 1)

```text
accepted_m1_step1_with_two_required_corrections   2026-09-24

Decisions: M1 restrictions accepted (no recursion, no source-level
address-of, pointers only in locals; heap uses indices/handles). SHA-256 is
implemented in KCore and proved against a Lean functional reference, with
FIPS/NIST vectors as independent qualification. Forward goto only to one
generated failure/cleanup epilogue.

Required corrections, incorporated:
1. Transaction-scoped automatic cleanup (§5a, T5, T6).
2. Checked malloc plus semantic typed-zero initialization instead of calloc
   (§2). calloc may return later only as a refinement proved for the exact
   admitted type.

Additional items, incorporated: success-only, write-once out-parameters
(C11 subset §4/§5); leak-injection tests (§6); exact width assertions
(C11 subset §1); program-logic dependencies audited (§7); SHA-256 against a
Lean functional reference (C11 subset §6).
```

## 10. Implementation record — `formal/kcore` (2026-09-24)

**Implemented and proved** (kernel-checked; permitted axioms only;
`./check-policy.sh` audits 822 KCore constants):

| Item | Lean |
|---|---|
| Syntax (§§1, 4) | `KCore/Syntax.lean` |
| Heap, ownership set, events, outcomes (§§2, 5, 5a) | `KCore/Semantics.lean` |
| Shared atomic step `atomic`; fuel-indexed evaluator `exec`; transaction `run` with release | `KCore/Semantics.lean` |
| Inductive big-step relation `Exec` | `KCore/BigStep.lean` |
| Agreement `Exec_iff_exec`; determinism `Exec.det` | `KCore/BigStep.lean` |
| Fuel monotonicity `exec_mono`, `exec_det` | `KCore/Fuel.lean` |
| **T3** non-fabrication: `exec_fail_witnessed`, `run_operational_witnessed` | `KCore/Theorems.lean` |
| **T5** release: `exec_inv` (ownership invariant), `run_nonok_released` | `KCore/Theorems.lean` |
| Executable qualification (`#guard`), including provenance-forging and heap-smuggling attacks | `KCore/Examples.lean` |

**Soundness gaps found in the first implementation and closed.** Both would
have violated §2:

1. **Pointer literals forged provenance.** A literal `ptr ⟨b,o⟩` could name
   any block. Literals are now restricted to in-range integers, booleans and
   `null` (`Val.isLiteral`).
2. **Pointers could reach the heap inside struct values.** `store` compared
   only the outer type name. It now requires deep conformance of the value to
   the block's element type (`Program.conforms?`), which keeps heap cells
   pointer-free.

Host-supplied integer arguments are also range-checked at `run`.

**Not yet implemented.** Static well-formedness: typing, definite
assignment, the acyclic call graph, and pointer-free heap types at compile
time. Today these are enforced dynamically (misuse is `stuck`). The static
checker, and the proof that well-formed programs never violate them, belong
to the program-logic step.

**Proposed baseline correction KCore-D1 (pending review).** §2 says "`n·sizeof(T)`
overflowing `u64` is stuck", and §5 has `allocEv(bytes)`. KCore can't know
C's `sizeof` for structs, because padding is implementation-defined. In the
emitted C, the checked multiplication in `kc_alloc_T` turns overflow into
`NULL`, which is an allocation failure. The implementation therefore uses
`Event.alloc (type, count)`, and an oversized request is simply an allocation
event the environment may fail. That is exactly what the C does, so the
semantics now models the emitted code rather than an unknowable size. T1's
"sufficient resources" assumption covers it. The text of §2 and §5 should be
amended to match.

## 11. Review record — KCore semantics core (2026-09-24)

```text
accepted_kcore_m1_semantics_core_with_corrections

Exec_iff_exec, T3 and T5 are accepted at their stated claim boundary.
The axiom and source-policy gates pass.

KCore-D1 is accepted only with a target-layout representability obligation.
An unconstrained allocation oracle may not authorize a target-impossible
allocation.

Before general per-program proof tooling, implement KCore-D2:
- typed function/local/result syntax;
- ProgramWF and InputWF;
- exact call typing and definite assignment;
- target-layout validity;
- private input snapshots; and
- the M1 success rule: pointer-free result and empty owned set.

D2 is the next milestone. No VC generator over the untyped syntax.
```

**KCore-D1, as accepted.**

- **`TargetLayoutV1`.** Each target supplies:
  - `sizeOf(T)` and `alignOf(T)`;
  - struct field offsets;
  - `SIZE_MAX`.
- **Representability.** An allocation is admitted only if `0 < count ≤
  SIZE_MAX / sizeOf(T)`. Anything else is **stuck**, not an environment
  decision. A no-stuck proof (T4) therefore proves every reachable
  allocation representable.
- **The C guard stays.** The emitted overflow guard in `kc_alloc_T` remains,
  and is *proved unreachable* on successful admitted executions.
- **Static assertions.** The C target emits `sizeof`, `_Alignof` and
  `offsetof` assertions for every used layout.
- **T1 preconditions:** `ProgramWF`, `InputWF`, `TargetLayoutValid`,
  `AllocationRepresentable`, and successful environment events.

**Private input snapshots.** Input blocks are private snapshots with no
external aliases while a transaction runs. The host shell copies caller
bytes into fresh buffers before the transaction (WP1 ownership rule), so a
store into an input block can never become an externally visible partial
mutation before `ok`. This is a shell (TCB) obligation, and part of the
atomic-publication argument.

**M1 success rule.** A successful entry result is pointer-free, and at `ok`
`heap.owned = []`. No allocation escapes a transaction in M1. A versioned
ownership-transfer result may be added later if production needs it.

## 12. KCore-D2 implementation record (2026-09-24)

| D2 requirement | Implementation |
|---|---|
| Typed parameters, result, locals | `FunDef.params : List (String × Ty)`, `result`, `locals` (`Syntax.lean`) |
| Unique function, struct and variable identities | `Program.wf`: `Nodup` on struct names, function names, and per-function parameters plus locals |
| Exact expression and statement typing | `typeOf`, `typesOf`, `binTy`, `unTy`, `litTy`, `checkStmt` (`WellFormed.lean`) |
| Exact call typing | Static: argument types = parameter types, and the result variable's type = callee result. Dynamic: `Program.argsOk` (arity and deep conformance), plus conformance of the returned value (the `callBadResult` rule). |
| Definite assignment | `checkStmt` threads the definitely assigned set. Every use requires assignment. `ite` joins; a definitely returning branch contributes everything. |
| Definite return | `Stmt.returns`, required of every body by `FunDef.wf` |
| Acyclic call and struct graphs | `acyclic` (repeated sink removal), `callGraphAcyclic`, `structGraphAcyclic` |
| `ProgramWF` | `Program.wf` |
| `InputWF` | `InputWF` = `Program.inputOk`, checked by `run`: input blocks live, of pointer-free type, every cell conforms; arguments conform; every pointer argument, including inside local structs, targets an input block within `[0, len]` with the exact element type |
| Target layout (D1) | `Layout` (`sizeOf`, `alignOf`, `fieldOffsets`, `sizeMax`), `Layout.valid`, `Layout.maxCount`; `Layout.naturalC11` is the C target's claimed layout |
| Representability (D1) | `alloc` with `count = 0 ∨ count > L.maxCount T` is **stuck** |
| M1 success rule | `run` gives `ok` only if the result conforms, the result type is pointer-free, and `heap.owned = []`; otherwise stuck, with release. `Program.entryWf` checks the result type statically. |
| Private input snapshots | stated in §11 as a shell (TCB) obligation |

Every earlier theorem was re-proved over the typed, layout-parameterized
semantics: `Exec_iff_exec`, `Exec.det`, `exec_mono`, T3 and T5. The axiom
audit covers 932 constants. The executable checks include ten static
rejections (type error, use before assignment, missing return, result
mismatch, pointer-bearing allocation, recursion, struct cycle, duplicate
variable, call-argument mismatch, pointer-returning entry) and the dynamic
InputWF, representability and no-escape cases.

**Still open, and belonging to the next step:** the theorem that
`ProgramWF ∧ InputWF ∧ TargetLayoutValid` excludes every typing-related
`stuck` outcome, so that per-program T4 obligations reduce to arithmetic,
bounds and liveness. The static assertions for used layouts are emitted by
the C printer (later).

## 13. Type soundness (2026-09-25)

**Theorem** `run_no_typing_fault` (`formal/kcore/KCore/TypeSoundness.lean`):

```text
P.wf = true  ∧  P.entryWf entry = true  ∧  InputWF P inputs entry args = true
  →  ∀ L env fuel h,  run P L env fuel inputs entry args ≠ .stuck h .typing
```

This holds for every target layout, every environment and every fuel. For a
well-formed program and input, any stuck outcome is therefore an **arith**,
**bounds**, **liveness**, **alloc** or **leak** fault. Those are exactly what
the per-program T4 obligations still have to exclude.

**Supporting results**, all kernel-checked with permitted axioms only (1258
KCore constants audited):

| Result | Meaning |
|---|---|
| `evalBin_sound`, `evalUn_sound` | A well-typed operator on conforming operands yields a conforming value, or fails with a non-typing fault |
| `evalExpr_sound`, `evalExprs_sound` | The same for whole expressions over well-typed locals; results are also pointer-valid |
| `exec_sound` | A well-typed statement, from a well-formed heap and well-typed locals, preserves `HeapOk` (pointer-free, conforming blocks), `HeapExt` (the heap only grows; blocks keep type and length) and `LocalsOk`; returns conforming values; and is never stuck with a typing fault |
| `exec_returns_not_normal` | A definitely returning statement never completes normally |
| `checkStmt_sets` | The definitely assigned set only grows, and stays within the declared variables |
| `load?/store?/ptrAdd?/free?_fault` | On a valid pointer, heap operations fail only with non-typing faults |
| `zeroOf_of_pointerFree`, `zeroOf_conforms` | Every pointer-free type has a conforming typed zero |

**Semantic change made for this result.** `stuck` outcomes, expression
evaluation and heap operations now carry a `Fault` class. Value conformance
is structural on the value, not bounded by a fuel counter. `Exec_iff_exec`,
`Exec.det`, `exec_mono`, T3 and T5 were re-proved. `checkStmt` now uses
`TyEnv.lookup` explicitly; the dot notation had resolved to the equivalent
`List.lookup`.

**Non-vacuity.** The main example program satisfies `P.wf`, `entryWf` and
`InputWF` (executable guards in `Examples.lean`).

## 14. Program logic and first verified program (2026-09-25)

**Program logic** (`formal/kcore/KCore/Logic.lean`). Total-correctness
triples over the inductive semantics:

```text
Valid P L env pre s post  :≡  ∀ m l, pre m l → ∃ r, Exec P L env m l s r ∧ post r
```

Each rule is proved sound once:

- `conseq`;
- `atomic` (the obligation is `post (atomic …)`, discharged by computation);
- `seq`;
- `ite`;
- `while` (invariant plus a strictly decreasing `Nat` measure, so total
  correctness);
- `call` (via the callee's triple);
- `Valid.exec`, which bridges a triple to the evaluator for all large fuel.

Also new: `exec_no_fail_allOk` (`Theorems.lean`). An environment that grants
every event never produces an operational failure. Together with a triple
this gives T1.

**First verified program** (`formal/kcore/KCore/Verified/SumSquares.lean`).
`main n` calls `sumSquares n`, which:

1. allocates an n-cell buffer;
2. fills it with j², with a checkpoint on every iteration;
3. sums it;
4. frees it;
5. returns the sum.

For `0 < n ≤ 2²⁰`:

| Theorem | Statement |
|---|---|
| `main_run` | For **every** environment and all sufficiently large fuel, `run` is either `ok (Σ_{j<n} j²)` or `operational`. It is never stuck and never out of fuel. `ok` implies the M1 success rule, so nothing leaks (T2, T4, T6). |
| `main_run_ok` | Under an environment that grants every event, `run` is `ok (Σ_{j<n} j²)` (T1). |
| `sumSquares_spec`, `main_spec` | The function-level triples. |

The bound `n ≤ 2²⁰` is the program's own precondition: checked arithmetic
must not overflow. `S_fits` and `sq_fits` prove that every intermediate value
fits in u64.

**First cost data point (M1 measurement).**

| Item | Size |
|---|---|
| Program | 2 functions, 18 statements (2 loops, 1 call, 1 alloc/free pair, 1 checkpoint) |
| Program logic (reusable) | 136 lines |
| Program proof | 521 lines, about 29 lines per statement |

- Every atomic obligation is closed by `simp` over the shared `atomic`
  function plus a small per-step lemma.
- Heap reasoning used a program-specific buffer predicate (`Buf`) with direct
  array lemmas. It is not a general separation logic.
- **Open for the rest of M1:**
  - whether multi-buffer programs such as SHA-256 need a frame rule or
    separation assertions;
  - how much of the per-step boilerplate a verification-condition generator
    can remove.

  Both are measured on the SHA-256 slice.

## 15. Verified SHA-256 and the proof kit (2026-09-25)

**Accepted claim (review of 2026-09-25).** The KCore SHA-256
implementation is proved equal to the frozen Lean reference
`KCore.Sha256.sha256`. That reference is qualified independently against
published NIST vectors. Operational allocation failures are witnessed, publish
no result, and leave no transaction-owned allocation live. This is **not** a
formal proof against the FIPS 180-4 prose specification. Where commit
`3c55fee`, its message, or this section say "the FIPS 180-4 reference" or
"the FIPS 180-4 digest", read "the Lean reference" and "its digest".

**Reference** (`formal/kcore/KCore/Verified/Sha256Spec.lean`). FIPS 180-4
over natural numbers: padding, message schedule, 64 rounds, block iteration.
It is checked against the four NIST example vectors by `#guard`. The vectors
qualify the reference; they do not define it. `Sha256Facts.lean` restates the
reference pointwise (padded cell `k`, schedule word `j`) in the form the
proof consumes.

**Program** (`Sha256Impl.lean`). One KCore function
`sha256(msg : ptr u8, len : u64) : Digest`, 221 lines of definitions. It:

1. allocates the padded buffer;
2. copies the message into it, appends `0x80` and the 64-bit big-endian bit
   length;
3. allocates and fills the 64 round constants;
4. allocates the 64-word schedule;
5. runs the block loop, with one cancellation checkpoint per block;
6. frees all three blocks;
7. returns the eight words as a pointer-free struct.

Executable checks run the program through `run`. They cover:

- the four NIST vectors and a 4-block message;
- refusing each event of a successful run in turn (3 allocations plus one
  checkpoint per block). Each refusal yields `operational` with every owned
  block released.

**Theorems** (`Sha256Proof.lean`), for every message of bytes (< 256) with
length < 2⁶⁰:

| Theorem | Statement |
|---|---|
| `sha256_run` | For **every** environment and all sufficiently large fuel, `run` is either `ok (digest of Sha256.sha256 msg)` or `operational`. It is never stuck and never out of fuel; `ok` implies nothing leaked. |
| `sha256_run_ok` | Under an environment that grants every event, `run` is `ok` with that digest (T1). |
| `body_valid` | The function-level triple. |

Axioms: `propext`, `Classical.choice`, `Quot.sound` only (policy audit,
1835 `KCore.*` constants).

**Proof kit** (`KCore/Kit.lean`, 511 lines, reusable):

- `steps` and `Valid.straight`. A straight-line segment is discharged by
  computing its result, not by one assertion per statement.
- `Arr`, an integer-block predicate, with load/store/pointer/alloc/free
  lemmas and frame lemmas for other blocks.
- Per-operator evaluation lemmas whose side conditions go to `omega`
  (`kdisch`).
- The `kstep` symbolic executor.

For SHA-256, a frame rule or separation assertions were **not** needed.
Explicit block ids and one frame equation per operation were enough.

**Cost (second M1 data point).**

| Item | Size / time |
|---|---|
| Program | ~390 atomic statements after expansion (6 loops, 3 allocations, 128 constant stores) |
| Program proof | 791 lines, 9 s to check |
| Reference facts | 126 lines |
| Round-loop body (15 statements, full compression round) | ~40 lines, <1 s |

Per statement this is about 2 lines of proof, against 29 for SumSquares. The
difference comes from the kit, not from simpler code.

**Finding: kernel cost of definitional rewriting (binding rule for proofs).**
When `simp` applies an `rfl` lemma or reduces a `match` definitionally, the
kernel must re-check that step by unfolding. Its unfolding order can reach
the program's checked arithmetic. It then evaluates a product such as
`x * 16777216` in unary. A single 9-statement segment took more than
8 minutes, rising linearly with the literal.

Rules:

- Symbolic execution uses only propositional lemmas (`Eq.trans rfl rfl` or
  tactic proofs), never `rfl` theorems. This covers statement continuations
  (`assignK`, `loadK`, …), `steps`, `bind`, local lookups and width
  constants.
- The discharger never uses `decide` on goals with free variables, for the
  same reason.
- With these rules the same segment checks in 0.16 s.

`decide +kernel` is used only for closed goals: the constant table and the
atomicity of the 140-statement setup list.

**What this means for the VC-generator question.** `kstep` is in effect a
verification-condition generator that runs inside the logic. It produces no
separate trusted artifact. The remaining per-program work is:

- loop invariants;
- the pointwise facts about the reference;
- glue for frame and ownership facts.

A separate VC generator is not needed for M1.

## 16. KCore-D3: target-layout alignment closure (2026-09-25)

Controlled finding **KCORE-M1-TARGET-LAYOUT-ALIGNMENT-CLOSURE-001** (review of
the SHA-256 milestone). `Layout.valid` checked field offsets for alignment,
bounds and overlap. It never required a struct's alignment to accommodate its
fields' alignments. So a struct claiming alignment 1 could hold an
8-byte-aligned field at offset 0 and still pass. It also never checked
pointer-typed fields themselves: an alignment of 0 passed the offset check,
because `0 % 0 = 0`. SHA-256 was not affected: it allocates only scalar
arrays, and its layout is the natural C11 one. But the printer needs
`Layout.valid` as a premise it can rely on.

**Correction (`KCore/WellFormed.lean`).** For every struct, `Layout.valid`
now also requires that every field type has a positive size and alignment,
with its alignment dividing its size, and that the struct's alignment is a
multiple of every field's alignment. The offset, bounds, overlap and size
conditions are unchanged.

**Closure theorem (`KCore/LayoutFacts.lean`).** `Contains P t u` holds when a
value of type `t` contains a field of type `u` by value, directly or through
nested structs. `Layout.valid_contains_align` proves that, under a valid
layout, `alignOf u > 0` and `alignOf u ∣ alignOf t` for every recursively
contained field.

**Hostile layouts (`KCore/Examples.lean`).** Each case below keeps natural,
aligned, in-bounds, non-overlapping offsets. Each is accepted by a test copy
of the pre-D3 predicate and rejected by `Layout.valid`:

| Case | Layout |
|---|---|
| Under-aligned struct | `struct S { u64 }` claiming alignment 1 |
| Nested under-aligned struct | `Outer { Inner }`, where `Inner { u64 }` has alignment 8 and `Outer` claims 4 |
| Valid offsets, invalid aggregate alignment | `{ u32, u64 }` at offsets 0 and 8, size 16, alignment 4 |
| Pointer field with alignment 0 | a pointer-typed field whose type claims alignment 0 |

Flipping any of these assertions makes the build fail.

**Kernel-checkable well-formedness.** Lean compiled `pointerFree` and
`natLayout` as mutual blocks through well-founded recursion. The kernel
cannot evaluate that, so `Program.wf` and `Layout.valid` of a concrete program
could not be settled by `decide`. Both are now plain structural recursion on
the depth, with the field-list part expressed through generic list functions.
Their values are unchanged; type soundness and all program proofs replay.

**M1 binding (`KCore/Verified/Sha256M1.lean`, `formal/kcore/m1-artifact.sh`).**

| Theorem | How it is established |
|---|---|
| `prog_wf`, `prog_entryWf`, `L_valid` | Exact results, by kernel evaluation |
| `L_align_closed` | The alignment closure for this layout |
| `m1_sha256` | One theorem combining the three results above with `sha256_run` and `sha256_run_ok` |

The manifest `formal/kcore/M1_SHA256_ARTIFACT.txt` (since §19
`M1_ARTIFACT.txt`, which binds both M1 units) records:

- the theorem and its axioms;
- the **program identity**: SHA-256 of the canonical text of `prog`
  (`KCore.Encode`, a length-prefixed S-expression format independent of
  Lean's `Repr`);
- the **target-layout identity**: SHA-256 of the canonical text of the layout
  facts the program depends on;
- the **reference identity**: SHA-256 of `Sha256Spec.lean`, plus the constant
  `KCore.Sha256.sha256`;
- the toolchain;
- the SHA-256 of every source the result depends on.

Each identity digest is computed twice, by the Lean reference and by the
system's `shasum`, and the script fails if they differ. This also cross-checks
the reference on a 12.8 KB, multi-block input.

`./m1-artifact.sh --check` replays the manifest, and `check-policy.sh` runs it.
A tampered source fails the replay.

## 17. C11 printer and independent checker (2026-09-25)

Authorized after D3 (review of 2026-09-25): "proceed with the restricted C11
printer and the independent emitted-C structural checker under the existing
AR-1 feasibility claim ceiling".

The printer, support component and checker are recorded in
`KCORE_C11_SUBSET.md` §7. The M1 manifest (`M1_SHA256_ARTIFACT.txt`) now also
binds:

- the printer, checker and support-component sources;
- the emitted files;
- the checker's acceptance, re-run on every replay.

AR-1 §8 still requires, beyond this slice, the M1 vertical slice items
(bounded decoding, a `Step` transition, receipt serialization, zero
publication, the ABI round trip through the hand-written shell) and the
M1 measurements report.

## 18. M1 vertical: public ABI shell over the KCore engine (2026-09-25)

Scope decision (owner, 2026-09-25). Two M1 vertical items stay blocked by the
KF-001..005 adjudication §7 until v0.3, expected within days:

- KCE decoding: KF-002, no wire layout;
- receipt serialization: KF-004, no abstract cost or receipt semantics.

The items that depend on neither proceed now.

**Shell** (`implementation/kcore-c/krisis_shell.c`). The WP1 shell is ported
to drive the emitted KCore program instead of compiled Lean. Everything that
did not touch Lean is unchanged:

- tokens;
- sessions;
- handles;
- sticky cancellation;
- preflight before allocation;
- reservation before the transaction.

The authority-free spike request keeps its WP1 meaning: its receipt is
SHA-256 over the WP1 domain separator followed by the request. The shell
copies `domain || request` into a private snapshot and runs `kc_entry` on it.
KCore's environment hook is wired to the session:

- allocation events consult the test fault-injection counter;
- every engine checkpoint observes the sticky cancellation request.

Shell boundaries 0 and 1, before and after the engine, keep the WP1 test
hooks.

**Zero publication.** A handle is created, and a receipt becomes readable,
only after `kc_entry` returns `KC_OK` and boundary 1 passes. On every other
path the engine has already released every block it owned (KCore T5,
`kc_rt_release_all`, and `kc_rt_dispose` aborts otherwise). The shell then
frees its own reservations and returns with `*out_handle = NULL`. The
unreachable `KC_STUCK` maps to the new detail `KRISIS_OP_INTERNAL_FAULT`,
which also publishes nothing.

**Build** (`CMakeLists.txt`). `krisis_kcore` and `krisis_kcore_testing`
contain only the shell, `kc_rt` and the emitted C:

- The emitted C compiles with exactly the subset flags.
- The hand-written C compiles with the WP1 warning set, including
  `-Wconversion`.
- The library's only external symbols are libc and pthreads (`nm`): no Lean,
  no GMP.

**Qualification.**

- The **unchanged** WP1 ABI suite (`tests/ffi/test_spike.c`) passes against
  the KCore engine, in the dev, AddressSanitizer + UndefinedBehaviorSanitizer
  and ThreadSanitizer profiles. Its expected receipts were computed
  independently with `shasum`, which makes it an end-to-end comparison with
  both an independent SHA-256 and the WP1 Lean behaviour. It covers:
  - receipts and buffer rules;
  - consume and drop;
  - forged, cross-session and retired tokens;
  - cancellation at every boundary;
  - failure of every allocation, shell and engine, in turn;
  - concurrent sessions.
- The C++17 consumer passes.
- `leaks` reports 0 leaks.

Indicative cost, with both engines benchmarked under the same heavy external
load:

| Measure | WP1 Lean | KCore |
|---|---|---|
| Cold start | 6.7 ms | 0.04 ms |
| RSS after initialization | 6.1 MiB | 1.0 MiB |
| 1 KiB request | 154 µs | 37 µs |
| 1 MiB request | 6.6 MiB/s | 37 MiB/s |

**Next (unblocked).** One real semantic `Step` from the frozen reference, in
KCore, proved equal to it, then exposed through this shell with zero
publication on rejection (§19).

## 19. M1 vertical: the state transition `applyRelation` (2026-09-25)

**Scope (owner, 2026-09-25).** The transition is the frozen
`Sak.applyRelation`, not the gated `Step`. `Step`'s dependency closure is
803 definitions / 2 642 lines, of which `Core.wellFormed` is 718 / 2 200,
and it is deferred to v0.3. `applyRelation` is 206 / 346. It is:

`if listSubset r.requires s.facts then some { s with facts := addUnique (eraseAll s.facts r.removes) r.adds } else none`

The frozen reference is a Lake path dependency of `formal/kcore`
(`frozen/v0.2/formal/sak_v0_2`), and only `Sak.Ids` and `Sak.Model` are
built.

**Program** (`KCore/Verified/ApplyImpl.lean`). Facts are flat records
`Fact [u8 tag, u8 sub, u64 a..f, u64 lo, u64 ln]`. A `sharedBorrowed` loan
list is the slice `pool[lo, lo+ln)` of a loan pool. The entry `apply`
proceeds in stages:

1. It validates the four input lists; a non-canonical record gives
   `Res[2, 0]`. Canonical form (`ApplySpec.Canon`): a known constructor and
   case, unused fields zero, and a slice inside the pool, checked without
   overflow.
2. It checks `requires ⊆ facts`; otherwise `Res[1, 0]`.
3. It writes `eraseAll` then `addUnique` into the output block and returns
   `Res[0, k]`.

Fact equality compares the eight fields and the loan lists through the
pool, which is exactly equality of the denoted facts
(`ApplySpec.dec_eq_iff`). Both output loops carry checkpoints.

**Theorems** (`ApplyProof.lean`, bound in `ApplyM1.lean` as `m1_apply` with
`Program.wf`, the entry rule and `Layout.valid`; axioms `propext`,
`Classical.choice`, `Quot.sound`):

- `apply_run` holds for every environment. Status 2 holds iff some record
  is not canonical. Status 1 holds iff the input is canonical and
  `Sak.applyRelation s r = none`. Status 0 with `k` records `go` holds iff
  the input is canonical and `(Sak.applyRelation s r).map (·.facts)` equals
  the decoded `go 0 … go (k-1)`. Otherwise the outcome is operational. Here
  `s` and `r` are any state and relation whose lists the input records
  denote.
- `apply_run_ok`: with every event granted, the run returns a status.

**C** (unit 1, `KCORE_C11_SUBSET.md` §7). The second program exposed two
printer defects that SHA-256 never hit, and both are fixed:

- `if ((a == b))` is diagnosed by clang;
- an unused context in event-free functions.

Fixing them changed the condition form and added `(void)kc_c;`. Unit 0 is
otherwise byte-identical to the previously accepted SHA-256 emission, up to
the unit prefix, and its program and layout identities are unchanged.

**Shell entry** (`include/krisis/krisis_m1.h`, `krisis_m1_apply`,
non-normative). It takes the four lists and the pool as caller-owned
`krisis_m1_fact` records, copied field by field, never by layout punning,
into one private snapshot with a private output region. Then:

- boundary 0 is checked, the engine runs, and boundary 1 is checked;
- the result is copied to the caller's buffer, and `*out_count` is set, only
  after `KC_OK` with status 0 and boundary 1 passed;
- statuses 2 and 1 map to `KRISIS_M1_REJECTED` with detail `NOT_CANONICAL`
  or `NOT_ENABLED`;
- every rejection and operational failure leaves the caller's buffer
  untouched and `*out_count = 0`.

The record format is an M1 carrier only, not a v0.2 wire format (KF-002).

**Qualification.** `kcore-c.sh`, run by `check-policy.sh`, runs the 20 000
frozen-reference vectors end to end through `krisis_m1_apply`, plain and
under ASan + UBSan. It checks:

- identical results;
- zero publication on every rejection;
- zero publication on refusal of every engine event (a testing-only hook,
  `krisis_m1_testing.h`);
- zero publication on cancellation at both shell boundaries;
- zero publication on failure of both shell allocations;
- the argument contract: misuse, preflight, buffer too small, unknown
  session and sticky cancellation.

The WP1 ABI suite still passes against the extended library in dev,
ASan + UBSan and TSan. `nm` shows no Lean or GMP symbol.

**Manifest.** `formal/kcore/M1_ARTIFACT.txt` (format 2) binds both units:

- theorems and per-theorem axioms;
- program and layout identities, each computed twice;
- reference identities: `Sha256Spec.lean`, and the frozen `Sak/Ids.lean`
  and `Sak/Model.lean`;
- every source, the shell and its headers;
- the four emitted files, which the checker must accept.

**Controlled finding KCORE-M1-ENTRY-RESULT-BUFFER-001 (open, for
review).** The failure-epilogue row of §4 in `KCORE_C11_SUBSET.md` states
that no public output ("out-parameters or result buffers") is written on
any path reaching the epilogue. The `apply` entry writes its result records
into its last pointer argument, a caller-supplied block, during loops that
contain checkpoints. A cancellation can therefore reach the epilogue after
partial writes into that block. The out-parameter (`Res`) is written only
on success, so that part of the rule holds.

At the public ABI, zero publication holds and is tested: the block is the
shell's private output region, published only on success. At the
emitted-entry level, the rule as written is not met. Resolutions:

- (a) Scope the rule. The emitted entry's pointer arguments are KCore input
  blocks, which it may modify on any path. Publication is the shell's, which
  gives the engine only private snapshots. This is today's design; it needs
  only a wording change.
- (b) Restructure `apply` to stage its result in a transaction-owned block
  and copy it to the caller's block after the last event. This needs a
  KCore program change and proof rework.

No choice has been made; it awaits review.

**Disposition (review, 2026-09-25): option (b).** The rule is not weakened or
rescoped. No-publication must be compositional at the generated engine
boundary, not a consequence of how a particular shell uses the engine.
The applyRelation proof against the frozen definition was accepted; the
complete vertical was pending this correction.

**Correction.** The program `apply` is now:

1. validation (status 2) and the enabled check (status 1), as before;
2. if `nf + na = 0`, return `Res[0, 0]` (the result is empty, and KCore
   forbids a zero-count allocation);
3. allocate the transaction-owned staging block `st` of `nf + na` records;
4. `eraseAll` then `addUnique` into `st`, with every checkpoint;
5. `commit`: copy `st[0, k)` to the caller's block, a bounded loop with no
   checkpoint, allocation or call;
6. free `st` and return `Res[0, k]`.

The staging allocation needs `nf + na ≤ L.maxCount Fact` =
⌊(2⁶⁴ − 1) / 72⌋ (KCore-D1 representability), now a conjunct of `Inp.Ok`.
It holds for every real caller, whose result block of at least `nf + na`
72-byte records exists in memory. The shell's preflight bound of 2²⁰
records per list implies it.

**Theorems** (`ApplyProof.lean`; bound in `ApplyM1.m1_apply`, axioms
`propext`, `Classical.choice`, `Quot.sound`). For every admitted input and
every environment, with sufficient fuel, `apply_run` gives exactly one of:

- status 2 iff some record is not canonical, with the supplied result block
  exactly unchanged (`h.blocks[5]? = some (outBlock go0)`);
- status 1 iff canonical and `Sak.applyRelation s r = none`, with the result
  block exactly unchanged;
- status 0 with `k ≤ cap`: the result block holds, in `[0, k)`, records
  denoting exactly `(Sak.applyRelation s r).facts` in order, and is
  unchanged in `[k, cap)`; every transaction block is dead;
- an operational outcome, with the result block exactly unchanged,
  nothing owned and every transaction block dead (the semantics'
  `releaseAll` over an owned set that the proof shows is exactly the
  transaction's blocks).

`apply_run_ok` gives a status whenever every event is granted.
`cmLoop_event_free` shows that from every commit state the commit loop ends
normally, never failed or stuck, with the trace, which records every event,
unchanged. So no event occurs after the first write to the result block.
Every failing event occurs before it, and the operational case of
`apply_run` then shows the block untouched. The proof's `EPost` now requires
of every failure outcome what it previously left unconstrained (`True`): the
result block as supplied, and the owned set exactly the transaction's
blocks. The loop invariants carry both, and the staging block is block 6.

**Qualification.** Raw-engine sentinel tests fill the result buffer with
`0xA5` and compare it byte for byte after every non-success outcome:

| Outcome | Cases |
|---|---|
| Invalid input | 1 932 |
| Not enabled | 9 615 |
| Allocation refusals (every one) | 8 362 |
| Checkpoint refusals (every one) | 81 780 |

Each refusal ends with exactly k + 1 events, the status of its kind, and no
owned block left. The same runs pass end to end through `krisis_m1_apply`,
plain and under ASan + UBSan. As a negative control, the pushed engine
(46ffe8c) fails the new raw-engine check ("result buffer written before
failure"). Six checker mutations target the commit discipline: staging into
the caller's buffer, a checkpoint in the commit, a short commit, a missing
free, a free before the commit, and a short staging block. All six are
rejected as not denoting the proved program; 58/58 mutations in total.

**Regenerated.** Unit 1's program identity is now `68a0c10d…` (was
`229ca06a…`); its layout identity and all of unit 0 are unchanged. The
emitted C, the checker verdict, the manifest `M1_ARTIFACT.txt` and the full
matrix are regenerated: the kcore-c lane, the WP1 ABI suite in dev, ASan +
UBSan and TSan, the policy gate and the frozen verification all pass, and
the library has no Lean or GMP symbol.

**Accepted (independent review, 2026-09-25).** The finding
KCORE-M1-ENTRY-RESULT-BUFFER-001 is closed with option (b)
(`accepted_controlled_finding`,
`accepted_kcore_m1_applyrelation_atomic_publication`, commit 28f96e0). The
review verified:

- the supplied result block is exactly preserved on status 1, status 2
  and every operational outcome;
- staging is transaction-owned;
- the commit loop is bounded, event-free, and proved unable to fail or be
  stuck;
- the final free is valid and cannot fail under the staging ownership
  invariant;
- no operational edge occurs after the first external write;
- staging is dead and the owned set is empty on completion and on failure;
- the stronger theorem is bound into `m1_apply`, and the emitted C has the
  staging → commit → free → return topology.

This accepts the applyRelation semantic and atomic-publication slice. It
does not complete M1. KCE decoding, receipt serialization and the full
`Step` must not be invented while v0.3 is unresolved. See `M1_REPORT.md`.
