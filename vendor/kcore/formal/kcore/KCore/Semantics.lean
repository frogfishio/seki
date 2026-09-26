/-
KCore semantics (docs/engineering/KCORE_SEMANTICS.md §§2–6).

This file defines the executable, fuel-indexed evaluator. Misuse of any kind
evaluates to `stuck`, tagged with the class of fault. Verified programs are
later proved never to be stuck. Well-formed programs are proved never to
reach a `typing` fault (KCore/TypeSoundness.lean), so per-program obligations
reduce to arithmetic, bounds, liveness, allocation and leak conditions.
Operational failure arises only from environment-decided events (§5), and
transaction-owned blocks are released by the semantics itself (§5a).
-/
import KCore.Syntax

namespace KCore

/-- Why an evaluation is stuck. -/
inductive Fault where
  /-- Type or shape mismatch, unassigned variable, bad call, missing return,
      invalid literal or provenance, input violating `InputWF`. Excluded for
      well-formed programs by type soundness. -/
  | typing
  /-- Checked overflow or underflow, division by zero, shift out of range. -/
  | arith
  /-- Out-of-bounds access or pointer arithmetic, null dereference,
      cross-block relational comparison, freeing through a non-base pointer. -/
  | bounds
  /-- Use after free, double free, freeing a block the transaction does not own. -/
  | liveness
  /-- Allocation count zero or not representable on the target (KCore-D1). -/
  | alloc
  /-- A transaction-owned block is still live at successful completion. -/
  | leak
deriving DecidableEq, Repr

/-! ## Pure values and expressions -/

def Val.ty : Val → Ty
  | .int w _ => .int w
  | .bool _ => .bool
  | .ptr t _ => .ptr t
  | .struct name _ => .struct name

abbrev Eval := Except Fault

def mkInt (w : IntTy) (n : Nat) : Eval Val :=
  if n < w.bound then .ok (.int w n) else .error .arith

def evalBin : BinOp → Val → Val → Eval Val
  | op, .int w a, .int w' b =>
      if w ≠ w' then .error .typing else
      match op with
      | .add => mkInt w (a + b)
      | .sub => if b ≤ a then .ok (.int w (a - b)) else .error .arith
      | .mul => mkInt w (a * b)
      | .div => if b = 0 then .error .arith else .ok (.int w (a / b))
      | .mod => if b = 0 then .error .arith else .ok (.int w (a % b))
      | .wadd => .ok (.int w ((a + b) % w.bound))
      | .wsub => .ok (.int w ((a + w.bound - b) % w.bound))
      | .wmul => .ok (.int w ((a * b) % w.bound))
      | .band => .ok (.int w (a &&& b))
      | .bor => .ok (.int w (a ||| b))
      | .bxor => .ok (.int w (a ^^^ b))
      | .shl => if b < w.bits then mkInt w (a <<< b) else .error .arith
      | .wshl => if b < w.bits then .ok (.int w ((a <<< b) % w.bound)) else .error .arith
      | .shr => if b < w.bits then .ok (.int w (a >>> b)) else .error .arith
      | .eq => .ok (.bool (a == b))
      | .ne => .ok (.bool (a != b))
      | .lt => .ok (.bool (decide (a < b)))
      | .le => .ok (.bool (decide (a ≤ b)))
      | .land | .lor => .error .typing
  | .eq, .bool a, .bool b => .ok (.bool (a == b))
  | .ne, .bool a, .bool b => .ok (.bool (a != b))
  | .land, .bool a, .bool b => .ok (.bool (a && b))
  | .lor, .bool a, .bool b => .ok (.bool (a || b))
  | op, .ptr t p, .ptr t' q =>
      if t ≠ t' then .error .typing else
      match op, p, q with
      | .eq, _, _ => .ok (.bool (p == q))
      | .ne, _, _ => .ok (.bool (p != q))
      -- Relational comparison only within one block, as in C.
      | .lt, .loc b o, .loc b' o' =>
          if b = b' then .ok (.bool (decide (o < o'))) else .error .bounds
      | .le, .loc b o, .loc b' o' =>
          if b = b' then .ok (.bool (decide (o ≤ o'))) else .error .bounds
      | .lt, _, _ | .le, _, _ => .error .bounds
      | _, _, _ => .error .typing
  | _, _, _ => .error .typing

def evalUn : UnOp → Val → Eval Val
  | .lnot, .bool b => .ok (.bool (!b))
  | .bnot, .int w a => .ok (.int w (w.bound - 1 - a))
  | .zext to, .int w a => if w.bits ≤ to.bits then .ok (.int to a) else .error .typing
  | .trunc to, .int w a => if to.bits ≤ w.bits then .ok (.int to (a % to.bound)) else .error .typing
  | _, _ => .error .typing

/-- Literals may only denote in-range integers, booleans and `null`.
    A pointer literal to a block would forge provenance; struct values are
    built with `mk`. -/
def Val.isLiteral : Val → Bool
  | .int w n => decide (n < w.bound)
  | .bool _ => true
  | .ptr _ .null => true
  | _ => false

/-- Locals are a finite partial map. There is no address-of, so no pointer can
    refer to a local. -/
abbrev Locals := String → Option Val

def Locals.empty : Locals := fun _ => none

def Locals.set (l : Locals) (x : String) (v : Val) : Locals :=
  fun y => if y = x then some v else l y

def Locals.ofList : List (String × Val) → Locals
  | [] => Locals.empty
  | (x, v) :: rest => (Locals.ofList rest).set x v

mutual
def evalExpr (l : Locals) : Expr → Eval Val
  | .var x => match l x with
      | some v => .ok v
      | none => .error .typing
  | .lit v => if v.isLiteral then .ok v else .error .typing
  | .bin op a b => do evalBin op (← evalExpr l a) (← evalExpr l b)
  | .un op a => do evalUn op (← evalExpr l a)
  | .field e i => do
      match ← evalExpr l e with
      | .struct _ fs => match fs[i]? with
          | some v => .ok v
          | none => .error .typing
      | _ => .error .typing
  | .mk name es => do pure (.struct name (← evalExprs l es))

def evalExprs (l : Locals) : List Expr → Eval (List Val)
  | [] => .ok []
  | e :: es => do pure ((← evalExpr l e) :: (← evalExprs l es))
end

/-! ## Typed zero values (semantic initialization, KCORE_SEMANTICS §2)

Heap element types are pointer-free: `zeroOf` has no case for pointers, so
allocating a pointer-bearing type is stuck. Structs are initialized
fieldwise. `depth` bounds struct nesting; a cyclic struct definition simply
has no zero value. -/
mutual
def zeroOf (P : Program) : Nat → Ty → Option Val
  | _, .int w => some (.int w 0)
  | _, .bool => some (.bool false)
  | _, .ptr _ => none
  | 0, .struct _ => none
  | d + 1, .struct name => do
      let sd ← P.struct? name
      pure (.struct name (← zerosOf P d sd.fields))

def zerosOf (P : Program) : Nat → List Ty → Option (List Val)
  | _, [] => some []
  | d, t :: ts => do pure ((← zeroOf P d t) :: (← zerosOf P d ts))
end

def Program.zero? (P : Program) (t : Ty) : Option Val :=
  zeroOf P (P.structs.length + 1) t

/- Deep conformance of a value to a type under the program's struct
   definitions: integer ranges, pointer target types, and struct field
   arity and types. Structural on the value, which is a finite tree. -/
mutual
def conforms (P : Program) : Val → Ty → Bool
  | .int w n, .int w' => w == w' && decide (n < w.bound)
  | .bool _, .bool => true
  | .ptr t _, .ptr t' => t == t'
  | .struct n fs, .struct n' =>
      n == n' && (match P.struct? n with
        | some sd => conformsAll P fs sd.fields
        | none => false)
  | _, _ => false

def conformsAll (P : Program) : List Val → List Ty → Bool
  | [], [] => true
  | v :: vs, t :: ts => conforms P v t && conformsAll P vs ts
  | _, _ => false
end

def Program.conforms? (P : Program) (v : Val) (t : Ty) : Bool := conforms P v t

/- Pointer-free types: the only types that may live in heap cells or be a
   successful entry result (KCore §2, M1 success rule).

   Written as plain structural recursion on the depth (the field list goes
   through `List.all`), not as a mutual block: Lean compiles that mutual
   block by well-founded recursion, which the kernel cannot evaluate, so
   `Program.wf` of a concrete program could not be checked by `decide`. -/
def pointerFree (P : Program) : Nat → Ty → Bool
  | _, .int _ | _, .bool => true
  | _, .ptr _ => false
  | 0, .struct _ => false
  | d + 1, .struct n =>
      match P.struct? n with
      | some sd => sd.fields.all (pointerFree P d)
      | none => false

def pointerFreeAll (P : Program) (d : Nat) (ts : List Ty) : Bool := ts.all (pointerFree P d)

@[simp] theorem pointerFreeAll_nil {P : Program} {d : Nat} : pointerFreeAll P d [] = true := rfl
@[simp] theorem pointerFreeAll_cons {P : Program} {d : Nat} {t : Ty} {ts : List Ty} :
    pointerFreeAll P d (t :: ts) = (pointerFree P d t && pointerFreeAll P d ts) := by
  simp [pointerFreeAll]

def Program.pointerFree? (P : Program) (t : Ty) : Bool :=
  pointerFree P (P.structs.length + 1) t

/-- Exact call typing: arity and deep conformance of every argument. -/
def Program.argsOk (P : Program) (fd : FunDef) (vs : List Val) : Bool :=
  fd.params.length == vs.length &&
  (fd.params.zip vs).all (fun pv => P.conforms? pv.2 pv.1.2)

/-! ## Heap, ownership and events -/

structure Block where
  ty : Ty
  cells : Array Val
  live : Bool
deriving Repr

/-- `owned` is the transaction-owned set (§5a). Block ids are array indices and
    are never reused: blocks are only ever appended. -/
structure Heap where
  blocks : Array Block
  owned : List Nat
deriving Repr

def Heap.load? (h : Heap) (t : Ty) (b o : Nat) : Eval Val :=
  match h.blocks[b]? with
  | none => .error .typing
  | some blk =>
    if blk.live = false then .error .liveness
    else if blk.ty ≠ t then .error .typing
    else match blk.cells[o]? with
      | some v => .ok v
      | none => .error .bounds

def Heap.store? (h : Heap) (t : Ty) (b o : Nat) (v : Val) : Eval Heap :=
  match h.blocks[b]? with
  | none => .error .typing
  | some blk =>
    if blk.live = false then .error .liveness
    else if blk.ty ≠ t ∨ v.ty ≠ t then .error .typing
    else if o < blk.cells.size then
      .ok { h with blocks := h.blocks.set! b { blk with cells := blk.cells.set! o v } }
    else .error .bounds

/-- Pointer arithmetic stays within `[0, len]` of a live block. -/
def Heap.ptrAdd? (h : Heap) (b o k : Nat) : Eval Nat :=
  match h.blocks[b]? with
  | none => .error .typing
  | some blk =>
    if blk.live = false then .error .liveness
    else if o + k ≤ blk.cells.size then .ok (o + k) else .error .bounds

/-- Only transaction-owned, live blocks may be freed, and only through their
    base pointer. Input blocks provided by the host shell are not owned. -/
def Heap.free? (h : Heap) (b : Nat) : Eval Heap :=
  match h.blocks[b]? with
  | none => .error .typing
  | some blk =>
    if blk.live = true ∧ b ∈ h.owned then
      .ok { blocks := h.blocks.set! b { blk with live := false },
            owned := h.owned.erase b }
    else .error .liveness

def Heap.alloc (h : Heap) (t : Ty) (n : Nat) (z : Val) : Heap × Nat :=
  ({ blocks := h.blocks.push { ty := t, cells := Array.replicate n z, live := true },
     owned := h.blocks.size :: h.owned }, h.blocks.size)

/-- Release every transaction-owned block (§5a). -/
def Heap.releaseAll (h : Heap) : Heap :=
  { blocks := h.blocks.mapIdx (fun i blk => if i ∈ h.owned then { blk with live := false } else blk),
    owned := [] }

inductive Event where
  | alloc (t : Ty) (count : Nat)
  | cancel
deriving Repr

inductive Failure where
  | allocationFailed | cancelled
deriving DecidableEq, Repr

/-- The event that witnesses a failure (§5, T3). -/
def Failure.witnessedBy : Failure → Event → Prop
  | .allocationFailed, .alloc _ _ => True
  | .cancelled, .cancel => True
  | _, _ => False

structure EventRec where
  ev : Event
  succeeded : Bool
deriving Repr

/-- The environment decides every fallible event: `env k ev = true` means the
    `k`-th event succeeds. -/
abbrev Env := Nat → Event → Bool

/-- Machine state. `trace` is newest-first; its length is the event index. -/
structure Machine where
  heap : Heap
  trace : List EventRec
deriving Repr

def Machine.record (m : Machine) (ev : Event) (ok : Bool) : Machine :=
  { m with trace := ⟨ev, ok⟩ :: m.trace }

/-! ## Statement evaluation -/

inductive Res where
  | normal (m : Machine) (l : Locals)
  | ret (m : Machine) (v : Val)
  | fail (m : Machine) (f : Failure)
  | stuck (m : Machine) (why : Fault)
  | oof

/-- One atomic (non-recursive) statement step. Shared by the evaluator
    (`exec`) and the inductive relation (`Exec`, KCore/BigStep.lean), so the
    two semantics cannot drift apart on atomic statements. -/
def atomic (P : Program) (L : Layout) (env : Env) (m : Machine) (l : Locals) : Stmt → Res
  | .skip => .normal m l
  | .assign x e =>
      match evalExpr l e with
      | .ok v => .normal m (l.set x v)
      | .error f => .stuck m f
  | .load x pe =>
      match evalExpr l pe with
      | .ok (.ptr t (.loc b o)) =>
          match m.heap.load? t b o with
          | .ok v => .normal m (l.set x v)
          | .error f => .stuck m f
      | .ok (.ptr _ .null) => .stuck m .bounds
      | .ok _ => .stuck m .typing
      | .error f => .stuck m f
  | .store pe ve =>
      match evalExpr l pe, evalExpr l ve with
      | .error f, _ => .stuck m f
      | _, .error f => .stuck m f
      | .ok (.ptr t (.loc b o)), .ok v =>
          -- Deep conformance: a heap cell can only receive a value of its
          -- exact (pointer-free) element type, so no pointer reaches the heap.
          if P.conforms? v t then
            match m.heap.store? t b o v with
            | .ok h => .normal { m with heap := h } l
            | .error f => .stuck m f
          else .stuck m .typing
      | .ok (.ptr _ .null), .ok _ => .stuck m .bounds
      | .ok _, .ok _ => .stuck m .typing
  | .ptrAdd x pe ke =>
      match evalExpr l pe, evalExpr l ke with
      | .error f, _ => .stuck m f
      | _, .error f => .stuck m f
      | .ok (.ptr t (.loc b o)), .ok (.int .u64 k) =>
          match m.heap.ptrAdd? b o k with
          | .ok o' => .normal m (l.set x (.ptr t (.loc b o')))
          | .error f => .stuck m f
      | .ok (.ptr _ .null), .ok (.int .u64 _) => .stuck m .bounds
      | .ok _, .ok _ => .stuck m .typing
  | .alloc x t ce =>
      match evalExpr l ce with
      | .ok (.int .u64 k) =>
          -- Representability (KCore-D1): the count must fit the target's
          -- size_t for this element type; otherwise the program is stuck,
          -- not an environment decision.
          if k = 0 ∨ L.maxCount t < k then .stuck m .alloc else
          match P.zero? t with
          | none => .stuck m .typing
          | some z =>
              let ev := Event.alloc t k
              let ok := env m.trace.length ev
              let m' := m.record ev ok
              if ok then
                let (h, b) := m'.heap.alloc t k z
                .normal { m' with heap := h } (l.set x (.ptr t (.loc b 0)))
              else .fail m' .allocationFailed
      | .ok _ => .stuck m .typing
      | .error f => .stuck m f
  | .free pe =>
      match evalExpr l pe with
      | .ok (.ptr _ (.loc b 0)) =>
          match m.heap.free? b with
          | .ok h => .normal { m with heap := h } l
          | .error f => .stuck m f
      | .ok (.ptr _ _) => .stuck m .bounds    -- null or non-base pointer
      | .ok _ => .stuck m .typing
      | .error f => .stuck m f
  | .checkpoint =>
      let ok := env m.trace.length .cancel
      let m' := m.record .cancel ok
      if ok then .normal m' l else .fail m' .cancelled
  | .ret e =>
      match evalExpr l e with
      | .ok v => .ret m v
      | .error f => .stuck m f
  -- Recursive forms are not atomic; `exec` and `Exec` handle them.
  | .call .. | .ite .. | .while .. | .seq .. => .stuck m .typing

def Stmt.isAtomic : Stmt → Bool
  | .call .. | .ite .. | .while .. | .seq .. => false
  | _ => true

def exec (P : Program) (L : Layout) (env : Env) : Nat → Machine → Locals → Stmt → Res
  | 0, _, _, _ => .oof
  | n + 1, m, l, s =>
    match s with
    | .call x f args =>
        match evalExprs l args, P.fun? f with
        | .error e, _ => .stuck m e
        | .ok _, none => .stuck m .typing
        | .ok vs, some fd =>
            if P.argsOk fd vs then
              match exec P L env n m (Locals.ofList (fd.paramNames.zip vs)) fd.body with
              | .ret m' v =>
                  if P.conforms? v fd.result then .normal m' (l.set x v) else .stuck m' .typing
              | .normal m' _ => .stuck m' .typing   -- falling off the end
              | r => r
            else .stuck m .typing
    | .ite c a b =>
        match evalExpr l c with
        | .ok (.bool true) => exec P L env n m l a
        | .ok (.bool false) => exec P L env n m l b
        | .ok _ => .stuck m .typing
        | .error f => .stuck m f
    | .while c body =>
        match evalExpr l c with
        | .ok (.bool false) => .normal m l
        | .ok (.bool true) =>
            match exec P L env n m l body with
            | .normal m' l' => exec P L env n m' l' (.while c body)
            | r => r
        | .ok _ => .stuck m .typing
        | .error f => .stuck m f
    | .seq a b =>
        match exec P L env n m l a with
        | .normal m' l' => exec P L env n m' l' b
        | r => r
    | s => atomic P L env m l s

/-! ## Transaction outcome -/

inductive Outcome where
  | ok (v : Val) (h : Heap) (trace : List EventRec)
  | operational (f : Failure) (h : Heap) (trace : List EventRec)
  | stuck (h : Heap) (why : Fault)
  | outOfFuel

/- Input validity (KCore-D2 `InputWF`): host input blocks are live, of
   pointer-free element type, and every cell conforms to that type. Pointer
   values in arguments (including inside local structs) refer to an input
   block, within `[0, len]`, with the block's exact element type. -/
def Program.blockOk (P : Program) (blk : Block) : Bool :=
  blk.live && P.pointerFree? blk.ty && blk.cells.all (fun c => P.conforms? c blk.ty)

mutual
def ptrsInInputs (inputs : Array Block) : Val → Bool
  | .ptr _ .null => true
  | .ptr t (.loc b o) =>
      match inputs[b]? with
      | some blk => blk.ty == t && decide (o ≤ blk.cells.size)
      | none => false
  | .struct _ fs => ptrsInInputsAll inputs fs
  | _ => true

def ptrsInInputsAll (inputs : Array Block) : List Val → Bool
  | [] => true
  | v :: vs => ptrsInInputs inputs v && ptrsInInputsAll inputs vs
end

def Program.inputOk (P : Program) (inputs : Array Block) (fd : FunDef) (args : List Val) : Bool :=
  inputs.all P.blockOk && P.argsOk fd args && args.all (ptrsInInputs inputs)

/-- Run one transaction: call `entry` on `args` over the host-provided input
    blocks, which are private snapshots and not transaction-owned. Inputs
    must satisfy `inputOk`. On `operational` and `stuck`, every
    transaction-owned block is released by the semantics. `ok` additionally
    requires the M1 success rule: a pointer-free, conforming result and an
    empty owned set. -/
def run (P : Program) (L : Layout) (env : Env) (fuel : Nat) (inputs : Array Block)
    (entry : String) (args : List Val) : Outcome :=
  let m0 : Machine := { heap := { blocks := inputs, owned := [] }, trace := [] }
  match P.fun? entry with
  | none => .stuck m0.heap .typing
  | some fd =>
    if !P.inputOk inputs fd args then .stuck m0.heap .typing else
    match exec P L env fuel m0 (Locals.ofList (fd.paramNames.zip args)) fd.body with
    | .ret m v =>
        if !(P.conforms? v fd.result && P.pointerFree? fd.result)
        then .stuck m.heap.releaseAll .typing
        else if !m.heap.owned.isEmpty then .stuck m.heap.releaseAll .leak
        else .ok v m.heap m.trace
    | .fail m f => .operational f m.heap.releaseAll m.trace
    | .stuck m why => .stuck m.heap.releaseAll why
    | .normal m _ => .stuck m.heap.releaseAll .typing
    | .oof => .outOfFuel

end KCore
