/-
Executable checks of the KCore evaluator and well-formedness checker.
Qualification only; the language theorems are in KCore/Theorems.lean and
KCore/BigStep.lean.
-/
import KCore.WellFormed

namespace KCore.Examples
open KCore

def u64 (n : Nat) : Expr := .lit (.int .u64 n)
def v (x : String) : Expr := .var x
def seqs : List Stmt → Stmt
  | [] => .skip
  | [s] => s
  | s :: ss => .seq s (seqs ss)

def U64 : Ty := .int .u64
def U8 : Ty := .int .u8

/-- Allocate `n` u64 cells, store i*i into cell i, then sum them and free. -/
def sumSquares : FunDef :=
  { name := "sumSquares", params := [("n", U64)], result := U64,
    locals := [("buf", .ptr U64), ("i", U64), ("p", .ptr U64), ("acc", U64), ("x", U64)],
    body := seqs [
      .alloc "buf" U64 (v "n"),
      .assign "i" (u64 0),
      .while (.bin .lt (v "i") (v "n")) (seqs [
        .ptrAdd "p" (v "buf") (v "i"),
        .store (v "p") (.bin .mul (v "i") (v "i")),
        .checkpoint,
        .assign "i" (.bin .add (v "i") (u64 1))]),
      .assign "i" (u64 0),
      .assign "acc" (u64 0),
      .while (.bin .lt (v "i") (v "n")) (seqs [
        .ptrAdd "p" (v "buf") (v "i"),
        .load "x" (v "p"),
        .assign "acc" (.bin .add (v "acc") (v "x")),
        .assign "i" (.bin .add (v "i") (u64 1))]),
      .free (v "buf"),
      .ret (v "acc")] }

def caller : FunDef :=
  { name := "main", params := [("n", U64)], result := U64, locals := [("r", U64)],
    body := seqs [.call "r" "sumSquares" [v "n"], .ret (v "r")] }

def prog : Program := { structs := [], funs := [sumSquares, caller] }
def L (P : Program) : Layout := Layout.naturalC11 P

def allOk : Env := fun _ _ => true
/-- Fail exactly the k-th event. -/
def failAt (k : Nat) : Env := fun i _ => i != k

def okU64? : Outcome → Option Nat
  | .ok (.int .u64 n) _ _ => some n
  | _ => none
def isOperational (f : Failure) : Outcome → Bool
  | .operational g _ _ => g == f
  | _ => false
def isStuck : Outcome → Bool
  | .stuck _ _ => true
  | _ => false
def stuckWith (f : Fault) : Outcome → Bool
  | .stuck _ g => g == f
  | _ => false

/-- True iff no transaction-allocated block (id ≥ `init`) is live. -/
def noTransactionBlockLive (init : Nat) : Outcome → Bool
  | .ok _ h _ | .operational _ h _ | .stuck h _ =>
      (List.range h.blocks.size).all (fun i => i < init || (h.blocks[i]?).all (fun b => !b.live))
  | .outOfFuel => true

def runMain (env : Env) (n : Nat) : Outcome :=
  run prog (L prog) env 10000 #[] "main" [.int .u64 n]

/-! ### Well-formedness and layout of the main example -/
#guard prog.wf
#guard prog.entryWf "main"
#guard (L prog).valid prog

-- Non-vacuity of `run_no_typing_fault`: its three hypotheses hold here.
#guard InputWF prog #[] "main" [.int .u64 5]

/-! ### Execution -/
-- 0² + 1² + … + 4² = 30
#guard okU64? (runMain allOk 5) == some 30
#guard noTransactionBlockLive 0 (runMain allOk 5)
#guard isOperational .allocationFailed (runMain (failAt 0) 5)
#guard isOperational .cancelled (runMain (failAt 3) 5)
#guard noTransactionBlockLive 0 (runMain (failAt 3) 5)

def one (name : String) (params : List (String × Ty)) (result : Ty)
    (locals : List (String × Ty)) (body : Stmt) : Program :=
  { structs := [], funs := [{ name, params, result, locals, body }] }

-- Checked overflow is stuck; wrapping is total.
#guard stuckWith .arith (run (one "f" [] U64 [] (.ret (.bin .add (u64 (2^64 - 1)) (u64 1))))
  (L prog) allOk 100 #[] "f" [])
#guard (match run (one "f" [] U64 [] (.ret (.bin .wadd (u64 (2^64 - 1)) (u64 1))))
  (L prog) allOk 100 #[] "f" [] with | .ok (.int .u64 0) _ _ => true | _ => false)

/-! ### Misuse is stuck (dynamic) -/
def oob := one "f" [] U64 [("b", .ptr U8), ("p", .ptr U8)] (seqs [
  .alloc "b" U8 (u64 4), .ptrAdd "p" (v "b") (u64 5), .ret (u64 0)])
def doubleFree := one "f" [] U64 [("b", .ptr U8)] (seqs [
  .alloc "b" U8 (u64 4), .free (v "b"), .free (v "b"), .ret (u64 0)])
def freeInput := one "f" [("in", .ptr U8)] U64 [] (seqs [.free (v "in"), .ret (u64 0)])
def inputBlock : Array Block := #[{ ty := U8, cells := #[.int .u8 7], live := true }]

#guard stuckWith .bounds (run oob (L oob) allOk 100 #[] "f" [])
#guard noTransactionBlockLive 0 (run oob (L oob) allOk 100 #[] "f" [])
#guard stuckWith .liveness (run doubleFree (L doubleFree) allOk 100 #[] "f" [])
#guard stuckWith .liveness (run freeInput (L freeInput) allOk 100 inputBlock "f" [.ptr U8 (.loc 0 0)])

/-! ### Provenance, heap pointer-freedom, input validity -/
def forge := one "f" [("in", .ptr U8)] U8 [("x", U8)] (seqs [
  .load "x" (.lit (.ptr U8 (.loc 0 0))), .ret (v "x")])
def honest := one "f" [("in", .ptr U8)] U8 [("x", U8)] (seqs [.load "x" (v "in"), .ret (v "x")])
#guard stuckWith .typing (run forge (L forge) allOk 100 inputBlock "f" [.ptr U8 (.loc 0 0)])
#guard !forge.wf                          -- also rejected statically
#guard (match run honest (L honest) allOk 100 inputBlock "f" [.ptr U8 (.loc 0 0)] with
  | .ok (.int .u8 7) _ _ => true | _ => false)
#guard honest.wf
-- InputWF: pointer argument past the end of its block is rejected.
#guard isStuck (run honest (L honest) allOk 100 inputBlock "f" [.ptr U8 (.loc 0 2)])
-- InputWF: pointer argument of the wrong element type is rejected.
#guard isStuck (run honest (L honest) allOk 100 inputBlock "f" [.ptr U64 (.loc 0 0)])
-- InputWF: an input cell that does not conform to its block type is rejected.
#guard isStuck (run honest (L honest) allOk 100
  #[{ ty := U8, cells := #[.int .u8 300], live := true }] "f" [.ptr U8 (.loc 0 0)])

def pairDef : StructDef := { name := "Pair", fields := [U64, U64] }
def smuggle : Program := { structs := [pairDef], funs := [
  { name := "f", params := [], result := U64, locals := [("b", .ptr (.struct "Pair"))],
    body := seqs [.alloc "b" (.struct "Pair") (u64 1),
      .store (v "b") (.mk "Pair" [u64 1, v "b"]), .ret (u64 0)] }] }
def pairOk : Program := { structs := [pairDef], funs := [
  { name := "f", params := [], result := U64,
    locals := [("b", .ptr (.struct "Pair")), ("p", .struct "Pair")],
    body := seqs [.alloc "b" (.struct "Pair") (u64 1),
      .store (v "b") (.mk "Pair" [u64 1, u64 2]), .load "p" (v "b"),
      .free (v "b"), .ret (.field (v "p") 1)] }] }
#guard stuckWith .typing (run smuggle (L smuggle) allOk 100 #[] "f" [])
#guard !smuggle.wf                        -- also rejected statically
#guard okU64? (run pairOk (L pairOk) allOk 100 #[] "f" []) == some 2
#guard pairOk.wf

/-! ### M1 success rule: no allocation escapes -/
def leak := one "f" [] U64 [("b", .ptr U8)] (seqs [.alloc "b" U8 (u64 1), .ret (u64 0)])
#guard leak.wf                            -- well-typed, but …
#guard stuckWith .leak (run leak (L leak) allOk 100 #[] "f" [])   -- … leaking is not `ok`
#guard noTransactionBlockLive 0 (run leak (L leak) allOk 100 #[] "f" [])

/-! ### Representability (KCore-D1) -/
-- u64 elements: SIZE_MAX / 8 is the largest representable count.
#guard (L prog).maxCount U64 == (2^64 - 1) / 8
def huge := one "f" [] U64 [("b", .ptr U64)] (seqs [
  .alloc "b" U64 (u64 ((2^64 - 1) / 8 + 1)), .free (v "b"), .ret (u64 0)])
#guard stuckWith .alloc (run huge (L huge) allOk 100 #[] "f" [])

/-! ### Static rejection (ProgramWF) -/
-- type error: u8 + u64
#guard !(one "f" [] U64 [] (.ret (.bin .add (.lit (.int .u8 1)) (u64 1)))).wf
-- use before assignment
#guard !(one "f" [] U64 [("x", U64)] (.ret (v "x"))).wf
-- missing return on a path
#guard !(one "f" [("c", .bool)] U64 [] (.ite (v "c") (.ret (u64 1)) .skip)).wf
-- result type mismatch
#guard !(one "f" [] .bool [] (.ret (u64 1))).wf
-- allocation of a pointer-bearing element type
#guard !(one "f" [] U64 [("b", .ptr (.ptr U8))] (seqs [
  .alloc "b" (.ptr U8) (u64 1), .ret (u64 0)])).wf
-- recursion (call-graph cycle)
#guard !({ structs := [], funs := [
  { name := "f", params := [], result := U64, locals := [("r", U64)],
    body := seqs [.call "r" "f" [], .ret (v "r")] }] } : Program).wf
-- by-value struct cycle
#guard !({ structs := [{ name := "A", fields := [.struct "A"] }], funs := [] } : Program).wf
-- duplicate variable name
#guard !(one "f" [("x", U64)] U64 [("x", U64)] (.ret (v "x"))).wf
-- call argument type mismatch
#guard !({ structs := [], funs := [sumSquares,
  { name := "g", params := [], result := U64, locals := [("r", U64)],
    body := seqs [.call "r" "sumSquares" [.lit (.bool true)], .ret (v "r")] }] } : Program).wf
-- pointer-returning entry violates the M1 entry rule
#guard !(one "f" [("in", .ptr U8)] (.ptr U8) [] (.ret (v "in"))).entryWf "f"

/-! ### Natural C11 layout -/
def mixed : Program := { structs := [{ name := "M", fields := [U8, U64, .bool] }], funs := [] }
#guard (L mixed).sizeOf (.struct "M") == 24
#guard (L mixed).alignOf (.struct "M") == 8
#guard (L mixed).fieldOffsets "M" == [0, 8, 16]
#guard (L mixed).valid mixed

/-! ### Hostile layouts (KCore-D3)

Each layout below keeps natural, aligned, in-bounds, non-overlapping field
offsets, but claims an aggregate or field alignment that is wrong. The pre-D3
predicate (kept here only as a test oracle) accepted every one of them.
`Layout.valid` rejects them. -/

/-- `Layout.valid` as it was before KCore-D3 (test oracle only). -/
def validPreD3 (L : Layout) (P : Program) : Bool :=
  let intOk (w : IntTy) : Bool :=
    L.sizeOf (.int w) = w.bits / 8 ∧ L.alignOf (.int w) > 0 ∧
    L.sizeOf (.int w) % L.alignOf (.int w) = 0
  let tyOk (t : Ty) : Bool :=
    L.sizeOf t > 0 ∧ L.alignOf t > 0 ∧ L.sizeOf t % L.alignOf t = 0
  let structOk (sd : StructDef) : Bool :=
    let t := Ty.struct sd.name
    let offs := L.fieldOffsets sd.name
    tyOk t ∧ offs.length = sd.fields.length ∧
    (offs.zip sd.fields).all (fun of => of.1 % L.alignOf of.2 = 0 ∧
      of.1 + L.sizeOf of.2 ≤ L.sizeOf t) ∧
    ((offs.zip sd.fields).zip (offs.drop 1)).all (fun p => p.1.1 + L.sizeOf p.1.2 ≤ p.2)
  L.sizeMax > 0 ∧ [IntTy.u8, .u16, .u32, .u64].all intOk ∧ tyOk .bool ∧
  P.structs.all structOk

/-- The natural layout with the alignment of type `t` replaced by `a`. -/
def withAlign (L : Layout) (t : Ty) (a : Nat) : Layout :=
  { L with alignOf := fun u => if u = t then a else L.alignOf u }

-- 1. Under-aligned struct: `struct S { u64 }` claiming alignment 1.
def hS : Program := { structs := [{ name := "S", fields := [U64] }], funs := [] }
#guard (L hS).valid hS
#guard validPreD3 (withAlign (L hS) (.struct "S") 1) hS
#guard !(withAlign (L hS) (.struct "S") 1).valid hS

-- 2. Nested under-aligned struct: `Outer { Inner }` with `Inner { u64 }`
--    correctly aligned at 8 and `Outer` claiming 4.
def hN : Program :=
  { structs := [{ name := "Inner", fields := [U64] }, { name := "Outer", fields := [.struct "Inner"] }],
    funs := [] }
#guard (L hN).valid hN
#guard validPreD3 (withAlign (L hN) (.struct "Outer") 4) hN
#guard !(withAlign (L hN) (.struct "Outer") 4).valid hN

-- 3. Valid offsets [0, 8] and size 16 for `{ u32, u64 }`, aggregate alignment 4.
def hO : Program := { structs := [{ name := "P", fields := [.int .u32, U64] }], funs := [] }
#guard (L hO).fieldOffsets "P" == [0, 8]
#guard (L hO).sizeOf (.struct "P") == 16
#guard (L hO).valid hO
#guard validPreD3 (withAlign (L hO) (.struct "P") 4) hO
#guard !(withAlign (L hO) (.struct "P") 4).valid hO

-- 4. Pointer field whose type claims alignment 0 (0 % 0 = 0 fooled the
--    offset check; field types are now checked themselves).
def hP : Program := { structs := [{ name := "Q", fields := [.ptr U8] }], funs := [] }
#guard (L hP).valid hP
#guard validPreD3 (withAlign (L hP) (.ptr U8) 0) hP
#guard !(withAlign (L hP) (.ptr U8) 0).valid hP

-- Null dereference is a bounds fault, not a typing fault: it is well-typed.
def nullDeref := one "f" [] U8 [("p", .ptr U8), ("x", U8)] (seqs [
  .assign "p" (.lit (.ptr U8 .null)), .load "x" (v "p"), .ret (v "x")])
#guard nullDeref.wf
#guard stuckWith .bounds (run nullDeref (L nullDeref) allOk 100 #[] "f" [])
-- Use after free is a liveness fault.
def uaf := one "f" [] U8 [("b", .ptr U8), ("x", U8)] (seqs [
  .alloc "b" U8 (u64 1), .free (v "b"), .load "x" (v "b"), .ret (v "x")])
#guard uaf.wf
#guard stuckWith .liveness (run uaf (L uaf) allOk 100 #[] "f" [])
-- Division by zero is an arithmetic fault.
#guard stuckWith .arith (run (one "f" [] U64 [] (.ret (.bin .div (u64 1) (u64 0))))
  (L prog) allOk 100 #[] "f" [])

end KCore.Examples
