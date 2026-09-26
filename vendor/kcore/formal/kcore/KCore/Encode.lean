/-
Canonical encoding of KCore programs and target layouts (identity binding).

A deterministic, injective S-expression text for every syntax node and for
the layout facts a program depends on. It does not use `Repr`, whose output
format belongs to the Lean version. Strings are length-prefixed (`<bytes>:`),
so no name can collide with the surrounding syntax. The SHA-256 of these texts
is the program identity and the target-layout identity recorded in an M1
artifact (`formal/kcore/m1-artifact.sh`).
-/
import KCore.Syntax

namespace KCore.Encode
open KCore

def str (s : String) : String := s!"{s.utf8ByteSize}:{s}"

def intTy : IntTy → String
  | .u8 => "u8" | .u16 => "u16" | .u32 => "u32" | .u64 => "u64"

def ty : Ty → String
  | .int w => intTy w
  | .bool => "bool"
  | .ptr t => s!"(ptr {ty t})"
  | .struct n => s!"(struct {str n})"

def ptr : Ptr → String
  | .null => "null"
  | .loc b o => s!"(loc {b} {o})"

mutual
def val : Val → String
  | .int w n => s!"(int {intTy w} {n})"
  | .bool b => if b then "true" else "false"
  | .ptr t p => s!"(pv {ty t} {ptr p})"
  | .struct n fs => s!"(sv {str n}{vals fs})"
def vals : List Val → String
  | [] => ""
  | v :: vs => " " ++ val v ++ vals vs
end

def binOp : BinOp → String
  | .add => "add" | .sub => "sub" | .mul => "mul" | .div => "div" | .mod => "mod"
  | .wadd => "wadd" | .wsub => "wsub" | .wmul => "wmul"
  | .band => "band" | .bor => "bor" | .bxor => "bxor"
  | .shl => "shl" | .wshl => "wshl" | .shr => "shr"
  | .eq => "eq" | .ne => "ne" | .lt => "lt" | .le => "le"
  | .land => "land" | .lor => "lor"

def unOp : UnOp → String
  | .lnot => "lnot" | .bnot => "bnot"
  | .zext w => s!"(zext {intTy w})" | .trunc w => s!"(trunc {intTy w})"

mutual
def expr : Expr → String
  | .var x => s!"(var {str x})"
  | .lit v => s!"(lit {val v})"
  | .bin op a b => s!"({binOp op} {expr a} {expr b})"
  | .un op a => s!"({unOp op} {expr a})"
  | .field e i => s!"(field {expr e} {i})"
  | .mk n es => s!"(mk {str n}{exprs es})"
def exprs : List Expr → String
  | [] => ""
  | e :: es => " " ++ expr e ++ exprs es
end

def stmt : Stmt → String
  | .skip => "skip"
  | .assign x e => s!"(assign {str x} {expr e})"
  | .load x p => s!"(load {str x} {expr p})"
  | .store p v => s!"(store {expr p} {expr v})"
  | .ptrAdd x p k => s!"(ptradd {str x} {expr p} {expr k})"
  | .alloc x t c => s!"(alloc {str x} {ty t} {expr c})"
  | .free p => s!"(free {expr p})"
  | .call x f as => s!"(call {str x} {str f}{exprs as})"
  | .checkpoint => "checkpoint"
  | .ite c a b => s!"(if {expr c} {stmt a} {stmt b})"
  | .while c b => s!"(while {expr c} {stmt b})"
  | .seq a b => s!"(seq {stmt a} {stmt b})"
  | .ret e => s!"(ret {expr e})"

def binding (p : String × Ty) : String := s!"({str p.1} {ty p.2})"

def list {α : Type} (f : α → String) (xs : List α) : String :=
  "(" ++ " ".intercalate (xs.map f) ++ ")"

def structDef (sd : StructDef) : String :=
  s!"(structdef {str sd.name} {list ty sd.fields})"

def funDef (fd : FunDef) : String :=
  s!"(fundef {str fd.name} {list binding fd.params} {ty fd.result} {list binding fd.locals} {stmt fd.body})"

/-- Canonical text of a program. -/
def program (P : Program) : String :=
  s!"(kcore-program-v1 {list structDef P.structs} {list funDef P.funs})"

/-- The layout facts a program depends on: every integer width, `bool`, and
    for each struct its size, alignment, field offsets and the size and
    alignment of each field type; plus `SIZE_MAX`. -/
def layout (L : Layout) (P : Program) : String :=
  let tyFact (t : Ty) : String := s!"({ty t} {L.sizeOf t} {L.alignOf t})"
  let base := [Ty.int .u8, .int .u16, .int .u32, .int .u64, .bool].map tyFact
  let structFact (sd : StructDef) : String :=
    s!"(struct {str sd.name} {tyFact (.struct sd.name)} {list toString (L.fieldOffsets sd.name)} {list tyFact sd.fields})"
  s!"(kcore-layout-v1 {L.sizeMax} {list id base} {list structFact P.structs})"

end KCore.Encode
