/-
Admission for the alpha typed-core fragment: the Lean statement of which
decoded modules are Seki kernels
(`spec/typed-core/SEKI_TYPED_CORE_V0_DRAFT.md`, `ADMISSION_RULES_V0_DRAFT.md`).

`sekic` is untrusted. Whatever it emits is decoded, then admitted or rejected
here, by rules that reopen every claim instead of believing it:

* every claimed expression type is recomputed and must match exactly;
* declaration tables are in canonical order, references are in range, and
  records, variants and payloads are well formed;
* the kernel's declared rejection order names every rejection case exactly
  once, every rejection site carries its reason's position in that order, and
  positions strictly increase along every path (`check_order`, typed core §8.7);
* every `match` covers every case exactly once, in canonical tag order.

Not yet here: the resource-bound derivation (the exact cost is decoded but not
recomputed) and acyclicity of type declarations. Neither is needed for the
totality theorem in `Seki.Totality`: the evaluator never recurses through a
type, and a cyclic declaration would only make fewer values admissible.
-/
import Seki.Core

namespace Seki

def Expr.ty : Expr → Ty
  | .mk t _ => t

namespace Admit

variable (ds : List Decl)

def body? (i : Nat) : Option DeclBody := (ds[i]?).map (·.body)

/-- The representation an operator acts on: aliases and nominals resolved. -/
def repr : Nat → Ty → Ty
  | 0, t => t
  | fuel + 1, .declared i =>
      match body? ds i with
      | some (.alias r) | some (.nominal r) => repr fuel r
      | _ => .declared i
  | _, t => t

def isInt : Ty → Bool
  | .int _ => true
  | _ => false

mutual
def okExpr (tenv : List Ty) : Expr → Bool
  | .mk t term => okTerm tenv t term

def okTerm (tenv : List Ty) (t : Ty) : Term → Bool
  | .unit => t == .unit
  | .bool _ => t == .bool
  | .int w n => t == .int w && decide (n < 2 ^ w.bits)
  | .local i => tenv[i]? == some t
  | .record r fs =>
      t == .declared r &&
      match body? ds r with
      | some (.record flds) => okInits tenv flds 0 fs
      | _ => false
  | .project e r f =>
      okExpr tenv e && e.ty == .declared r &&
      match body? ds r with
      | some (.record flds) => (flds[f]?.map (·.ty)) == some t
      | _ => false
  | .variant r tag fs =>
      t == .declared r &&
      match body? ds r with
      | some (.variant cs) =>
          match cs.find? (·.tag == tag) with
          | some ⟨_, _, none⟩ => okNamed tenv [] fs
          | some ⟨_, _, some flds⟩ => !flds.isEmpty && okNamed tenv flds fs
          | none => false
      | _ => false
  | .eq a b | .ne a b =>
      t == .bool && okExpr tenv a && okExpr tenv b && a.ty == b.ty
  | .andThen a b | .orElse a b =>
      t == .bool && okExpr tenv a && okExpr tenv b && a.ty == .bool && b.ty == .bool
  | .cmp _ a b =>
      t == .bool && okExpr tenv a && okExpr tenv b && a.ty == b.ty &&
        isInt (repr ds (ds.length + 1) a.ty)

/-- Record constructor fields: every field, in canonical position order. -/
def okInits (tenv : List Ty) : List Field → Nat → Inits → Bool
  | [], _, .nil => true
  | f :: fs, i, .cons j e rest =>
      j == i && okExpr tenv e && e.ty == f.ty && okInits tenv fs (i + 1) rest
  | _, _, _ => false

/-- Variant payload fields: every field, by name, in canonical order. -/
def okNamed (tenv : List Ty) : List Field → NamedInits → Bool
  | [], .nil => true
  | f :: fs, .cons n e rest => n == f.name && okExpr tenv e && e.ty == f.ty && okNamed tenv fs rest
  | _, _ => false
end

/-- The declared variant and stable tag a rejection reason constructs. -/
def reasonCase : Expr → Option (Nat × Nat)
  | .mk _ (.variant r tag _) => some (r, tag)
  | _ => none

/-- A rejection site: its reason has the rejection type, and its precedence
    is its case's position in the declared order and is at least `floor`. -/
def okReason (tenv : List Ty) (R : Ty) (rejects : List (Nat × Nat)) (floor : Nat)
    (r : Expr) (p : Nat) : Bool :=
  okExpr ds tenv r && r.ty == R && decide (floor ≤ p) &&
    match reasonCase r, rejects[p]? with
    | some rc, some q => rc == q
    | _, _ => false

mutual
def okK (tenv : List Ty) (A R : Ty) (rejects : List (Nat × Nat)) (floor : Nat) :
    KExpr → Bool
  | .accept e => okExpr ds tenv e && e.ty == A
  | .reject r p => okReason ds tenv R rejects floor r p
  | .require c r p k =>
      okExpr ds tenv c && c.ty == .bool && okReason ds tenv R rejects floor r p &&
        okK tenv A R rejects (p + 1) k
  | .let_ v k => okExpr ds tenv v && okK (v.ty :: tenv) A R rejects floor k
  | .ite c a b =>
      okExpr ds tenv c && c.ty == .bool && okK tenv A R rejects floor a &&
        okK tenv A R rejects floor b
  | .match_ s arms =>
      okExpr ds tenv s &&
      match s.ty with
      | .declared v =>
          match body? ds v with
          | some (.variant cs) =>
              cs.all (·.payload.isNone) &&
                okArms tenv A R rejects floor v (cs.map (·.tag)) arms
          | _ => false
      | _ => false

/-- Arms: one per case of variant `v`, in canonical tag order. -/
def okArms (tenv : List Ty) (A R : Ty) (rejects : List (Nat × Nat)) (floor v : Nat) :
    List Nat → Arms → Bool
  | [], .nil => true
  | t :: ts, .cons r tag k rest =>
      r == v && tag == t && okK tenv A R rejects floor k &&
        okArms tenv A R rejects floor v ts rest
  | _, _ => false
end

/-! ## Declarations and the module -/

def strictlyIncreasing {α} (lt : α → α → Bool) : List α → Bool
  | a :: b :: rest => lt a b && strictlyIncreasing lt (b :: rest)
  | _ => true

/-- Names compare by unsigned ASCII octets, shorter prefix first. -/
def nameLt (a b : String) : Bool := decide (a.toList.map Char.toNat < b.toList.map Char.toNat)

/-- Every reference in a type is in range, and octet lengths are admitted. -/
def okTy (n : Nat) : Ty → Bool
  | .unit | .bool | .int _ => true
  | .bytes len => decide (0 < len)
  | .digest len => len == 32
  | .decision a r => okTy n a && okTy n r
  | .declared i => decide (i < n)

def okFields (n : Nat) (fs : List Field) : Bool :=
  !fs.isEmpty && strictlyIncreasing (fun a b => nameLt a.name b.name) fs &&
    fs.all (fun f => okTy n f.ty)

def okDecl (n : Nat) : DeclBody → Bool
  | .alias t | .nominal t => okTy n t
  | .record fs => okFields n fs
  | .variant cs =>
      !cs.isEmpty && strictlyIncreasing (fun a b => decide (a.tag < b.tag)) cs &&
      cs.all (fun c => c.tag != 0 && match c.payload with
        | none => true
        | some fs => okFields n fs) &&
      (cs.map (·.name)).all (fun n => (cs.map (·.name)).count n == 1)

/-- A permutation check that the kernel can evaluate. -/
def sameElems (xs ys : List (Nat × Nat)) : Bool :=
  xs.length == ys.length && xs.all (fun x => ys.count x == 1) && ys.all (fun y => xs.count y == 1)

def okKernel (k : Kernel) : Bool :=
  match k.params, k.result with
  | [pt], .decision A (.declared rv) =>
      match body? ds rv with
      | some (.variant cs) =>
          okTy ds.length pt && okTy ds.length A &&
          sameElems k.rejects (cs.map fun c => (rv, c.tag)) &&
          okK ds [pt] A (.declared rv) k.rejects 0 k.body
      | _ => false
  | _, _ => false

/-- A decoded module is an admitted alpha kernel module. -/
def module (m : Module) : Bool :=
  strictlyIncreasing (fun a b => nameLt a.name b.name) m.types &&
  m.types.all (fun d => okDecl m.types.length d.body) &&
  m.kernels.length == 1 &&
  m.kernels.all (okKernel m.types)

end Admit
end Seki
