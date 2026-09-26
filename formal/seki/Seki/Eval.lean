/-
The meaning of a typed-core kernel: `Seki.eval`.

A value is what the typed core computes with. Nominals and aliases are
transparent here: a nominal's value is its representation's value, because
admission, not evaluation, is what keeps nominals apart. A record is its
field values in canonical field order. A variant is its stable tag and, for a
case with a payload, the payload's field values in canonical order.

Evaluation is total and structural. It returns `none` only when the program
or its input is not admitted: an unbound local, a type mismatch, or a variant
tag with no arm. For an admitted kernel on an admitted input it always
returns a decision (that is a theorem still to be proved, not assumed here).
-/
import Seki.Core

namespace Seki

inductive Value where
  | unit
  | bool (b : Bool)
  | int (w : IntTy) (n : Nat)
  | bytes (octets : List Nat)
  | record (fields : List Value)
  | variant (tag : Nat) (payload : Option (List Value))
deriving Repr

mutual
def Value.beq : Value → Value → Bool
  | .unit, .unit => true
  | .bool a, .bool b => a == b
  | .int v a, .int w b => v == w && a == b
  | .bytes a, .bytes b => a == b
  | .record a, .record b => Value.beqList a b
  | .variant s p, .variant t q => s == t && Value.beqOpt p q
  | _, _ => false

def Value.beqList : List Value → List Value → Bool
  | [], [] => true
  | a :: as, b :: bs => Value.beq a b && Value.beqList as bs
  | _, _ => false

def Value.beqOpt : Option (List Value) → Option (List Value) → Bool
  | none, none => true
  | some a, some b => Value.beqList a b
  | _, _ => false
end

/-- A kernel's decision. A rejection records its precedence index (its
    reason's position in the declared rejection order) and whether a
    `require` produced it. -/
inductive Outcome where
  | accept (value : Value)
  | reject (reason : Value) (precedence : Nat) (viaRequire : Bool)
deriving Repr

def cmp : CmpOp → Nat → Nat → Bool
  | .lt, a, b => decide (a < b)
  | .le, a, b => decide (a ≤ b)
  | .gt, a, b => decide (a > b)
  | .ge, a, b => decide (a ≥ b)

mutual
def evalExpr (env : List Value) : Expr → Option Value
  | .mk _ t => evalTerm env t

def evalTerm (env : List Value) : Term → Option Value
  | .unit => some .unit
  | .bool b => some (.bool b)
  | .int w n => some (.int w n)
  | .local i => env[i]?
  | .record _ fs => (evalInits env fs).map .record
  | .project e _ f =>
      match evalExpr env e with
      | some (.record vs) => vs[f]?
      | _ => none
  | .variant _ tag fs =>
      (evalNamed env fs).map fun vs => .variant tag (if vs.isEmpty then none else some vs)
  | .eq a b =>
      match evalExpr env a, evalExpr env b with
      | some x, some y => some (.bool (Value.beq x y))
      | _, _ => none
  | .ne a b =>
      match evalExpr env a, evalExpr env b with
      | some x, some y => some (.bool (!Value.beq x y))
      | _, _ => none
  | .andThen a b =>
      match evalExpr env a with
      | some (.bool false) => some (.bool false)
      | some (.bool true) =>
          match evalExpr env b with
          | some (.bool r) => some (.bool r)
          | _ => none
      | _ => none
  | .orElse a b =>
      match evalExpr env a with
      | some (.bool true) => some (.bool true)
      | some (.bool false) =>
          match evalExpr env b with
          | some (.bool r) => some (.bool r)
          | _ => none
      | _ => none
  | .cmp op a b =>
      match evalExpr env a, evalExpr env b with
      | some (.int v x), some (.int w y) => if v == w then some (.bool (cmp op x y)) else none
      | _, _ => none

def evalInits (env : List Value) : Inits → Option (List Value)
  | .nil => some []
  | .cons _ e rest =>
      match evalExpr env e, evalInits env rest with
      | some v, some vs => some (v :: vs)
      | _, _ => none

def evalNamed (env : List Value) : NamedInits → Option (List Value)
  | .nil => some []
  | .cons _ e rest =>
      match evalExpr env e, evalNamed env rest with
      | some v, some vs => some (v :: vs)
      | _, _ => none
end

mutual
def evalK (env : List Value) : KExpr → Option Outcome
  | .accept e => (evalExpr env e).map .accept
  | .reject r p => (evalExpr env r).map fun v => .reject v p false
  | .require c r p k =>
      match evalExpr env c with
      | some (.bool true) => evalK env k
      | some (.bool false) => (evalExpr env r).map fun v => .reject v p true
      | _ => none
  | .let_ v k =>
      match evalExpr env v with
      | some x => evalK (x :: env) k
      | none => none
  | .ite c t f =>
      match evalExpr env c with
      | some (.bool true) => evalK env t
      | some (.bool false) => evalK env f
      | _ => none
  | .match_ s as =>
      match evalExpr env s with
      | some (.variant tag payload) => evalArms env tag payload as
      | _ => none

/-- The arm for `tag`. A case with a payload binds it, as a record, at local 0. -/
def evalArms (env : List Value) (tag : Nat) (payload : Option (List Value)) :
    Arms → Option Outcome
  | .nil => none
  | .cons _ t k rest =>
      if t == tag then
        evalK (match payload with | some p => .record p :: env | none => env) k
      else evalArms env tag payload rest
end

/-- `Seki.eval`: run a kernel on its arguments. Parameters are pushed left to
    right, so the last argument is local 0. -/
def Kernel.eval (k : Kernel) (args : List Value) : Option Outcome :=
  evalK args.reverse k.body

end Seki
