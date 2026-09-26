/-
KCore static well-formedness (KCore-D2): exact typing, definite assignment,
definite return, unique identities, acyclic call and struct graphs, and
target-layout validity (KCore-D1). All checks are executable `Bool`
functions, so `ProgramWF` is decidable.

Per-program proofs (T1, T2, T4, T6) take `ProgramWF`, `InputWF`,
`TargetLayoutValid` and `AllocationRepresentable` as hypotheses.
-/
import KCore.Semantics

namespace KCore

/-! ## Types -/

def Program.tyWf (P : Program) : Ty → Bool
  | .int _ | .bool => true
  | .ptr t => P.tyWf t
  | .struct n => (P.struct? n).isSome

abbrev TyEnv := List (String × Ty)

def TyEnv.lookup (Γ : TyEnv) (x : String) : Option Ty := (Γ.find? (·.1 == x)).map (·.2)

/-- The type of a literal; exactly the values admitted by `Val.isLiteral`. -/
def litTy : Val → Option Ty
  | .int w n => if n < w.bound then some (.int w) else none
  | .bool _ => some .bool
  | .ptr t .null => some (.ptr t)
  | _ => none

def binTy : BinOp → Ty → Ty → Option Ty
  | op, .int w, .int w' =>
      if w ≠ w' then none else
      match op with
      | .add | .sub | .mul | .div | .mod | .wadd | .wsub | .wmul
      | .band | .bor | .bxor | .shl | .wshl | .shr => some (.int w)
      | .eq | .ne | .lt | .le => some .bool
      | .land | .lor => none
  | .eq, .bool, .bool | .ne, .bool, .bool
  | .land, .bool, .bool | .lor, .bool, .bool => some .bool
  | op, .ptr t, .ptr t' =>
      if t ≠ t' then none else
      match op with
      | .eq | .ne | .lt | .le => some .bool
      | _ => none
  | _, _, _ => none

def unTy : UnOp → Ty → Option Ty
  | .lnot, .bool => some .bool
  | .bnot, .int w => some (.int w)
  | .zext to, .int w => if w.bits ≤ to.bits then some (.int to) else none
  | .trunc to, .int w => if to.bits ≤ w.bits then some (.int to) else none
  | _, _ => none

mutual
def typeOf (P : Program) (Γ : TyEnv) : Expr → Option Ty
  | .var x => Γ.lookup x
  | .lit v => litTy v
  | .bin op a b => do binTy op (← typeOf P Γ a) (← typeOf P Γ b)
  | .un op a => do unTy op (← typeOf P Γ a)
  | .field e i => do
      match ← typeOf P Γ e with
      | .struct n => do let sd ← P.struct? n; sd.fields[i]?
      | _ => none
  | .mk n es => do
      let sd ← P.struct? n
      let ts ← typesOf P Γ es
      if ts = sd.fields then some (.struct n) else none

def typesOf (P : Program) (Γ : TyEnv) : List Expr → Option (List Ty)
  | [] => some []
  | e :: es => do pure ((← typeOf P Γ e) :: (← typesOf P Γ es))
end

mutual
def exprVars : Expr → List String
  | .var x => [x]
  | .lit _ => []
  | .bin _ a b => exprVars a ++ exprVars b
  | .un _ a => exprVars a
  | .field e _ => exprVars e
  | .mk _ es => exprsVars es

def exprsVars : List Expr → List String
  | [] => []
  | e :: es => exprVars e ++ exprsVars es
end

/-! ## Statements: typing, definite assignment, definite return -/

/-- A statement definitely returns on every path. -/
def Stmt.returns : Stmt → Bool
  | .ret _ => true
  | .seq a b => a.returns || b.returns
  | .ite _ a b => a.returns && b.returns
  | _ => false

def Stmt.calls : Stmt → List String
  | .call _ f _ => [f]
  | .ite _ a b | .seq a b => a.calls ++ b.calls
  | .while _ body => body.calls
  | _ => []

/-- Every variable of `e` is definitely assigned. -/
def usedIn (A : List String) (e : Expr) : Bool := (exprVars e).all (· ∈ A)

/-- Check one statement in function `fd` given the definitely assigned set
    `A`. Returns the assigned set afterwards, or `none` on any typing or
    definite-assignment error. After a definite `ret`, every variable counts
    as assigned (the continuation is unreachable). -/
def checkStmt (P : Program) (fd : FunDef) (A : List String) : Stmt → Option (List String)
  | .skip => some A
  | .assign x e => do
      let t ← typeOf P fd.vars e
      if TyEnv.lookup fd.vars x = some t ∧ usedIn A e then some (x :: A) else none
  | .load x p => do
      match ← typeOf P fd.vars p with
      | .ptr t =>
          if TyEnv.lookup fd.vars x = some t ∧ P.pointerFree? t ∧ usedIn A p then some (x :: A) else none
      | _ => none
  | .store p v => do
      match ← typeOf P fd.vars p, ← typeOf P fd.vars v with
      | .ptr t, t' =>
          if t = t' ∧ P.pointerFree? t ∧ usedIn A p ∧ usedIn A v then some A else none
      | _, _ => none
  | .ptrAdd x p k => do
      match ← typeOf P fd.vars p, ← typeOf P fd.vars k with
      | .ptr t, .int .u64 =>
          if TyEnv.lookup fd.vars x = some (.ptr t) ∧ usedIn A p ∧ usedIn A k then some (x :: A) else none
      | _, _ => none
  | .alloc x t c => do
      match ← typeOf P fd.vars c with
      | .int .u64 =>
          if TyEnv.lookup fd.vars x = some (.ptr t) ∧ P.pointerFree? t ∧ usedIn A c
          then some (x :: A) else none
      | _ => none
  | .free p => do
      match ← typeOf P fd.vars p with
      | .ptr _ => if usedIn A p then some A else none
      | _ => none
  | .call x f args => do
      let g ← P.fun? f
      let ts ← typesOf P fd.vars args
      if ts = g.params.map (·.2) ∧ TyEnv.lookup fd.vars x = some g.result ∧
         (exprsVars args).all (· ∈ A) then some (x :: A) else none
  | .checkpoint => some A
  | .ite c a b => do
      if typeOf P fd.vars c ≠ some .bool ∨ ¬ usedIn A c then none else
      let A₁ ← checkStmt P fd A a
      let A₂ ← checkStmt P fd A b
      if a.returns then some A₂
      else if b.returns then some A₁
      else some (A₁.filter (· ∈ A₂))
  | .while c body => do
      if typeOf P fd.vars c ≠ some .bool ∨ ¬ usedIn A c then none else
      let _ ← checkStmt P fd A body
      some A
  | .seq a b => do checkStmt P fd (← checkStmt P fd A a) b
  | .ret e => do
      let t ← typeOf P fd.vars e
      if t = fd.result ∧ usedIn A e then some (fd.vars.map (·.1)) else none

def FunDef.wf (P : Program) (fd : FunDef) : Bool :=
  (fd.vars.map (·.1)).Nodup ∧
  fd.vars.all (fun v => P.tyWf v.2) ∧ P.tyWf fd.result ∧
  (checkStmt P fd fd.paramNames fd.body).isSome ∧ fd.body.returns

/-! ## Graphs -/

/-- Acyclicity by repeated removal of nodes with no remaining successors.
    A cycle can never be removed. `fuel` = number of nodes suffices. -/
def acyclicAux (succ : String → List String) : Nat → List String → Bool
  | 0, remaining => remaining.isEmpty
  | n + 1, remaining =>
      if remaining.isEmpty then true else
      let sinks := remaining.filter (fun x => (succ x).all (fun y => y ∉ remaining))
      if sinks.isEmpty then false
      else acyclicAux succ n (remaining.filter (· ∉ sinks))

def acyclic (nodes : List String) (succ : String → List String) : Bool :=
  acyclicAux succ nodes.length nodes

def Program.callGraphAcyclic (P : Program) : Bool :=
  acyclic (P.funs.map (·.name)) (fun f => match P.fun? f with
    | some fd => fd.body.calls
    | none => [])

/-- Structs contained by value (not through a pointer). -/
def Ty.byValueStruct : Ty → Option String
  | .struct n => some n
  | _ => none

def Program.structGraphAcyclic (P : Program) : Bool :=
  acyclic (P.structs.map (·.name)) (fun n => match P.struct? n with
    | some sd => sd.fields.filterMap Ty.byValueStruct
    | none => [])

/-! ## Target layout (KCore-D1) -/

def roundUp (n a : Nat) : Nat := if a = 0 then n else (n + a - 1) / a * a

/-- Internal consistency of a target layout for every type of `P`:
    exact integer widths, positive sizes and alignments, alignment dividing
    size, and for each struct:
    * every field type has a positive size and alignment, with its alignment
      dividing its size;
    * the struct's alignment is a multiple of every field's alignment
      (KCore-D3). By induction over containment this extends to every
      recursively contained field (`Layout.valid_contains_align`);
    * one offset per field, each aligned, fields non-overlapping and in
      order, all within the struct's size. -/
def Layout.valid (L : Layout) (P : Program) : Bool :=
  let intOk (w : IntTy) : Bool :=
    L.sizeOf (.int w) = w.bits / 8 ∧ L.alignOf (.int w) > 0 ∧
    L.sizeOf (.int w) % L.alignOf (.int w) = 0
  let tyOk (t : Ty) : Bool :=
    L.sizeOf t > 0 ∧ L.alignOf t > 0 ∧ L.sizeOf t % L.alignOf t = 0
  let structOk (sd : StructDef) : Bool :=
    let t := Ty.struct sd.name
    let offs := L.fieldOffsets sd.name
    tyOk t ∧ offs.length = sd.fields.length ∧
    sd.fields.all (fun f => tyOk f ∧ L.alignOf t % L.alignOf f = 0) ∧
    (offs.zip sd.fields).all (fun of => of.1 % L.alignOf of.2 = 0 ∧
      of.1 + L.sizeOf of.2 ≤ L.sizeOf t) ∧
    ((offs.zip sd.fields).zip (offs.drop 1)).all (fun p => p.1.1 + L.sizeOf p.1.2 ≤ p.2)
  L.sizeMax > 0 ∧ [IntTy.u8, .u16, .u32, .u64].all intOk ∧ tyOk .bool ∧
  P.structs.all structOk

/- Natural C11 layout: each type aligned to its natural alignment, struct
   fields at increasing aligned offsets, and the struct size rounded to its
   largest field alignment. This is the C target's *claimed* layout. The
   emitted C asserts every used value with `sizeof`, `_Alignof` and
   `offsetof`, so a disagreeing compiler fails the build. -/
/-- (end offset, max alignment) of a field list laid out from `off`, given
    the layout of each field type. -/
def natStructWith (lay : Ty → Nat × Nat) : List Ty → Nat → Nat → Nat × Nat
  | [], off, al => (off, al)
  | t :: ts, off, al =>
      let fa := lay t
      natStructWith lay ts (roundUp off fa.2 + fa.1) (max al fa.2)

/-- (size, alignment) of a type. Structural recursion on the depth, so the
    kernel can evaluate it (see the note at `pointerFree`). -/
def natLayout (P : Program) : Nat → Ty → Nat × Nat
  | _, .int w => (w.bits / 8, w.bits / 8)
  | _, .bool => (1, 1)
  | _, .ptr _ => (8, 8)
  | 0, .struct _ => (0, 1)
  | d + 1, .struct n =>
      match P.struct? n with
      | none => (0, 1)
      | some sd =>
          let r := natStructWith (natLayout P d) sd.fields 0 1
          (roundUp r.1 r.2, r.2)

def natStruct (P : Program) (d : Nat) : List Ty → Nat → Nat → Nat × Nat :=
  natStructWith (natLayout P d)

/-- Left-to-right natural field offsets. -/
def natOffsets (P : Program) (d : Nat) : List Ty → Nat → List Nat
  | [], _ => []
  | t :: ts, off =>
      let fa := natLayout P d t
      let o := roundUp off fa.2
      o :: natOffsets P d ts (o + fa.1)

def Layout.naturalC11 (P : Program) : Layout :=
  let depth := P.structs.length + 1
  { sizeOf := fun t => (natLayout P depth t).1
    alignOf := fun t => (natLayout P depth t).2
    fieldOffsets := fun n => match P.struct? n with
      | some sd => natOffsets P (depth - 1) sd.fields 0
      | none => []
    sizeMax := 2 ^ 64 - 1 }

/-! ## Program and input well-formedness -/

/-- `ProgramWF` (KCore-D2). -/
def Program.wf (P : Program) : Bool :=
  (P.structs.map (·.name)).Nodup ∧ (P.funs.map (·.name)).Nodup ∧
  P.structs.all (fun sd => sd.fields.all P.tyWf) ∧
  P.structGraphAcyclic ∧ P.callGraphAcyclic ∧
  P.funs.all (FunDef.wf P)

/-- The M1 entry rule: the entry exists and its result is pointer-free. -/
def Program.entryWf (P : Program) (entry : String) : Bool :=
  match P.fun? entry with
  | some fd => P.pointerFree? fd.result
  | none => false

/-- `InputWF` (KCore-D2): exactly the dynamic check `run` performs. -/
def InputWF (P : Program) (inputs : Array Block) (entry : String) (args : List Val) : Bool :=
  match P.fun? entry with
  | some fd => P.inputOk inputs fd args
  | none => false

end KCore
