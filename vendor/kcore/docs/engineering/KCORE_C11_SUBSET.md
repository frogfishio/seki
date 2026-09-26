# KCORE_C11_SUBSET — emitted C11 subset and translation table (M1 draft 1)

Status: **accepted as the M1 implementation baseline** (review disposition
`accepted_m1_step1_with_two_required_corrections`, 2026-09-24; corrections
incorporated; see `KCORE_SEMANTICS.md` §9). It defines the only C the printer
may emit, and it is the rule set the independently reviewed emitted-C
validator enforces (AR-1 amendment 12).

## 1. Environment

- **Language:** ISO C11 (`-std=c11 -pedantic`), hosted.
- **Headers:** `<stdint.h>`, `<stdbool.h>`, `<stddef.h>`, `<limits.h>`,
  and `<stdlib.h>` inside the allocation support component only.
- **Every emitted file begins with exact assertions of every width and limit
  the table relies on.** Nothing is inferred from `sizeof(size_t)` alone.

  ```c
  _Static_assert(CHAR_BIT == 8, "8-bit bytes");
  _Static_assert(UINT_MAX == 4294967295u, "32-bit unsigned int");
  _Static_assert(INT_MAX == 2147483647, "32-bit int (promotion rule, sec. 3)");
  _Static_assert(SIZE_MAX == UINT64_MAX, "64-bit size_t");
  _Static_assert(UINT8_MAX == 255u && UINT16_MAX == 65535u, "exact widths");
  _Static_assert(UINT32_MAX == 4294967295u, "exact width");
  _Static_assert(UINT64_MAX == 18446744073709551615u, "exact width");
  ```

  The exact-width types `uintN_t` are required to exist by their use, and
  they have no padding bits by definition (C11 §7.20.1.1).

- **Linkage:** all functions are `static` except the named entry points.

## 2. Types

| KCore | C11 | Note |
|---|---|---|
| `u8` `u16` `u32` `u64` | `uint8_t` `uint16_t` `uint32_t` `uint64_t` | |
| `bool` | `bool` | stored as `_Bool` |
| `ptr T` | `T *` | never `void *`, never cast |
| `struct S` | `struct kc_S { … };` with generated field names | Padding is never observed: no `sizeof` on structs except as the element size passed to the allocation support component, no `memcpy`, no byte access. Heap element structs are pointer-free (KCore §2); local structs may contain pointers. |

## 3. The integer-promotion rule (central)

In C, `uint8_t` and `uint16_t` operands are promoted to **signed `int`**
before arithmetic. `(uint16_t)a * (uint16_t)b` can overflow `int`, which is
undefined behaviour. Therefore:

> Every arithmetic, bitwise and shift operation on `u8`/`u16` operands is
> emitted with both operands first cast to `uint32_t`, and the result cast
> back to the KCore width.

`u32` and `u64` are not promoted, because `int` is exactly 32 bits (asserted
in §1). Their operators are emitted directly.

## 4. Translation table

| KCore construct | Emitted C | Why it is exact |
|---|---|---|
| checked `a + b` (u32/u64) | `a + b` | No overflow is proved. Unsigned `+` equals the mathematical sum when no overflow occurs. |
| checked `a + b` (u8/u16) | `(uintW_t)((uint32_t)a + (uint32_t)b)` | promotion rule §3 |
| `wadd a b` (u32/u64) | `a + b` | C unsigned arithmetic is modulo 2^N by definition |
| `wadd a b` (u8/u16) | `(uintW_t)((uint32_t)a + (uint32_t)b)` | conversion to an unsigned type is modulo 2^N |
| `- * / %` | same pattern as `+` | `/` and `%` have divisor ≠ 0 proved |
| `shl a k`, `shr a k` | `a << k`, `a >> k` (u32/u64); promotion pattern for u8/u16 | `k < N` proved; unsigned shift is exact |
| `& \| ^` | as operators; promotion pattern for u8/u16 | |
| `~a` (u8/u16) | `(uintW_t)~(uint32_t)a` | Without the cast, `~` on a promoted `int` yields a negative `int` |
| `zext a` to W | `(uintW_t)a` | widening an unsigned value is value-preserving |
| `trunc a` to W | `(uintW_t)a` | narrowing to an unsigned type is modulo 2^W |
| comparisons | `a < b` etc. | same types, no promotion hazard: an `int` compare of promoted non-negative values is exact |
| `x := e` | `x = e;` | e is pure, so there is no sequence-point hazard |
| `x := load p` | `x = *p;` | in bounds, live and correctly typed are proved |
| `store p e` | `*p = e;` | same |
| `x := p +ₚ e` | `x = p + e;` | the result is proved within `[0, len]`, and one-past-end is allowed by C11 §6.5.6 |
| `p := alloc T n` | `p = kc_alloc_T(ctx, n); if (p == NULL) goto kc_fail_alloc;` followed by the generated initialization loop `kc_i = 0; while (kc_i < n) { p[kc_i] = KC_ZERO_T; kc_i = kc_i + 1; }` | `kc_alloc_T` is the named allocation support component. It performs **checked** multiplication `n·sizeof(T)` (failure means NULL), calls `malloc`, and registers the block with the transaction (KCore §5a). `KC_ZERO_T` is a generated typed zero: `0` for integers, `false` for `bool`, a fieldwise compound literal for structs. No representation of all-zero bits is assumed. `calloc` may replace this only as a refinement proved for the exact admitted type. |
| `free p` | `kc_free_T(ctx, p);` | `p` proved to be a live block base. The support component unregisters it from the transaction and calls `free`. |
| `checkpoint` | `if (kc_cancel_requested(ctx)) goto kc_fail_cancel;` | named support call (AR-1 §5) |
| `x := call F(args)` | `kc_st = F(ctx, args…, &x); if (kc_st != KC_OK) goto kc_propagate;` | Operational failure propagates exactly as in KCore §5. Arguments are evaluated before the call as separate statements. `kc_st` and the `KC_*` status codes are `uint32_t` (`#define KC_OK UINT32_C(0)`), never a C `enum`, whose type is signed `int`. `&x` is the only address-of the printer emits, and it targets the callee's out-parameter. **Out-parameter rule:** the callee writes `*out` exactly once, on the success path only, immediately before `return KC_OK;`. The caller reads `x` only after checking `kc_st == KC_OK`. |
| `if`/`while`/`;`/`return` | structured `if`/`while`/`{}`/`return` | |
| failure epilogue | exactly one generated failure/cleanup region per function, entered only by forward `goto` from `kc_fail_alloc`, `kc_fail_cancel` and `kc_propagate` | The **only** `goto` use. Non-entry functions just return the status upward. The **transaction entry function's** epilogue calls `kc_release_all(ctx)`, which frees every transaction-owned live block (KCore §5a, T5), and returns the status. **No public output** (out-parameters or result buffers) is written on any path reaching the epilogue. |

## 5. Forbidden in emitted C (validator rejects)

- **Signed integer types and arithmetic,** including plain `char` and `int`
  as operand types. `int` appears only as an implicit promotion guarded by
  §3.
- **Any cast** except the `(uintW_t)` forms listed in §4.
- **Pointer↔integer conversion,** `void *` variables, and casts between
  pointer types.
- **Structs as bytes:** `memcpy`/`memset`/`memcmp` on anything, `sizeof` of a
  struct except as the element size inside the allocation support component
  `kc_alloc_T`, and unions.
- **Evaluation-order hazards:** any expression with more than one side
  effect; function calls inside expressions other than the §4 call form;
  `++`/`--`; the comma operator; compound assignment.
- **Unchecked pointer arithmetic:** the validator can't check bounds, so it
  accepts pointer arithmetic only in the `x = p + e;` statement form. The
  bounds proof lives in KCore (T4). The validator enforces shape; KCore
  proves meaning.
- **Library calls** other than through the named support components. The
  validator rejects direct `malloc`, `calloc`, `free` and `memcpy` in emitted
  code.
- **Out-parameter violations:** any write to an out-parameter other than the
  single success-path write immediately before `return KC_OK;`, any write on
  a path reaching the failure epilogue, and any read of a call result before
  its status check.
- **`goto` violations:** any `goto` other than a forward jump to the
  function's single failure/cleanup region.
- **Also:** backward `goto`, `setjmp`, variadics, VLAs, recursion, function
  pointers, `volatile`, floats, and any `#pragma` or compiler extension.

## 6. Open points for review

1. **Named support components (decided).** `kc_cancel_requested`,
   `kc_alloc_T`, `kc_free_T` and `kc_release_all`, which form the
   transaction allocation registry. SHA-256 is **KCore code**, proved against
   a Lean functional reference; the FIPS 180-4 / NIST vectors are independent
   qualification (AR-1 §8, item 2).
2. **The `goto` epilogue pattern (decided).** Forward edges only, into one
   generated failure/cleanup region per function.
3. **Emitted-C compiler flags** are part of the TCB statement. The build uses
   only diagnostic and standard-selection flags: `-std=c11 -pedantic -Wall
   -Wextra -Werror` plus optimization level. **No flag that changes C
   semantics is used** (for example `-fwrapv`, `-fno-strict-aliasing`,
   `-fno-strict-overflow`). Every emitted construct must mean the same under
   plain ISO C11, so the table never depends on a dialect.

## 7. Implementation record: printer, support component and checker (2026-09-25)

The printer, the support component and the independent checker are
implemented. The SHA-256 program is emitted, checked, compiled and
qualified. `./kcore-c.sh` runs the lane and `check-policy.sh` includes it.

| Component | Location | Trust status |
|---|---|---|
| Typed subset AST | `formal/kcore/KCore/C11/Ast.lean` | one constructor per §4 row |
| Printer (lowering + rendering) | `formal/kcore/KCore/C11/Print.lean` | trusted boundary (AR-1 §4(b)); not proved |
| Independent checker | `formal/kcore/KCore/C11/Check.lean` | reviewed; imports nothing from the printer |
| Support component | `implementation/kcore-c/kc_rt.{h,c}` | hand-written, reviewed, trusted |
| Emitted units | `implementation/kcore-c/gen/kc_u<n>.{h,c}`: unit 0 SHA-256, unit 1 `apply` (applyRelation) | must be reproducible and accepted by the checker |

### 7.1 Emitted form (additions to §4)

- **Closed naming.** No KCore name reaches the emitted text.

  | Entity | Emitted name |
  |---|---|
  | Parameters and locals | `v<i>` (parameters first) |
  | Structs and their fields | `kc_u<n>_s<i>`, fields `f<j>` |
  | Functions | `kc_u<n>_f<i>` (`static`); the entry is `kc_u<n>_entry` |
  | Allocation components | `kc_u<n>_alloc_<code>` |
  | Files and include guard | `kc_u<n>.h`, `kc_u<n>.c`, `KC_U<n>_H` |
  | Fixed support names | `kc_c` (context), `kc_out`, `kc_st`, `kc_n`, `kc_i` |

  `n` is the unit number the program is emitted as, so that several
  programs link into one library. The checker is told the unit and accepts
  only that unit's names. The entry may not be called internally.
- **Every expression is fully parenthesized:**

  | Form | Emitted as |
  |---|---|
  | u32/u64 operators | `(a OP b)` |
  | u8/u16 operators (promotion pattern) | `((uintW_t)((uint32_t)(a) OP (uint32_t)(b)))` |
  | Complement, u32/u64 | `(~a)` |
  | Complement, u8/u16 | `((uintW_t)(~(uint32_t)(a)))` |
  | Conversions (both `zext` and `trunc`) | `((uintW_t)a)` |
  | Field access | `(e).f<j>` |
  | Struct values | `((struct kc_s<i>){ .f0 = …, … })` |
  | Literals | `UINTW_C(n)`, `true`, `false`, `NULL` |

- **Conditions.** `if` and `while` take a relational or logical condition
  as `if (a OP b)`: the statement's parentheses are the operator's own.
  Doubling them around `==` would be diagnosed by clang
  (`-Wparentheses-equality`). Every other condition is `if (e)`. The
  checker accepts exactly one form per condition.
- **Context use.** Every function begins, after its locals and support
  variables, with `(void)kc_c;`. A function without events or calls does not
  otherwise use the context (`-Wunused-parameter`).
- **Allocation** first evaluates the count into `kc_n`, so the count
  expression is evaluated once, before the target is assigned (KCore order).
  Then: `x = kc_alloc_<code>(kc_c, kc_n); if (x == NULL) goto kc_fail_alloc;`
  and the typed-zero loop over `kc_i`. Each allocation component is the
  one-line template `return kc_rt_alloc(kc_c, kc_n, sizeof(T));`.
- **Locals are initialized to their typed zero.** This is defensive only:
  definite assignment is proved in KCore, so the initializer is never
  observed.
- **The function tail.** After the body comes `kc_st = KC_STUCK; goto
  kc_fail;`, the defensive fall-off-the-end path (unreachable for verified
  programs). Then the epilogue: only the failure labels the body uses, then
  `kc_fail:`, which calls `kc_rt_release_all` in the entry, then
  `return kc_st;`.
- **Layout.** Every fact of the target layout's canonical text is asserted
  with `_Static_assert` (`sizeof`, `_Alignof`, `offsetof`), so a compiler
  that disagrees fails the build.
- **Flags.** The emitted file compiles warning-free under exactly
  `-std=c11 -pedantic -Wall -Wextra -Werror`. No warning is suppressed, and
  no flag changes semantics.

### 7.2 Support component and the event model

`kc_ctx.decide(user, k, event, count)` is KCore's `Env`: event `k` is the
k-th allocation or checkpoint of the transaction, and returning false refuses
it. `NULL` grants every event. A granted allocation that `malloc` cannot
satisfy is observably the same as a refusal. `kc_rt_free` aborts on a block
the transaction does not own (excluded by T4). `kc_rt_release_all` frees
every block still owned.

### 7.3 Independent checker

The checker reads the two files as text, with its own lexer and grammar.
There is no rule for any construct outside this document, so everything
listed in §5 is rejected by construction.

**Typed parsing.** It type-checks while it parses: plain operators only at
u32/u64, the promotion pattern only at exactly the operands' u8/u16 width,
and `NULL` only where the context fixes a pointer type.

**Comparison.** It rebuilds the KCore program the text denotes and compares
its canonical encoding with `normalize (erase (anon P))` of the proved
program `P`:

| Step | Effect |
|---|---|
| `anon` | the closed naming |
| `erase` | checked ≡ wrapping operators, `zext` ≡ `trunc`: same C text, same value on every non-stuck run |
| `normalize` | `seq` re-association, which C flattens |

It also compares the asserted layout facts with the target layout, and it
refuses a program or layout that is not well-formed or valid.

**Soundness argument (reviewed, not proved).** If the check passes, the text
means, row by row of §4, the rebuilt program. That program equals
`normalize (erase (anon P))`, which behaves as `P` on every run on which `P`
is not stuck, which is every run (T4).

**Lexer fidelity.** The lexer follows C's translation phases where they
could make the checker and the compiler read different tokens:

| C behaviour | Checker rule |
|---|---|
| A comment becomes one space | the same, so `a/**/b` is two tokens |
| A `/*` inside a string literal starts no comment | the same |
| A leading `0` means octal | only the constant `0` may start with `0`, so `010` is rejected rather than misread as 10 |
| Hex constants, uppercase suffixes, line comments, backslashes, trigraphs and non-ASCII characters | rejected |

Each rule has a mutation test. The octal and comment rules were found in
self-review before the first commit.

**Known incompleteness (rejects, never accepts wrongly):** `NULL` in a
position without an expected pointer type, for example the left operand of
`==`.

### 7.4 Qualification

- **Reproducible emission.** The committed files equal a fresh printer run.
- **Checker.** Accepts the emitted files.
- **Mutations.** 58 mutations of the emitted files must all be rejected
  (`tests/kcore-c/checker_mutations.py`). On unit 0 they cover constants,
  operators, signed and unsigned-int casts, raw `malloc`, extra includes,
  comments, labels, release, layout, widths, the promotion hazard,
  pointer-arithmetic order, duplicated and dropped statements, typed zeros,
  free order, header changes, `+=`, `++`, new labels, the lexer traps above,
  a doubly parenthesized condition and a missing context use. On unit 1
  they cover the canonical-form bounds, the loan-slice check, the erase and
  add conditions, status codes, argument order, a skipped field, a dropped
  checkpoint, both condition forms, and names, entry and include guard of
  another unit, and the commit discipline (staging into the caller's buffer,
  a checkpoint in the commit, a short commit, a missing or early free, a
  short staging block). The apply unit renamed as unit 0 is also rejected. Every
  semantic mutation is rejected as "does not denote the proved program".
- **Unit 1 (`apply`).** Differential vectors come from
  `Audit/ApplyVectors.lean`: 20 000 cases whose expected results are
  computed from the frozen `Sak.applyRelation` on the decoded input, not
  from KCore. There are 8 453 applied, 9 615 not enabled and 1 932 with a
  non-canonical record. Each case checks the status, the count and every
  output key, with loans read through the pool. For rejections it checks
  that the sentinel-filled output buffer is byte-identical. It then refuses
  every event of the run in turn: 8 362 allocation refusals, expecting
  `KC_ALLOCATION_FAILED`, and 81 780 checkpoint refusals, expecting
  `KC_CANCELLED`. Each ends after exactly k + 1 events, with nothing owned
  and the output buffer byte-identical. The same vectors run end to end through
  `krisis_m1_apply`; see `KCORE_SEMANTICS.md` §19. Both run plain and under
  ASan + UBSan.
- **Unit 0 tests.** NIST vectors and refusal of every event of each run: exact
  status, nothing owned, no output written. These run both plain and under
  AddressSanitizer + UndefinedBehaviorSanitizer.
- **Differential test.** Matches `shasum` on 15 lengths across every padding
  boundary, up to 1 MB. `leaks` reports 0 leaks.
- **Size.** SHA-256: 365 lines of C plus a 22-line header, for a 221-line
  KCore program. `apply`: 349 lines plus a 29-line header.
- **Speed.** About 176 MiB/s on an unloaded machine (64 MiB, `-O2`), against
  28 MiB/s for the WP1 compiled-Lean baseline and about 230 MiB/s for
  `shasum`. It is informational, not gated: under heavy external load it
  measured 42–50 MiB/s.

Claim ceiling (AR-1 §4a):

| Level | Status |
|---|---|
| KCore/L2 refinement, safety and progress | proved |
| Emitted C conformance | qualified: checker, mutations, tests |
| Native artifact | trusted: clang and libc |
