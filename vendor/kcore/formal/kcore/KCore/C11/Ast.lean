/-
Typed AST of the emitted C11 subset (AR-1 amendment 12,
docs/engineering/KCORE_C11_SUBSET.md).

Every constructor is one row of the translation table and renders to exactly
one fixed C form. The printer builds this AST and renders only this AST: it
never concatenates source fragments, and every identifier comes from the
closed naming scheme below. No KCore name reaches the emitted text.

Naming scheme (closed). Every program-scope name carries the prefix
`kc_u<n>_` of the unit number `n` the program is emitted as, so that several
programs link into one library; the files are `kc_u<n>.h` and `kc_u<n>.c`
with include guard `KC_U<n>_H`:
  * `v<i>`        parameter or local number `i` of the function (params first);
  * `kc_u<n>_s<i>`  struct number `i` of the program, fields `f<j>`;
  * `kc_u<n>_f<i>`  function number `i` (static), except the entry,
                  `kc_u<n>_entry`;
  * `kc_u<n>_alloc_<code>`  the per-element-type allocation component;
  * `kc_c`, `kc_out`, `kc_st`, `kc_n`, `kc_i`  context, out-parameter,
                  status, allocation count and initialization index.
-/
import KCore.Syntax

namespace KCore.C11

/-- C types of the subset. -/
inductive CTy where
  | int (w : IntTy)
  | bool
  | ptr (t : CTy)
  | struct (i : Nat)
deriving DecidableEq, Repr

/-- Generated variable names. -/
inductive CVar where
  | v (i : Nat)
  | out
  | st
  | n
  | i
deriving DecidableEq, Repr

/-- Arithmetic, bitwise and shift operators (the result has the operand width). -/
inductive CArith where
  | add | sub | mul | div | mod | band | bor | bxor | shl | shr
deriving DecidableEq, Repr

/-- Comparison and logical operators (the result is `bool`). -/
inductive CRel where
  | eq | ne | lt | le | land | lor
deriving DecidableEq, Repr

inductive CExpr where
  | var (x : CVar)
  /-- `UINTW_C(n)` -/
  | intLit (w : IntTy) (n : Nat)
  | boolLit (b : Bool)
  /-- `NULL` -/
  | null
  /-- `(a OP b)`, operands of width u32 or u64. -/
  | wide (op : CArith) (a b : CExpr)
  /-- `((uintW_t)((uint32_t)(a) OP (uint32_t)(b)))`, operands of width u8/u16. -/
  | narrow (w : IntTy) (op : CArith) (a b : CExpr)
  /-- `(a OP b)` for comparisons and `&&`/`||`. -/
  | rel (op : CRel) (a b : CExpr)
  /-- `(!a)` -/
  | lnot (a : CExpr)
  /-- `(~a)` at u32/u64. -/
  | complWide (a : CExpr)
  /-- `((uintW_t)(~(uint32_t)(a)))` at u8/u16. -/
  | complNarrow (w : IntTy) (a : CExpr)
  /-- `((uintW_t)a)`: value-preserving widening or modular narrowing. -/
  | conv (w : IntTy) (a : CExpr)
  /-- `(e).f<i>` -/
  | field (e : CExpr) (i : Nat)
  /-- `((struct kc_u<n>_s<s>){ .f0 = e0, … })` -/
  | compound (s : Nat) (es : List CExpr)
deriving Repr

/-- Element-type code used in `kc_u<n>_alloc_<code>` (closed scheme). -/
def CTy.code : CTy → String
  | .int .u8 => "u8" | .int .u16 => "u16" | .int .u32 => "u32" | .int .u64 => "u64"
  | .bool => "b"
  | .ptr t => "p" ++ t.code
  | .struct i => s!"s{i}"

inductive CStmt where
  /-- `;` -/
  | empty
  /-- `x = e;` -/
  | assign (x : CVar) (e : CExpr)
  /-- `x = *(p);` -/
  | load (x : CVar) (p : CExpr)
  /-- `*(p) = e;` -/
  | store (p e : CExpr)
  /-- `x = (p) + (k);` -/
  | ptrAdd (x : CVar) (p k : CExpr)
  /-- `kc_n = c; x = kc_u<n>_alloc_<t>(kc_c, kc_n); if (x == NULL) goto kc_fail_alloc;`
      then the typed-zero initialization loop over `kc_i`. -/
  | alloc (x : CVar) (t : CTy) (c : CExpr) (zero : CExpr)
  /-- `kc_rt_free(kc_c, p);` -/
  | free (p : CExpr)
  /-- `if (kc_rt_cancelled(kc_c)) goto kc_fail_cancel;` -/
  | checkpoint
  /-- `kc_st = kc_u<n>_f<f>(kc_c, args…, &x); if (kc_st != KC_OK) goto kc_propagate;` -/
  | call (x : CVar) (f : Nat) (args : List CExpr)
  /-- `*kc_out = e; return KC_OK;` -/
  | ret (e : CExpr)
  | ite (c : CExpr) (a b : List CStmt)
  | while (c : CExpr) (body : List CStmt)
deriving Repr

structure CFun where
  idx : Nat
  entry : Bool
  params : List CTy
  locals : List CTy
  result : CTy
  body : List CStmt
deriving Repr

/-- One layout fact asserted in the emitted file. -/
inductive CAssert where
  | sizeOf (t : CTy) (n : Nat)
  | alignOf (t : CTy) (n : Nat)
  | offsetOf (s : Nat) (field : Nat) (n : Nat)
deriving Repr

structure CUnit where
  structs : List (List CTy)
  asserts : List CAssert
  allocTypes : List CTy
  funs : List CFun
  /-- Index of the entry function. -/
  entry : Nat
deriving Repr

end KCore.C11
