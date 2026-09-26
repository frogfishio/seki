/-
Seki's canonical typed core, as a Lean model: the fragment the A0 alpha
compiler emits (`spec/typed-core/SEKI_TYPED_CORE_V0_DRAFT.md`).

This is the authority's shape, not the surface language. Names, references and
orders are exactly those of the canonical encoding: declaration references are
indices into the canonically ordered type table, fields are canonical field
positions, variant cases are stable tags, and locals are de Bruijn indices
(0 is the nearest binder; parameters are pushed left to right, so the last
parameter is 0).

Anything outside the fragment has no constructor here, so a decoder that
produces this model fails closed on it.
-/
namespace Seki

inductive IntTy where
  | u8 | u16 | u32 | u64
deriving DecidableEq, Repr

def IntTy.bits : IntTy → Nat
  | .u8 => 8 | .u16 => 16 | .u32 => 32 | .u64 => 64

inductive Ty where
  | unit
  | bool
  | int (w : IntTy)
  | bytes (length : Nat)
  | digest (length : Nat)
  | decision (accepted rejection : Ty)
  /-- A declared type: index into the canonical type table. -/
  | declared (index : Nat)
deriving DecidableEq, Repr

structure Field where
  name : String
  ty : Ty
deriving Repr

structure Case where
  tag : Nat
  name : String
  /-- `none` for a case without payload; otherwise its fields in canonical order. -/
  payload : Option (List Field)
deriving Repr

inductive DeclBody where
  | alias (target : Ty)
  | nominal (representation : Ty)
  | record (fields : List Field)
  | variant (cases : List Case)
deriving Repr

structure Decl where
  name : String
  body : DeclBody
deriving Repr

inductive CmpOp where
  | lt | le | gt | ge
deriving DecidableEq, Repr

mutual
/-- A typed expression: its claimed type and its term. -/
inductive Expr where
  | mk (ty : Ty) (term : Term)

inductive Term where
  | unit
  | bool (value : Bool)
  | int (w : IntTy) (value : Nat)
  | local (index : Nat)
  /-- Record construction: every field, in canonical field order. -/
  | record (ty : Nat) (fields : Inits)
  | project (record : Expr) (ty : Nat) (field : Nat)
  /-- Variant construction: a case by stable tag, payload fields by name. -/
  | variant (ty : Nat) (tag : Nat) (fields : NamedInits)
  | eq (left right : Expr)
  | ne (left right : Expr)
  | andThen (left right : Expr)
  | orElse (left right : Expr)
  | cmp (op : CmpOp) (left right : Expr)

inductive Inits where
  | nil
  | cons (field : Nat) (value : Expr) (rest : Inits)

inductive NamedInits where
  | nil
  | cons (name : String) (value : Expr) (rest : NamedInits)
end

mutual
/-- Tail-formed kernel control (typed core §8.7). -/
inductive KExpr where
  | accept (value : Expr)
  | reject (reason : Expr) (precedence : Nat)
  | require (condition reason : Expr) (precedence : Nat) (continuation : KExpr)
  | let_ (value : Expr) (body : KExpr)
  | ite (condition : Expr) (whenTrue whenFalse : KExpr)
  | match_ (scrutinee : Expr) (arms : Arms)

inductive Arms where
  | nil
  /-- An arm for the declared variant `ty`'s case `tag`. -/
  | cons (ty : Nat) (tag : Nat) (body : KExpr) (rest : Arms)
end

structure Bounds where
  steps : Nat
  liveBits : Nat
  controlDepth : Nat
  workspaceBits : Nat
deriving Repr

structure Kernel where
  name : String
  labels : List String
  params : List Ty
  result : Ty
  /-- The declared rejection order: (variant type, stable tag). -/
  rejects : List (Nat × Nat)
  body : KExpr
  declared : Bounds
  exact : Bounds
  publicationEligible : Bool

structure Module where
  path : List String
  version : Nat
  profile : String
  profileVersion : Nat
  types : List Decl
  kernels : List Kernel
  theorems : List Nat
  claims : List Nat

end Seki
