/-
KCore syntax (docs/engineering/KCORE_SEMANTICS.md §§1, 4).

Design rule: C hazards are excluded from the language rather than modelled.
There are no signed types, casts, unions, function pointers, `void*` or
address-of. Expressions are pure; every effect is a statement.
-/
namespace KCore

/-- Unsigned integer widths. No signed type exists. -/
inductive IntTy where
  | u8 | u16 | u32 | u64
deriving DecidableEq, Repr

def IntTy.bits : IntTy → Nat
  | .u8 => 8 | .u16 => 16 | .u32 => 32 | .u64 => 64

/-- Exclusive upper bound of the width: values are `n < 2^bits`. -/
def IntTy.bound (w : IntTy) : Nat := 2 ^ w.bits

inductive Ty where
  | int (w : IntTy)
  | bool
  | ptr (target : Ty)
  | struct (name : String)
deriving DecidableEq, Repr

/-- A pointer value. Provenance is the block identity, which never changes and
    cannot be produced from an integer. -/
inductive Ptr where
  | null
  | loc (block : Nat) (offset : Nat)
deriving DecidableEq, Repr

inductive Val where
  | int (w : IntTy) (n : Nat)
  | bool (b : Bool)
  | ptr (target : Ty) (p : Ptr)
  | struct (name : String) (fields : List Val)
deriving Repr

inductive BinOp where
  /-- Checked arithmetic: stuck when the mathematical result does not fit,
      and on division or remainder by zero. -/
  | add | sub | mul | div | mod
  /-- Wrapping arithmetic, modulo 2^bits. Only these may wrap. -/
  | wadd | wsub | wmul
  | band | bor | bxor
  /-- `shl` is checked (no set bit may be lost); `wshl` wraps. The shift
      amount must be below the width. -/
  | shl | wshl | shr
  | eq | ne | lt | le
  /-- Logical operators on `bool` (pure, so evaluation order is irrelevant). -/
  | land | lor
deriving DecidableEq, Repr

inductive UnOp where
  | lnot                 -- bool negation
  | bnot                 -- bitwise complement within the width
  | zext (to : IntTy)    -- widening, value preserving
  | trunc (to : IntTy)   -- narrowing, modulo 2^to.bits
deriving DecidableEq, Repr

inductive Expr where
  | var (x : String)
  | lit (v : Val)
  | bin (op : BinOp) (a b : Expr)
  | un (op : UnOp) (a : Expr)
  | field (e : Expr) (index : Nat)
  | mk (name : String) (fields : List Expr)
deriving Repr

inductive Stmt where
  | skip
  | assign (x : String) (e : Expr)
  | load (x : String) (p : Expr)
  | store (p : Expr) (v : Expr)
  | ptrAdd (x : String) (p : Expr) (k : Expr)
  | alloc (x : String) (t : Ty) (count : Expr)
  | free (p : Expr)
  | call (x : String) (f : String) (args : List Expr)
  | checkpoint
  | ite (c : Expr) (a b : Stmt)
  | while (c : Expr) (body : Stmt)
  | seq (a b : Stmt)
  | ret (e : Expr)
deriving Repr

structure StructDef where
  name : String
  fields : List Ty
deriving Repr

/-- A function with typed parameters, a declared result type and declared,
    typed locals (KCore-D2). Parameters and locals share one namespace. -/
structure FunDef where
  name : String
  params : List (String × Ty)
  result : Ty
  locals : List (String × Ty)
  body : Stmt
deriving Repr

def FunDef.paramNames (fd : FunDef) : List String := fd.params.map (·.1)

/-- Every variable visible in the body, with its declared type. -/
def FunDef.vars (fd : FunDef) : List (String × Ty) := fd.params ++ fd.locals

structure Program where
  structs : List StructDef
  funs : List FunDef
deriving Repr

def Program.struct? (P : Program) (name : String) : Option StructDef :=
  P.structs.find? (·.name == name)

def Program.fun? (P : Program) (name : String) : Option FunDef :=
  P.funs.find? (·.name == name)

/-- Target layout (KCore-D1, `TargetLayoutV1`). Supplied by each target and
    checked by `Layout.valid`. The C target emits static assertions for every
    used layout. -/
structure Layout where
  sizeOf : Ty → Nat
  alignOf : Ty → Nat
  /-- Byte offset of each field of a struct, in declaration order. -/
  fieldOffsets : String → List Nat
  /-- The target's `SIZE_MAX`. -/
  sizeMax : Nat

/-- Largest representable element count for an allocation of `t`. -/
def Layout.maxCount (L : Layout) (t : Ty) : Nat :=
  if L.sizeOf t = 0 then 0 else L.sizeMax / L.sizeOf t

end KCore
